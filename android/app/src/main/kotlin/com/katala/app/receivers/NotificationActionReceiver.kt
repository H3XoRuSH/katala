package com.katala.app.receivers

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import com.katala.app.bridges.NotificationBridgeImpl
import com.katala.app.data.DatabaseHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Handles incoming alarm broadcasts to display notifications,
 * and processes interactive notification actions (Done, Snooze, Call, SMS, Open Link).
 */
class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_COMPLETE = "com.katala.app.ACTION_COMPLETE"
        const val ACTION_SNOOZE = "com.katala.app.ACTION_SNOOZE"
        const val ACTION_CALL = "com.katala.app.ACTION_CALL"
        const val ACTION_SMS = "com.katala.app.ACTION_SMS"
        const val ACTION_OPEN_URL = "com.katala.app.ACTION_OPEN_URL"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val reminderId = intent.getStringExtra(NotificationBridgeImpl.EXTRA_REMINDER_ID) ?: ""
        val notificationId = intent.getIntExtra(
            NotificationBridgeImpl.EXTRA_NOTIFICATION_ID,
            reminderId.hashCode() and 0x7FFFFFFF
        )

        when (action) {
            NotificationBridgeImpl.ACTION_ALARM_TRIGGER -> {
                if (reminderId.isNotEmpty() && !DatabaseHelper.isReminderActive(context, reminderId)) {
                    // Task was completed, deleted, or dismissed early; suppress alarm notification
                    return
                }
                showNotification(context, intent, reminderId, notificationId)
            }
            ACTION_COMPLETE -> {
                val pendingResult = goAsync()
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        if (reminderId.isNotEmpty()) {
                            DatabaseHelper.markReminderCompleted(context, reminderId)
                        }
                        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        notificationManager?.cancel(notificationId)
                    } finally {
                        pendingResult.finish()
                    }
                }
            }
            ACTION_SNOOZE -> {
                val pendingResult = goAsync()
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        if (reminderId.isNotEmpty()) {
                            DatabaseHelper.snoozeReminder(context, reminderId, snoozeMinutes = 10)
                            // Schedule next alarm in 10 minutes
                            scheduleSnoozeAlarm(context, intent, reminderId, notificationId, 10)
                        }
                        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        notificationManager?.cancel(notificationId)
                    } finally {
                        pendingResult.finish()
                    }
                }
            }
            ACTION_CALL -> {
                val target = intent.getStringExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET)
                if (!target.isNullOrBlank()) {
                    val encoded = Uri.encode(target.trim())
                    val dialIntent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encoded")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(dialIntent)
                }
            }
            ACTION_SMS -> {
                val target = intent.getStringExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET)
                if (!target.isNullOrBlank()) {
                    val encoded = Uri.encode(target.trim())
                    val smsIntent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$encoded")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(smsIntent)
                }
            }
            ACTION_OPEN_URL -> {
                val target = intent.getStringExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET)
                if (!target.isNullOrBlank()) {
                    val uri = Uri.parse(target.trim())
                    val scheme = uri.scheme?.lowercase()
                    if (scheme == "http" || scheme == "https") {
                        val viewIntent = Intent(Intent.ACTION_VIEW, uri).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(viewIntent)
                    }
                }
            }
        }
    }

    private fun showNotification(
        context: Context,
        intent: Intent,
        reminderId: String,
        notificationId: Int
    ) {
        // Ensure channels are created on Android O+
        NotificationBridgeImpl(context).configureCategories()

        val title = intent.getStringExtra(NotificationBridgeImpl.EXTRA_TITLE) ?: "Katala Reminder"
        val notes = intent.getStringExtra(NotificationBridgeImpl.EXTRA_NOTES)
        val category = intent.getStringExtra(NotificationBridgeImpl.EXTRA_CATEGORY) ?: NotificationBridgeImpl.CHANNEL_GENERAL
        val actionType = intent.getStringExtra(NotificationBridgeImpl.EXTRA_ACTION_TYPE)
        val actionTarget = intent.getStringExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET)

        val channelId = when (category.lowercase()) {
            "call" -> NotificationBridgeImpl.CHANNEL_CALL
            "text" -> NotificationBridgeImpl.CHANNEL_TEXT
            "url", "open_url" -> NotificationBridgeImpl.CHANNEL_URL
            else -> NotificationBridgeImpl.CHANNEL_GENERAL
        }

        val soundUri = Uri.parse("android.resource://" + context.packageName + "/raw/chirp_notification")

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Tap content intent -> open App
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            pendingFlags
        )

        // Action: Complete
        val completeIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_COMPLETE
            putExtra(NotificationBridgeImpl.EXTRA_REMINDER_ID, reminderId)
            putExtra(NotificationBridgeImpl.EXTRA_NOTIFICATION_ID, notificationId)
        }
        val completePendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId * 10 + 1,
            completeIntent,
            pendingFlags
        )

        // Action: Snooze
        val snoozeIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = ACTION_SNOOZE
            putExtra(NotificationBridgeImpl.EXTRA_REMINDER_ID, reminderId)
            putExtra(NotificationBridgeImpl.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(NotificationBridgeImpl.EXTRA_TITLE, title)
            putExtra(NotificationBridgeImpl.EXTRA_NOTES, notes)
            putExtra(NotificationBridgeImpl.EXTRA_CATEGORY, category)
            putExtra(NotificationBridgeImpl.EXTRA_ACTION_TYPE, actionType)
            putExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET, actionTarget)
        }
        val snoozePendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId * 10 + 2,
            snoozeIntent,
            pendingFlags
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(notes ?: "Reminder scheduled in Katala")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setSound(soundUri)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .setDefaults(NotificationCompat.DEFAULT_LIGHTS or NotificationCompat.DEFAULT_VIBRATE)
            .setContentIntent(contentPendingIntent)
            .addAction(0, "Done", completePendingIntent)
            .addAction(0, "Snooze (10m)", snoozePendingIntent)

        // Action button for specific intent types
        if (!actionTarget.isNullOrBlank()) {
            when {
                actionType == "CALL" || category.equals("call", ignoreCase = true) -> {
                    val callActionIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                        action = ACTION_CALL
                        putExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET, actionTarget)
                    }
                    val callPending = PendingIntent.getBroadcast(
                        context,
                        notificationId * 10 + 3,
                        callActionIntent,
                        pendingFlags
                    )
                    builder.addAction(0, "Call", callPending)
                }
                actionType == "TEXT" || category.equals("text", ignoreCase = true) -> {
                    val smsActionIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                        action = ACTION_SMS
                        putExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET, actionTarget)
                    }
                    val smsPending = PendingIntent.getBroadcast(
                        context,
                        notificationId * 10 + 4,
                        smsActionIntent,
                        pendingFlags
                    )
                    builder.addAction(0, "Message", smsPending)
                }
                actionType == "OPEN_URL" || category.equals("url", ignoreCase = true) -> {
                    val urlActionIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                        action = ACTION_OPEN_URL
                        putExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET, actionTarget)
                    }
                    val urlPending = PendingIntent.getBroadcast(
                        context,
                        notificationId * 10 + 5,
                        urlActionIntent,
                        pendingFlags
                    )
                    builder.addAction(0, "Open Link", urlPending)
                }
            }
        }

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        notificationManager?.notify(notificationId, builder.build())

        if (reminderId.isNotEmpty()) {
            val pendingResult = goAsync()
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    DatabaseHelper.markTriggerFired(context, reminderId)
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }

    private fun scheduleSnoozeAlarm(
        context: Context,
        intent: Intent,
        reminderId: String,
        notificationId: Int,
        snoozeMinutes: Int
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val triggerEpoch = System.currentTimeMillis() + (snoozeMinutes * 60 * 1000L)

        val receiverIntent = Intent(context, NotificationActionReceiver::class.java).apply {
            action = NotificationBridgeImpl.ACTION_ALARM_TRIGGER
            putExtra(NotificationBridgeImpl.EXTRA_REMINDER_ID, reminderId)
            putExtra(NotificationBridgeImpl.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(NotificationBridgeImpl.EXTRA_TITLE, intent.getStringExtra(NotificationBridgeImpl.EXTRA_TITLE))
            putExtra(NotificationBridgeImpl.EXTRA_NOTES, intent.getStringExtra(NotificationBridgeImpl.EXTRA_NOTES))
            putExtra(NotificationBridgeImpl.EXTRA_CATEGORY, intent.getStringExtra(NotificationBridgeImpl.EXTRA_CATEGORY))
            putExtra(NotificationBridgeImpl.EXTRA_ACTION_TYPE, intent.getStringExtra(NotificationBridgeImpl.EXTRA_ACTION_TYPE))
            putExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET, intent.getStringExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET))
        }

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val alarmPendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId,
            receiverIntent,
            pendingFlags
        )

        val showIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val showPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            showIntent,
            pendingFlags
        )

        // Dual scheduling
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerEpoch,
                alarmPendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerEpoch,
                alarmPendingIntent
            )
        }

        try {
            val clockInfo = AlarmManager.AlarmClockInfo(triggerEpoch, showPendingIntent)
            alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
        } catch (e: Exception) {
            // Ignore if rejected
        }
    }
}
