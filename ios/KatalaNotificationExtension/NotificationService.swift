import UserNotifications
import Foundation

/**
 * iOS Notification Service Extension for Katala.
 *
 * Intercepts notification payloads before delivery to perform any required
 * modifications or handle background action processing when the app is killed.
 * Must execute within < 1 second.
 */
public class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    public override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let userInfo = request.content.userInfo
        guard let reminderId = (userInfo["reminder_id"] as? String) ?? (userInfo["reminderId"] as? String) else {
            // No reminder ID attached, deliver as is
            contentHandler(bestAttemptContent)
            return
        }

        // Verify database accessibility and schema compatibility in background
        do {
            let database = try ExtensionDatabase()
            try database.validateSchemaVersion()

            // If action metadata is in DB, ensure notification content category is populated
            if let action = try database.getReminderAction(reminderId: reminderId),
               !action.actionType.isEmpty {
                // Ensure appropriate category is attached if not already set
                if bestAttemptContent.categoryIdentifier.isEmpty || bestAttemptContent.categoryIdentifier == "REMINDER_GENERAL" {
                    switch action.actionType.lowercased() {
                    case "call":
                        bestAttemptContent.categoryIdentifier = "REMINDER_CALL"
                    case "text", "sms":
                        bestAttemptContent.categoryIdentifier = "REMINDER_TEXT"
                    case "url", "open_url":
                        bestAttemptContent.categoryIdentifier = "REMINDER_URL"
                    default:
                        break
                    }
                }
            }

            contentHandler(bestAttemptContent)
        } catch {
            // If database is locked, missing, or schema mismatched:
            // deliver notification unmodified so user can still see and tap it to launch the app
            NSLog("[KatalaNotificationExtension] Database check failed: \(error.localizedDescription)")
            contentHandler(bestAttemptContent)
        }
    }

    public override func serviceExtensionTimeWillExpire() {
        // Called directly by the system when the extension is about to run out of time (30s limit)
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
