import Foundation
import Flutter
import UserNotifications

/**
 * Native iOS NotificationBridge implementation using UNUserNotificationCenter.
 *
 * Implements category configuration and strict iOS 64-notification limit
 * management using priority queue replacement (nearest 60 reminders).
 */
public class NotificationBridgeImpl: NSObject {

    public static let channelName = "com.katala.app/notifications"
    public static let maxScheduledNotifications = 60

    // Categories
    public static let categoryGeneral = "REMINDER_GENERAL"
    public static let categoryCall = "REMINDER_CALL"
    public static let categoryText = "REMINDER_TEXT"
    public static let categoryUrl = "REMINDER_URL"

    // Action identifiers
    public static let actionDone = "ACTION_DONE"
    public static let actionSnooze = "ACTION_SNOOZE"
    public static let actionCall = "ACTION_CALL"
    public static let actionText = "ACTION_TEXT"
    public static let actionUrl = "ACTION_URL"

    private let channel: FlutterMethodChannel

    public init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: NotificationBridgeImpl.channelName, binaryMessenger: messenger)
        super.init()
        self.channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "configureCategories":
            configureCategories()
            result(true)
        case "schedule":
            guard let reminderData = call.arguments as? [String: Any] else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Reminder data cannot be null", details: nil))
                return
            }
            scheduleNotification(reminderData: reminderData, result: result)
        case "cancel":
            if let notificationId = (call.arguments as? [String: Any])?["notificationId"] as? Int {
                cancelNotification(notificationId: notificationId)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "notificationId is required", details: nil))
            }
        case "cancelForReminder":
            if let reminderId = (call.arguments as? [String: Any])?["reminderId"] as? String {
                cancelForReminder(reminderId: reminderId)
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "reminderId is required", details: nil))
            }
        case "getScheduledIds":
            getScheduledIds(result: result)
        case "reconcile":
            let args = call.arguments as? [String: Any]
            let toSchedule = args?["toSchedule"] as? [[String: Any]] ?? []
            let knownIds = args?["knownIds"] as? [Int] ?? []
            reconcileNotifications(toSchedule: toSchedule, knownIds: knownIds, result: result)
        case "dismiss":
            if let notificationId = (call.arguments as? [String: Any])?["notificationId"] as? Int {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [String(notificationId)])
                result(true)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "notificationId is required", details: nil))
            }
        case "dispose":
            channel.setMethodCallHandler(nil)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /**
     * Registers interactive notification categories with action buttons.
     */
    public func configureCategories() {
        let doneAction = UNNotificationAction(
            identifier: NotificationBridgeImpl.actionDone,
            title: "Done",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: NotificationBridgeImpl.actionSnooze,
            title: "Snooze (10m)",
            options: []
        )

        let callAction = UNNotificationAction(
            identifier: NotificationBridgeImpl.actionCall,
            title: "Call",
            options: [.foreground]
        )

        let textAction = UNNotificationAction(
            identifier: NotificationBridgeImpl.actionText,
            title: "Message",
            options: [.foreground]
        )

        let urlAction = UNNotificationAction(
            identifier: NotificationBridgeImpl.actionUrl,
            title: "Open Link",
            options: [.foreground]
        )

        let generalCategory = UNNotificationCategory(
            identifier: NotificationBridgeImpl.categoryGeneral,
            actions: [doneAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let callCategory = UNNotificationCategory(
            identifier: NotificationBridgeImpl.categoryCall,
            actions: [callAction, doneAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let textCategory = UNNotificationCategory(
            identifier: NotificationBridgeImpl.categoryText,
            actions: [textAction, doneAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let urlCategory = UNNotificationCategory(
            identifier: NotificationBridgeImpl.categoryUrl,
            actions: [urlAction, doneAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        let categories: Set<UNNotificationCategory> = [
            generalCategory,
            callCategory,
            textCategory,
            urlCategory
        ]

        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    private func scheduleNotification(reminderData: [String: Any], result: @escaping FlutterResult) {
        guard let reminderId = reminderData["id"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Reminder id is required", details: nil))
            return
        }

        let title = reminderData["title"] as? String ?? "Katala Reminder"
        let notes = reminderData["notes"] as? String

        let scheduledTimeStr: String
        if let st = reminderData["scheduledTimeUtc"] as? String {
            scheduledTimeStr = st
        } else if let trigger = reminderData["trigger"] as? [String: Any], let st = trigger["scheduledTimeUtc"] as? String {
            scheduledTimeStr = st
        } else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "scheduledTimeUtc is required", details: nil))
            return
        }

        guard let triggerDate = parseIsoDate(scheduledTimeStr) else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid ISO-8601 date: \(scheduledTimeStr)", details: nil))
            return
        }

        let notificationId = (reminderData["notificationId"] as? Int) ?? (abs(reminderId.hashValue))
        let identifier = String(notificationId)

        // Cancel any previous notification for this identifier first
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier, reminderId])

        let categoryRaw = (reminderData["intentType"] as? String) ?? (reminderData["category"] as? String) ?? "general"
        let categoryId = mapCategoryId(categoryRaw)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = notes ?? "Scheduled reminder in Katala"
        content.categoryIdentifier = categoryId
        content.sound = .default

        var userInfo: [String: Any] = [
            "reminder_id": reminderId,
            "notification_id": notificationId,
            "category": categoryRaw
        ]

        if let action = reminderData["action"] as? [String: Any] {
            userInfo["action_type"] = action["actionType"]
            userInfo["action_target"] = action["target"]
        }
        content.userInfo = userInfo

        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Enforce 64-notification limit via priority replacement
        UNUserNotificationCenter.current().getPendingNotificationRequests { pendingRequests in
            if pendingRequests.count >= NotificationBridgeImpl.maxScheduledNotifications {
                // Find pending request with the latest scheduled date
                var latestDate: Date? = nil
                var latestIdentifier: String? = nil

                for req in pendingRequests {
                    if let calTrigger = req.trigger as? UNCalendarNotificationTrigger,
                       let nextDate = calTrigger.nextTriggerDate() {
                        if latestDate == nil || nextDate > latestDate! {
                            latestDate = nextDate
                            latestIdentifier = req.identifier
                        }
                    }
                }

                if let latest = latestDate, triggerDate < latest, let latestId = latestIdentifier {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [latestId])
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            result(FlutterError(code: "SCHEDULING_FAILED", message: error.localizedDescription, details: nil))
                        } else {
                            result(notificationId)
                        }
                    }
                } else {
                    // Beyond top 60 threshold; keep in DB without active notification
                    result(notificationId)
                }
            } else {
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        result(FlutterError(code: "SCHEDULING_FAILED", message: error.localizedDescription, details: nil))
                    } else {
                        result(notificationId)
                    }
                }
            }
        }
    }

    private func cancelNotification(notificationId: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [String(notificationId)])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [String(notificationId)])
    }

    private func cancelForReminder(reminderId: String) {
        let hashId = String(abs(reminderId.hashValue))
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderId, hashId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [reminderId, hashId])
    }

    private func getScheduledIds(result: @escaping FlutterResult) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.compactMap { Int($0.identifier) }
            DispatchQueue.main.async {
                result(ids)
            }
        }
    }

    private func reconcileNotifications(
        toSchedule: [[String: Any]],
        knownIds: [Int],
        result: @escaping FlutterResult
    ) {
        // Sort toSchedule ascending by scheduledTimeUtc and take top 60
        let sorted = toSchedule.compactMap { item -> (Date, [String: Any])? in
            let dateStr = (item["scheduledTimeUtc"] as? String)
                ?? ((item["trigger"] as? [String: Any])?["scheduledTimeUtc"] as? String)
            guard let ds = dateStr, let date = parseIsoDate(ds) else { return nil }
            return (date, item)
        }.sorted { $0.0 < $1.0 }

        let top60 = Array(sorted.prefix(NotificationBridgeImpl.maxScheduledNotifications))
        var scheduledIds: [String] = []
        var failedIds: [String] = []
        var cancelledIds: [Int] = []
        var errors: [String] = []

        let group = DispatchGroup()
        var desiredIds = Set<String>()

        for (_, reminder) in top60 {
            guard let id = reminder["id"] as? String else { continue }
            let nid = (reminder["notificationId"] as? Int) ?? abs(id.hashValue)
            desiredIds.insert(String(nid))
            desiredIds.insert(id)

            group.enter()
            scheduleNotification(reminderData: reminder) { res in
                if res is FlutterError {
                    failedIds.append(id)
                    errors.append("Failed to schedule \(id)")
                } else {
                    scheduledIds.append(id)
                }
                group.leave()
            }
        }

        UNUserNotificationCenter.current().getPendingNotificationRequests { pending in
            for req in pending {
                if !desiredIds.contains(req.identifier) {
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [req.identifier])
                    if let intId = Int(req.identifier) {
                        cancelledIds.append(intId)
                    }
                }
            }

            group.notify(queue: .main) {
                result([
                    "scheduledIds": scheduledIds,
                    "failedIds": failedIds,
                    "cancelledIds": cancelledIds,
                    "errors": errors
                ])
            }
        }
    }

    private func mapCategoryId(_ rawCategory: String) -> String {
        switch rawCategory.lowercased() {
        case "call":
            return NotificationBridgeImpl.categoryCall
        case "text":
            return NotificationBridgeImpl.categoryText
        case "url", "open_url":
            return NotificationBridgeImpl.categoryUrl
        default:
            return NotificationBridgeImpl.categoryGeneral
        }
    }

    private func parseIsoDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: str) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: str)
    }
}
