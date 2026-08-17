package com.katala.app.bridges

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Evaluates OEM background delivery reliability and provides manufacturer-specific
 * guidance (Xiaomi, OPPO, realme, Samsung, Huawei, Vivo).
 */
class ReliabilityChecker(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.katala.app/reliability"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getReliabilityStatus" -> {
                result.success(getReliabilityReport())
            }
            "requestIgnoreBatteryOptimizations" -> {
                requestIgnoreBatteryOptimizations(result)
            }
            "openExactAlarmSettings" -> {
                openExactAlarmSettings(result)
            }
            "dispose" -> {
                channel.setMethodCallHandler(null)
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun getReliabilityReport(): Map<String, Any?> {
        val manufacturer = Build.MANUFACTURER?.lowercase() ?: "unknown"
        val model = Build.MODEL ?: "unknown"
        val sdkInt = Build.VERSION.SDK_INT

        val isExactAlarmGranted = if (sdkInt >= Build.VERSION_CODES.S) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            am?.canScheduleExactAlarms() ?: false
        } else {
            true
        }

        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val isBatteryOptimizationIgnored = if (sdkInt >= Build.VERSION_CODES.M) {
            powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } else {
            true
        }

        val isAggressiveOem = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> true
            manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> true
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> true
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> true
            manufacturer.contains("samsung") -> true
            else -> false
        }

        val status = when {
            !isExactAlarmGranted -> "poor"
            isBatteryOptimizationIgnored && !isAggressiveOem -> "good"
            isBatteryOptimizationIgnored && isAggressiveOem -> "good"
            isAggressiveOem && !isBatteryOptimizationIgnored -> "fair"
            else -> "good"
        }

        val (title, steps, autoStart) = getOemGuidance(manufacturer)

        return mapOf(
            "status" to status,
            "manufacturer" to Build.MANUFACTURER,
            "model" to model,
            "sdkVersion" to sdkInt,
            "isExactAlarmGranted" to isExactAlarmGranted,
            "isBatteryOptimizationIgnored" to isBatteryOptimizationIgnored,
            "isAggressiveOem" to isAggressiveOem,
            "guidanceTitle" to title,
            "guidanceSteps" to steps,
            "autoStartGuidance" to autoStart
        )
    }

    private fun getOemGuidance(manufacturer: String): Triple<String, List<String>, String?> {
        return when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> {
                Triple(
                    "Xiaomi / MIUI / HyperOS Optimization",
                    listOf(
                        "1. Open Settings -> Apps -> Manage apps -> Katala",
                        "2. Enable 'Autostart'",
                        "3. Tap 'Battery saver' and select 'No restrictions'",
                        "4. Enable 'Display pop-up windows while running in the background'"
                    ),
                    "Autostart is critical on MIUI/HyperOS to receive alarms after app kill."
                )
            }
            manufacturer.contains("oppo") || manufacturer.contains("realme") || manufacturer.contains("oneplus") -> {
                Triple(
                    "OPPO / realme / ColorOS Optimization",
                    listOf(
                        "1. Open Settings -> Battery -> App Battery Management -> Katala",
                        "2. Enable 'Allow background activity' and 'Allow auto-launch'",
                        "3. Under 'More battery settings', set 'Optimize battery use' to 'Don't optimize'"
                    ),
                    "Auto-launch permission ensures alarms fire reliably."
                )
            }
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                Triple(
                    "Huawei / EMUI Optimization",
                    listOf(
                        "1. Open Settings -> Battery -> App Launch -> Katala",
                        "2. Switch off 'Manage automatically'",
                        "3. Turn ON 'Auto-launch', 'Secondary launch', and 'Run in background'"
                    ),
                    "Manual launch management prevents EMUI from freezing Katala."
                )
            }
            manufacturer.contains("samsung") -> {
                Triple(
                    "Samsung / One UI Optimization",
                    listOf(
                        "1. Open Settings -> Apps -> Katala -> Battery",
                        "2. Select 'Unrestricted'",
                        "3. In Settings -> Battery -> Background usage limits, ensure Katala is in 'Never sleeping apps'"
                    ),
                    "Unrestricted battery mode prevents One UI from delaying alarms."
                )
            }
            manufacturer.contains("vivo") || manufacturer.contains("iqoo") -> {
                Triple(
                    "Vivo / Funtouch OS Optimization",
                    listOf(
                        "1. Open Settings -> Battery -> Background power consumption management",
                        "2. Select Katala and choose 'High background power consumption'",
                        "3. In Settings -> Applications -> Autostart, enable Katala"
                    ),
                    "High background power mode prevents Funtouch OS sleep timers."
                )
            }
            else -> {
                Triple(
                    "Standard Android Optimization",
                    listOf(
                        "1. Open Settings -> Apps -> Katala -> App battery usage",
                        "2. Set to 'Unrestricted' or disable Battery Optimization",
                        "3. Ensure 'Alarms & Reminders' permission is allowed"
                    ),
                    null
                )
            }
        }
    }

    private fun requestIgnoreBatteryOptimizations(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("INTENT_FAILED", e.message, null)
            }
        } else {
            result.success(true)
        }
    }

    private fun openExactAlarmSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:${context.packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("INTENT_FAILED", e.message, null)
            }
        } else {
            result.success(true)
        }
    }
}
