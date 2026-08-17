package com.katala.app.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import java.io.File
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Lightweight native SQLite database helper for background execution
 * (BootReceiver, WorkManager, NotificationActionReceiver).
 */
object DatabaseHelper {

    private val DB_NAMES = listOf("katala.sqlite", "katala.db", "katala")

    data class NativeReminder(
        val id: String,
        val title: String,
        val notes: String?,
        val scheduledTimeUtc: String,
        val category: String,
        val actionType: String?,
        val actionTarget: String?,
        val notificationId: Int,
        val firedAt: String? = null
    )

    fun getDatabaseFile(context: Context): File {
        val candidateDirs = listOfNotNull(
            context.filesDir,
            context.noBackupFilesDir,
            File(context.filesDir.parentFile ?: context.filesDir, "app_flutter"),
            context.getDatabasePath("dummy").parentFile,
            context.filesDir.parentFile
        )

        // 1. Direct match with candidates
        for (dir in candidateDirs) {
            for (name in DB_NAMES) {
                val f = File(dir, name)
                if (f.exists() && f.length() > 0) return f
            }
        }

        // 2. Discover any existing .sqlite or .db file in the directories
        for (dir in candidateDirs) {
            val dbFiles = dir.listFiles { _, name -> name.endsWith(".sqlite") || name.endsWith(".db") }
            if (!dbFiles.isNullOrEmpty()) {
                val best = dbFiles.maxByOrNull { it.length() }
                if (best != null && best.exists()) return best
            }
        }

        return File(context.filesDir, "katala.sqlite")
    }

    fun openDatabase(context: Context): SQLiteDatabase? {
        val file = getDatabaseFile(context)
        if (!file.exists()) {
            return null
        }
        return try {
            SQLiteDatabase.openDatabase(
                file.absolutePath,
                null,
                SQLiteDatabase.OPEN_READWRITE
            ).apply {
                rawQuery("PRAGMA journal_mode=WAL;", null).close()
                rawQuery("PRAGMA foreign_keys=ON;", null).close()
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Queries nearest pending/snoozed reminders up to [limit] (default 60).
     */
    fun queryPendingReminders(context: Context, limit: Int = 60): List<NativeReminder> {
        val db = openDatabase(context) ?: return emptyList()
        val list = mutableListOf<NativeReminder>()

        try {
            val query = """
                SELECT 
                    r.id, 
                    r.title, 
                    r.notes, 
                    r.intent_type, 
                    t.scheduled_time_utc,
                    t.notification_id,
                    t.fired_at,
                    a.action_type,
                    a.target_value
                FROM reminder r
                JOIN trigger_ t ON r.id = t.reminder_id
                LEFT JOIN action_ a ON r.id = a.reminder_id
                WHERE r.is_deleted = 0 
                  AND r.status IN ('PENDING', 'SNOOZED')
                ORDER BY t.scheduled_time_utc ASC
                LIMIT ?
            """.trimIndent()

            db.rawQuery(query, arrayOf(limit.toString())).use { cursor ->
                val idIdx = cursor.getColumnIndex("id")
                val titleIdx = cursor.getColumnIndex("title")
                val notesIdx = cursor.getColumnIndex("notes")
                val intentTypeIdx = cursor.getColumnIndex("intent_type")
                val timeIdx = cursor.getColumnIndex("scheduled_time_utc")
                val nidIdx = cursor.getColumnIndex("notification_id")
                val firedAtIdx = cursor.getColumnIndex("fired_at")
                val actionTypeIdx = cursor.getColumnIndex("action_type")
                val targetIdx = cursor.getColumnIndex("target_value")

                while (cursor.moveToNext()) {
                    val id = cursor.getString(idIdx)
                    val title = cursor.getString(titleIdx)
                    val notes = if (notesIdx >= 0 && !cursor.isNull(notesIdx)) cursor.getString(notesIdx) else null
                    val intentType = if (intentTypeIdx >= 0 && !cursor.isNull(intentTypeIdx)) cursor.getString(intentTypeIdx) else "GENERAL"
                    val scheduledTimeUtc = cursor.getString(timeIdx)
                    val nid = if (nidIdx >= 0 && !cursor.isNull(nidIdx)) cursor.getInt(nidIdx) else (id.hashCode() and 0x7FFFFFFF)
                    val firedAt = if (firedAtIdx >= 0 && !cursor.isNull(firedAtIdx)) cursor.getString(firedAtIdx) else null
                    val actionType = if (actionTypeIdx >= 0 && !cursor.isNull(actionTypeIdx)) cursor.getString(actionTypeIdx) else null
                    val targetValue = if (targetIdx >= 0 && !cursor.isNull(targetIdx)) cursor.getString(targetIdx) else null

                    list.add(
                        NativeReminder(
                            id = id,
                            title = title,
                            notes = notes,
                            scheduledTimeUtc = scheduledTimeUtc,
                            category = intentType.lowercase(),
                            actionType = actionType,
                            actionTarget = targetValue,
                            notificationId = nid,
                            firedAt = firedAt
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Log or ignore query errors
        } finally {
            db.close()
        }

        return list
    }

    /**
     * Updates reminder status to COMPLETED directly in SQLite.
     */
    fun markReminderCompleted(context: Context, reminderId: String): Boolean {
        val db = openDatabase(context) ?: return false
        return try {
            val now = Instant.now().toString()
            val values = ContentValues().apply {
                put("status", "COMPLETED")
                put("completed_at", now)
                put("updated_at", now)
            }
            db.execSQL(
                "UPDATE reminder SET version = version + 1 WHERE id = ?",
                arrayOf(reminderId)
            )
            val rows = db.update("reminder", values, "id = ?", arrayOf(reminderId))
            rows > 0
        } catch (e: Exception) {
            false
        } finally {
            db.close()
        }
    }

    /**
     * Snoozes a reminder for [snoozeMinutes] directly in SQLite.
     */
    fun snoozeReminder(context: Context, reminderId: String, snoozeMinutes: Int = 10): Boolean {
        val db = openDatabase(context) ?: return false
        return try {
            val now = Instant.now()
            val newTime = now.plus(snoozeMinutes.toLong(), ChronoUnit.MINUTES).toString()
            val nowStr = now.toString()

            db.beginTransaction()
            try {
                // Update reminder
                db.execSQL(
                    """
                    UPDATE reminder 
                    SET status = 'SNOOZED', 
                        snooze_count = snooze_count + 1, 
                        version = version + 1, 
                        updated_at = ? 
                    WHERE id = ? AND snooze_count < 10
                    """.trimIndent(),
                    arrayOf(nowStr, reminderId)
                )

                // Update trigger scheduled time
                db.execSQL(
                    """
                    UPDATE trigger_ 
                    SET scheduled_time_utc = ?, 
                        notification_scheduled = 1 
                    WHERE reminder_id = ?
                    """.trimIndent(),
                    arrayOf(newTime, reminderId)
                )

                db.setTransactionSuccessful()
                true
            } finally {
                db.endTransaction()
            }
        } catch (e: Exception) {
            false
        } finally {
            db.close()
        }
    }

    /**
     * Sets or updates a metadata key-value pair.
     */
    fun updateMetadata(context: Context, key: String, value: String) {
        val db = openDatabase(context) ?: return
        try {
            val now = Instant.now().toString()
            val values = ContentValues().apply {
                put("key", key)
                put("value", value)
            }
            db.insertWithOnConflict(
                "app_metadata",
                null,
                values,
                SQLiteDatabase.CONFLICT_REPLACE
            )
        } catch (e: Exception) {
            // Ignore metadata update failures
        } finally {
            db.close()
        }
    }

    /**
     * Marks trigger as fired when OS notification is displayed.
     */
    fun markTriggerFired(context: Context, reminderId: String): Boolean {
        val db = openDatabase(context) ?: return false
        return try {
            val now = Instant.now().toString()
            val values = ContentValues().apply {
                put("fired_at", now)
            }
            val rows = db.update("trigger_", values, "reminder_id = ?", arrayOf(reminderId))
            rows > 0
        } catch (e: Exception) {
            false
        } finally {
            db.close()
        }
    }

    /**
     * Checks if reminder is currently pending or snoozed and not deleted.
     */
    fun isReminderActive(context: Context, reminderId: String): Boolean {
        val db = openDatabase(context) ?: return true
        return try {
            val query = "SELECT status, is_deleted FROM reminder WHERE id = ?"
            db.rawQuery(query, arrayOf(reminderId)).use { cursor ->
                if (cursor.moveToNext()) {
                    val status = cursor.getString(0)
                    val isDeleted = cursor.getInt(1)
                    isDeleted == 0 && (status == "PENDING" || status == "SNOOZED")
                } else {
                    false
                }
            }
        } catch (e: Exception) {
            true
        } finally {
            db.close()
        }
    }
}
