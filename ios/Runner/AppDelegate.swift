import Flutter
import UIKit
import UserNotifications
import BackgroundTasks
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UNUserNotificationCenterDelegate {

    public static let bgReconcileTaskIdentifier = "com.katala.app.reconcile"
    public static let appGroupIdentifier = "group.com.katala.app"

    private var speechBridge: SpeechBridgeImpl?
    private var notificationBridge: NotificationBridgeImpl?
    private var contactBridge: ContactBridgeImpl?
    private var actionBridge: ActionBridgeImpl?
    private var platformChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = self

        // Initialize notification categories on launch
        NotificationBridgeImpl.configureCategories()

        // Register BGAppRefreshTask before didFinishLaunching completes
        registerBackgroundRefreshTask()

        // Configure audio session
        configureAudioSession()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "KatalaAppNativePlugin").messenger()
        registerPlatformBridges(messenger: messenger)
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    }

    private func registerPlatformBridges(messenger: FlutterBinaryMessenger) {
        speechBridge = SpeechBridgeImpl(messenger: messenger)
        notificationBridge = NotificationBridgeImpl(messenger: messenger)
        contactBridge = ContactBridgeImpl(messenger: messenger)
        actionBridge = ActionBridgeImpl(messenger: messenger)

        // Platform / database path channel
        platformChannel = FlutterMethodChannel(name: "com.katala.app/platform", binaryMessenger: messenger)
        platformChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "getSharedContainerPath":
                if let containerURL = FileManager.default.containerURL(
                    forSecurityApplicationGroupIdentifier: AppDelegate.appGroupIdentifier
                ) {
                    result(containerURL.path)
                } else {
                    result(FlutterError(code: "NO_APP_GROUP", message: "Shared App Group container not found", details: nil))
                }
            case "scheduleBackgroundReconciliation":
                self?.scheduleNextBackgroundRefresh()
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Background App Refresh (TASK-065)

    private func registerBackgroundRefreshTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: AppDelegate.bgReconcileTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self?.handleBackgroundReconcile(task: refreshTask)
        }
    }

    private func handleBackgroundReconcile(task: BGAppRefreshTask) {
        // Schedule next refresh window (e.g. 6 hours from now)
        scheduleNextBackgroundRefresh()

        var isTaskExpired = false
        task.expirationHandler = {
            isTaskExpired = true
            NSLog("[Katala] BGAppRefreshTask expired before completion.")
        }

        // Perform best-effort reconciliation
        DispatchQueue.global(qos: .background).async {
            guard !isTaskExpired else {
                task.setTaskCompleted(success: false)
                return
            }

            do {
                let db = try ExtensionDatabase()
                try db.validateSchemaVersion()
                // Database is accessible and valid
                NSLog("[Katala] Background reconciliation check succeeded.")
                task.setTaskCompleted(success: true)
            } catch {
                NSLog("[Katala] Background reconciliation error: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }
    }

    public func scheduleNextBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppDelegate.bgReconcileTaskIdentifier)
        // Request earliest launch 6 hours from now (best effort by iOS)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            NSLog("[Katala] Scheduled next BGAppRefreshTask.")
        } catch {
            NSLog("[Katala] Could not schedule BGAppRefreshTask: \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        } catch {
            NSLog("[Katala] Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let reminderId = (userInfo["reminder_id"] as? String) ?? (userInfo["reminderId"] as? String)

        defer { completionHandler() }

        guard let reminderId = reminderId else { return }

        switch actionIdentifier {
        case NotificationBridgeImpl.actionDone:
            handleDoneAction(reminderId: reminderId)

        case NotificationBridgeImpl.actionSnooze:
            handleSnoozeAction(reminderId: reminderId)

        case NotificationBridgeImpl.actionCall:
            if let target = userInfo["action_target"] as? String {
                actionBridge?.launchDialer(phoneNumber: target) { _ in }
            }

        case NotificationBridgeImpl.actionText:
            if let target = userInfo["action_target"] as? String {
                actionBridge?.launchSms(phoneNumber: target, message: nil) { _ in }
            }

        case NotificationBridgeImpl.actionUrl:
            if let target = userInfo["action_target"] as? String {
                actionBridge?.launchUrl(urlString: target) { _ in }
            }

        default:
            break
        }
    }

    private func handleDoneAction(reminderId: String) {
        do {
            let db = try ExtensionDatabase()
            if let (version, _) = try db.getReminderVersion(reminderId: reminderId) {
                let completedAt = ISO8601DateFormatter().string(from: Date())
                try db.transitionReminderState(
                    reminderId: reminderId,
                    expectedVersion: version,
                    newStatus: "completed",
                    completedAt: completedAt
                )
            }
        } catch {
            NSLog("[Katala] Failed to complete reminder from action: \(error.localizedDescription)")
        }
    }

    private func handleSnoozeAction(reminderId: String) {
        do {
            let db = try ExtensionDatabase()
            if let (version, _) = try db.getReminderVersion(reminderId: reminderId) {
                try db.transitionReminderState(
                    reminderId: reminderId,
                    expectedVersion: version,
                    newStatus: "snoozed"
                )
            }
        } catch {
            NSLog("[Katala] Failed to snooze reminder from action: \(error.localizedDescription)")
        }
    }
}
