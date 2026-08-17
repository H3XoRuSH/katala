package com.katala.app.bridges

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import com.katala.app.receivers.NotificationActionReceiver
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.format.DateTimeParseException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArraySet

/**
 * Native Android NotificationBridge implementation.
 *
 * Employs dual scheduling (setExactAndAllowWhileIdle + setAlarmClock)
 * to maximize alarm delivery across diverse OEM background limiters.
 */
class NotificationBridgeImpl(
    private val context: Context,
    messenger: BinaryMessenger? = null
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.katala.app/notifications"

        // Notification Channel IDs
        const val CHANNEL_GENERAL = "katala_general_v1"
        const val CHANNEL_CALL = "katala_call_v1"
        const val CHANNEL_TEXT = "katala_text_v1"
        const val CHANNEL_URL = "katala_url_v1"

        const val ACTION_ALARM_TRIGGER = "com.katala.app.ALARM_TRIGGER"
        const val EXTRA_REMINDER_ID = "reminder_id"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_NOTES = "notes"
        const val EXTRA_CATEGORY = "category"
        const val EXTRA_ACTION_TYPE = "action_type"
        const val EXTRA_ACTION_TARGET = "action_target"
    }

    private val channel = messenger?.let { MethodChannel(it, CHANNEL_NAME) }
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

    // In-memory tracked scheduled IDs and reminder-to-id mapping
    private val scheduledNotificationIds = CopyOnWriteArraySet<Int>()
    private val reminderToNotificationId = ConcurrentHashMap<String, Int>()

    init {
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configureCategories" -> {
                configureCategories()
                result.success(true)
            }
            "schedule" -> {
                try {
                    @Suppress("UNCHECKED_CAST")
                    val reminderData = call.arguments as? Map<String, Any?>
                    if (reminderData == null) {
                        result.error("INVALID_ARGUMENTS", "Reminder data cannot be null", null)
                        return
                    }
                    val notificationId = scheduleNotification(reminderData)
                    result.success(notificationId)
                } catch (e: SecurityException) {
                    result.error("PERMISSION_DENIED", "Exact alarm permission not granted", e.message)
                } catch (e: Exception) {
                    result.error("SCHEDULING_FAILED", e.message, null)
                }
            }
            "cancel" -> {
                val notificationId = call.argument<Int>("notificationId")
                if (notificationId != null) {
                    cancelNotification(notificationId)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENTS", "notificationId is required", null)
                }
            }
            "cancelForReminder" -> {
                val reminderId = call.argument<String>("reminderId")
                if (reminderId != null) {
                    cancelForReminder(reminderId)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENTS", "reminderId is required", null)
                }
            }
            "getScheduledIds" -> {
                result.success(scheduledNotificationIds.toList())
            }
            "reconcile" -> {
                @Suppress("UNCHECKED_CAST")
                val toSchedule = call.argument<List<Map<String, Any?>>>("toSchedule") ?: emptyList()
                @Suppress("UNCHECKED_CAST")
                val knownIds = call.argument<List<Int>>("knownIds") ?: emptyList()
                val reconciliationResult = reconcileNotifications(toSchedule, knownIds)
                result.success(reconciliationResult)
            }
            "dismiss" -> {
                val notificationId = call.argument<Int>("notificationId")
                if (notificationId != null) {
                    notificationManager?.cancel(notificationId)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENTS", "notificationId is required", null)
                }
            }
            "playSaveSound" -> {
                playSaveSound()
                result.success(true)
            }
            "canScheduleExactAlarms" -> {
                result.success(canScheduleExactAlarms())
            }
            "dispose" -> {
                channel?.setMethodCallHandler(null)
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Creates and registers Notification Channels with high importance.
     */
    fun configureCategories() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Delete legacy unversioned channels so Android drops cached settings
            listOf("general", "call", "text", "url").forEach { oldId ->
                try {
                    notificationManager?.deleteNotificationChannel(oldId)
                } catch (e: Exception) {}
            }

            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val soundUri = android.net.Uri.parse("android.resource://" + context.packageName + "/raw/chirp_notification")
            val vibrationPattern = longArrayOf(0, 250, 250, 250)

            val channels = listOf(
                NotificationChannel(CHANNEL_GENERAL, "General Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Notifications for general reminders"
                    enableVibration(true)
                    this.vibrationPattern = vibrationPattern
                    setSound(soundUri, audioAttributes)
                },
                NotificationChannel(CHANNEL_CALL, "Call Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Notifications for phone call reminders"
                    enableVibration(true)
                    this.vibrationPattern = vibrationPattern
                    setSound(soundUri, audioAttributes)
                },
                NotificationChannel(CHANNEL_TEXT, "SMS Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Notifications for SMS and text reminders"
                    enableVibration(true)
                    this.vibrationPattern = vibrationPattern
                    setSound(soundUri, audioAttributes)
                },
                NotificationChannel(CHANNEL_URL, "Link Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Notifications for web links and online tasks"
                    enableVibration(true)
                    this.vibrationPattern = vibrationPattern
                    setSound(soundUri, audioAttributes)
                }
            )

            notificationManager?.createNotificationChannels(channels)
        }
    }

    private fun playSaveSound() {
        try {
            val resId = context.resources.getIdentifier("chirp_save", "raw", context.packageName)
            if (resId != 0) {
                val mp = android.media.MediaPlayer.create(context, resId)
                mp?.setOnCompletionListener { it.release() }
                mp?.start()
            }
        } catch (e: Exception) {}
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager?.canScheduleExactAlarms() ?: false
        } else {
            true
        }
    }

    private fun scheduleNotification(reminderData: Map<String, Any?>): Int {
        val reminderId = reminderData["id"] as? String
            ?: throw IllegalArgumentException("Reminder id is required")
        val title = reminderData["title"] as? String ?: "Katala Reminder"
        val notes = reminderData["notes"] as? String
        val scheduledTimeUtcStr = reminderData["scheduledTimeUtc"] as? String
            ?: (reminderData["trigger"] as? Map<*, *>)?.get("scheduledTimeUtc") as? String
            ?: throw IllegalArgumentException("scheduledTimeUtc is required")

        val triggerInstant = try {
            Instant.parse(scheduledTimeUtcStr)
        } catch (e: DateTimeParseException) {
            throw IllegalArgumentException("Invalid ISO-8601 date: $scheduledTimeUtcStr", e)
        }

        val triggerEpochMillis = triggerInstant.toEpochMilli()
        val notificationId = (reminderData["notificationId"] as? Number)?.toInt()
            ?: (reminderId.hashCode() and 0x7FFFFFFF)

        // Cancel any previous alarm for this reminder first (idempotent)
        cancelNotification(notificationId)

        val firedAt = reminderData["firedAt"] as? String
            ?: (reminderData["trigger"] as? Map<*, *>)?.get("firedAt") as? String
        val nowMillis = System.currentTimeMillis()
        val isEligible = triggerEpochMillis > nowMillis ||
            (firedAt == null && triggerEpochMillis >= nowMillis - 120_000L)

        if (!isEligible) {
            return notificationId
        }

        if (alarmManager == null) {
            throw IllegalStateException("AlarmManager service is unavailable")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            throw SecurityException("Exact alarm permission SCHEDULE_EXACT_ALARM is not granted")
        }

        val category = (reminderData["intentType"] as? String)
            ?: (reminderData["category"] as? String)
            ?: CHANNEL_GENERAL

        @Suppress("UNCHECKED_CAST")
        val actionData = reminderData["action"] as? Map<String, Any?>
        val actionType = actionData?.get("actionType") as? String
        val actionTarget = actionData?.get("target") as? String

        // Intent for AlarmReceiver
        val receiverIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_ALARM_TRIGGER
            setPackage(context.packageName)
            putExtra(EXTRA_REMINDER_ID, reminderId)
            putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_NOTES, notes)
            putExtra(EXTRA_CATEGORY, category)
            putExtra(EXTRA_ACTION_TYPE, actionType)
            putExtra(EXTRA_ACTION_TARGET, actionTarget)
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val alarmPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            receiverIntent,
            pendingIntentFlags
        )

        // Intent to show when user taps clock indicator
        val showIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val showPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            showIntent,
            pendingIntentFlags
        )

        // Dual scheduling for OEM reliability:
        // 1. Primary: setExactAndAllowWhileIdle
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerEpochMillis,
                alarmPendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerEpochMillis,
                alarmPendingIntent
            )
        }

        // 2. Secondary: setAlarmClock (survives aggressive OEM battery managers)
        try {
            val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerEpochMillis, showPendingIntent)
            alarmManager.setAlarmClock(alarmClockInfo, alarmPendingIntent)
        } catch (e: Exception) {
            // Some devices or permission states may throw on setAlarmClock; keep primary exact alarm
        }

        // Update in-memory tracking
        scheduledNotificationIds.add(notificationId)
        reminderToNotificationId[reminderId] = notificationId

        return notificationId
    }

    private fun cancelNotification(notificationId: Int) {
        val receiverIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_ALARM_TRIGGER
            setPackage(context.packageName)
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_NO_CREATE
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            receiverIntent,
            pendingIntentFlags
        )

        if (pendingIntent != null && alarmManager != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }

        notificationManager?.cancel(notificationId)
        scheduledNotificationIds.remove(notificationId)

        // Remove from reminder mapping
        val entry = reminderToNotificationId.entries.firstOrNull { it.value == notificationId }
        entry?.let { reminderToNotificationId.remove(it.key) }
    }

    private fun cancelForReminder(reminderId: String) {
        val notificationId = reminderToNotificationId[reminderId]
            ?: (reminderId.hashCode() and 0x7FFFFFFF)
        cancelNotification(notificationId)
        reminderToNotificationId.remove(reminderId)
    }

    private fun reconcileNotifications(
        toSchedule: List<Map<String, Any?>>,
        knownIds: List<Int>
    ): Map<String, Any> {
        val scheduledIds = mutableListOf<String>()
        val failedIds = mutableListOf<String>()
        val cancelledIds = mutableListOf<Int>()
        val errors = mutableListOf<String>()

        val desiredNotificationIds = mutableSetOf<Int>()

        // 1. Schedule all valid reminders
        for (reminder in toSchedule) {
            val id = reminder["id"] as? String ?: continue
            try {
                val nid = scheduleNotification(reminder)
                desiredNotificationIds.add(nid)
                scheduledIds.add(id)
            } catch (e: Exception) {
                failedIds.add(id)
                errors.add("Failed to schedule reminder $id: ${e.message}")
            }
        }

        // 2. Cancel orphaned notification IDs
        val allTrackedOrKnown = (scheduledNotificationIds + knownIds).toSet()
        for (candidateId in allTrackedOrKnown) {
            if (!desiredNotificationIds.contains(candidateId)) {
                cancelNotification(candidateId)
                cancelledIds.add(candidateId)
            }
        }

        return mapOf(
            "scheduledIds" to scheduledIds,
            "failedIds" to failedIds,
            "cancelledIds" to cancelledIds,
            "errors" to errors
        )
    }
}
