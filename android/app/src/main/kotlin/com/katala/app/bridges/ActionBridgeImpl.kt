package com.katala.app.bridges

import android.content.Context
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android ActionBridge implementation.
 *
 * Executes external OS intents:
 * - Phone dialer via ACTION_DIAL (never ACTION_CALL)
 * - SMS pre-fill via ACTION_SENDTO
 * - Web URLs via ACTION_VIEW with strict HTTP/HTTPS validation
 */
class ActionBridgeImpl(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.katala.app/actions"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "launchDialer" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                if (phoneNumber.isNullOrBlank()) {
                    result.error("INVALID_PHONE", "Phone number is required", null)
                    return
                }
                launchDialer(phoneNumber, result)
            }
            "launchSms" -> {
                val phoneNumber = call.argument<String>("phoneNumber")
                val message = call.argument<String>("message")
                if (phoneNumber.isNullOrBlank()) {
                    result.error("INVALID_PHONE", "Phone number is required", null)
                    return
                }
                launchSms(phoneNumber, message, result)
            }
            "launchUrl" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("INVALID_URL", "URL is required", null)
                    return
                }
                launchUrl(url, result)
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

    /**
     * Launches the system dialer pre-populated with [phoneNumber].
     * Uses ACTION_DIAL to require user confirmation before calling.
     */
    private fun launchDialer(phoneNumber: String, result: MethodChannel.Result) {
        try {
            val encodedPhone = Uri.encode(phoneNumber.trim())
            val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$encodedPhone")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CANNOT_LAUNCH", "Failed to launch dialer: ${e.message}", null)
        }
    }

    /**
     * Opens the default SMS application with prefilled recipient and optional message.
     */
    private fun launchSms(phoneNumber: String, message: String?, result: MethodChannel.Result) {
        try {
            val encodedPhone = Uri.encode(phoneNumber.trim())
            val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:$encodedPhone")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                if (!message.isNullOrEmpty()) {
                    putExtra("sms_body", message)
                }
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CANNOT_LAUNCH", "Failed to launch SMS: ${e.message}", null)
        }
    }

    /**
     * Opens an external web URL in the system browser.
     * Validates that the scheme is strictly HTTP or HTTPS.
     */
    private fun launchUrl(url: String, result: MethodChannel.Result) {
        try {
            val uri = Uri.parse(url.trim())
            val scheme = uri.scheme?.lowercase()

            if (scheme != "http" && scheme != "https") {
                result.error("INVALID_URL", "Only HTTP and HTTPS URLs are permitted: $url", null)
                return
            }

            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("CANNOT_LAUNCH", "Failed to launch URL: ${e.message}", null)
        }
    }
}
