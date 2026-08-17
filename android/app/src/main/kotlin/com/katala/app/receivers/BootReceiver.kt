package com.katala.app.receivers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.katala.app.bridges.NotificationBridgeImpl
import com.katala.app.data.DatabaseHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.format.DateTimeParseException

/**
 * Handles device boot completion to re-schedule exact alarms for pending reminders.
 *
 * Implements the 10-second budget constraint (L2) by limiting the query to the
 * nearest 60 reminders.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED && action != "android.intent.action.QUICKBOOT_POWERON") {
            return
        }

        val pendingResult = goAsync()
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

        if (alarmManager == null) {
            pendingResult.finish()
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Ensure channels exist
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    NotificationBridgeImpl(context).configureCategories()
                }

                // Query nearest 60 pending reminders
                val pendingReminders = DatabaseHelper.queryPendingReminders(context, limit = 60)

                for (reminder in pendingReminders) {
                    try {
                        val triggerEpoch = try {
                            Instant.parse(reminder.scheduledTimeUtc).toEpochMilli()
                        } catch (e: DateTimeParseException) {
                            continue
                        }

                        // Don't re-schedule past alarms that are more than 1 hour overdue
                        if (triggerEpoch < System.currentTimeMillis() - 3600000L) {
                            continue
                        }

                        val receiverIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                            this.action = NotificationBridgeImpl.ACTION_ALARM_TRIGGER
                            putExtra(NotificationBridgeImpl.EXTRA_REMINDER_ID, reminder.id)
                            putExtra(NotificationBridgeImpl.EXTRA_NOTIFICATION_ID, reminder.notificationId)
                            putExtra(NotificationBridgeImpl.EXTRA_TITLE, reminder.title)
                            putExtra(NotificationBridgeImpl.EXTRA_NOTES, reminder.notes)
                            putExtra(NotificationBridgeImpl.EXTRA_CATEGORY, reminder.category)
                            putExtra(NotificationBridgeImpl.EXTRA_ACTION_TYPE, reminder.actionType)
                            putExtra(NotificationBridgeImpl.EXTRA_ACTION_TARGET, reminder.actionTarget)
                        }

                        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }

                        val alarmPendingIntent = PendingIntent.getBroadcast(
                            context,
                            reminder.notificationId,
                            receiverIntent,
                            pendingFlags
                        )

                        val showIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                        val showPendingIntent = PendingIntent.getActivity(
                            context,
                            reminder.notificationId,
                            showIntent,
                            pendingFlags
                        )

                        // 1. Primary: setExactAndAllowWhileIdle
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

                        // 2. Secondary: setAlarmClock for aggressive OEM survival
                        try {
                            val clockInfo = AlarmManager.AlarmClockInfo(triggerEpoch, showPendingIntent)
                            alarmManager.setAlarmClock(clockInfo, alarmPendingIntent)
                        } catch (e: Exception) {
                            // Ignored if device rejects alarm clock
                        }
                    } catch (e: Exception) {
                        // Skip problematic individual reminder
                    }
                }

                DatabaseHelper.updateMetadata(
                    context,
                    "last_reconciled_at",
                    Instant.now().toString()
                )
            } finally {
                pendingResult.finish()
            }
        }
    }
}
