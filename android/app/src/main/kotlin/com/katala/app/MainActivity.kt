package com.katala.app

import com.katala.app.bridges.ActionBridgeImpl
import com.katala.app.bridges.ContactBridgeImpl
import com.katala.app.bridges.NotificationBridgeImpl
import com.katala.app.bridges.ReliabilityChecker
import com.katala.app.bridges.SpeechBridgeImpl
import com.katala.app.workers.ReconciliationWorker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Main host activity for the Katala Flutter application.
 *
 * Configures all native platform bridges and enqueues the periodic
 * 24-hour background alarm reconciliation worker.
 */
class MainActivity : FlutterActivity() {

    private var speechBridge: SpeechBridgeImpl? = null
    private var notificationBridge: NotificationBridgeImpl? = null
    private var contactBridge: ContactBridgeImpl? = null
    private var actionBridge: ActionBridgeImpl? = null
    private var reliabilityChecker: ReliabilityChecker? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 1. Initialize and register platform bridge handlers
        speechBridge = SpeechBridgeImpl(context, messenger)
        notificationBridge = NotificationBridgeImpl(context, messenger).apply {
            configureCategories()
        }
        contactBridge = ContactBridgeImpl(context, messenger)
        actionBridge = ActionBridgeImpl(context, messenger)
        reliabilityChecker = ReliabilityChecker(context, messenger)

        // 2. Schedule daily background WorkManager alarm reconciliation
        ReconciliationWorker.enqueue(applicationContext)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        speechBridge?.dispose()
        contactBridge = null
        actionBridge = null
        reliabilityChecker = null
        notificationBridge = null
    }
}
