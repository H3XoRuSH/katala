package com.katala.app.workers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.katala.app.bridges.NotificationBridgeImpl
import com.katala.app.data.DatabaseHelper
import com.katala.app.receivers.NotificationActionReceiver
import java.time.Instant
import java.time.format.DateTimeParseException
import java.util.concurrent.TimeUnit

/**
 * Background WorkManager worker that runs every 24 hours to reconcile
 * pending alarms with database records.
 */
class ReconciliationWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        const val WORK_NAME = "com.katala.app.reconciliation"

        /**
         * Enqueues unique daily periodic reconciliation work.
         */
        fun enqueue(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiresBatteryNotLow(true)
                .build()

            val workRequest = PeriodicWorkRequestBuilder<ReconciliationWorker>(24, TimeUnit.HOURS)
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
        }
    }

    override suspend fun doWork(): Result {
        return try {
            val alarmManager = applicationContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                ?: return Result.retry()

            // Ensure categories/channels are registered
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationBridgeImpl(applicationContext).configureCategories()
            }

            val pendingReminders = DatabaseHelper.queryPendingReminders(applicationContext, limit = 60)
            val nowMillis = System.currentTimeMillis()

            for (reminder in pendingReminders) {
                val triggerEpoch = try {
                    Instant.parse(reminder.scheduledTimeUtc).toEpochMilli()
                } catch (e: DateTimeParseException) {
                    continue
                }

                // If scheduled time is in the future
                if (triggerEpoch > nowMillis) {
                    val receiverIntent = Intent(applicationContext, NotificationActionReceiver::class.java).apply {
                        action = NotificationBridgeImpl.ACTION_ALARM_TRIGGER
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
                        applicationContext,
                        reminder.notificationId,
                        receiverIntent,
                        pendingFlags
                    )

                    val showIntent = applicationContext.packageManager.getLaunchIntentForPackage(applicationContext.packageName)
                    val showPendingIntent = PendingIntent.getActivity(
                        applicationContext,
                        reminder.notificationId,
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
                        // Ignore if device rejects
                    }
                }
            }

            DatabaseHelper.updateMetadata(
                applicationContext,
                "last_reconciled_at",
                Instant.now().toString()
            )

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
