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

    private const val DB_NAME = "katala.db"

    data class NativeReminder(
        val id: String,
        val title: String,
        val notes: String?,
        val scheduledTimeUtc: String,
        val category: String,
        val actionType: String?,
        val actionTarget: String?,
        val notificationId: Int
    )

    fun getDatabaseFile(context: Context): File {
        // Standard Android database location
        val dbFile = context.getDatabasePath(DB_NAME)
        if (dbFile.exists()) return dbFile

        // PathProvider default files directory
        val filesDb = File(context.filesDir, DB_NAME)
        if (filesDb.exists()) return filesDb

        // PathProvider app_flutter directory
        val appFlutterDb = File(context.filesDir.parentFile, "app_flutter/$DB_NAME")
        if (appFlutterDb.exists()) return appFlutterDb

        return dbFile
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
                val actionTypeIdx = cursor.getColumnIndex("action_type")
                val targetIdx = cursor.getColumnIndex("target_value")

                while (cursor.moveToNext()) {
                    val id = cursor.getString(idIdx)
                    val title = cursor.getString(titleIdx)
                    val notes = if (notesIdx >= 0 && !cursor.isNull(notesIdx)) cursor.getString(notesIdx) else null
                    val intentType = if (intentTypeIdx >= 0 && !cursor.isNull(intentTypeIdx)) cursor.getString(intentTypeIdx) else "GENERAL"
                    val scheduledTimeUtc = cursor.getString(timeIdx)
                    val nid = if (nidIdx >= 0 && !cursor.isNull(nidIdx)) cursor.getInt(nidIdx) else (id.hashCode() and 0x7FFFFFFF)
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
                            notificationId = nid
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
}
