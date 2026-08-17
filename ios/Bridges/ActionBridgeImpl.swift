import Foundation
import Flutter
import UIKit

/**
 * Native iOS ActionBridge implementation.
 *
 * Executes OS intents:
 * - tel: URL scheme (prompts native system dialer confirmation)
 * - sms: URL scheme (opens compose sheet)
 * - http / https URLs (opens system browser, strictly rejects non-web schemes)
 */
public class ActionBridgeImpl: NSObject {

    public static let channelName = "com.katala.app/actions"

    private let channel: FlutterMethodChannel

    public init(messenger: FlutterBinaryMessenger) {
        self.channel = FlutterMethodChannel(name: ActionBridgeImpl.channelName, binaryMessenger: messenger)
        super.init()
        self.channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "launchDialer":
            guard let args = call.arguments as? [String: Any],
                  let phoneNumber = args["phoneNumber"] as? String,
                  !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                result(FlutterError(code: "INVALID_PHONE", message: "Phone number is required", details: nil))
                return
            }
            launchDialer(phoneNumber: phoneNumber, result: result)

        case "launchSms":
            guard let args = call.arguments as? [String: Any],
                  let phoneNumber = args["phoneNumber"] as? String,
                  !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                result(FlutterError(code: "INVALID_PHONE", message: "Phone number is required", details: nil))
                return
            }
            let message = args["message"] as? String
            launchSms(phoneNumber: phoneNumber, message: message, result: result)

        case "launchUrl":
            guard let args = call.arguments as? [String: Any],
                  let urlString = args["url"] as? String,
                  !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                result(FlutterError(code: "INVALID_URL", message: "URL is required", details: nil))
                return
            }
            launchUrl(urlString: urlString, result: result)

        case "dispose":
            channel.setMethodCallHandler(nil)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func launchDialer(phoneNumber: String, result: @escaping FlutterResult) {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "tel:\(encoded)") else {
            result(FlutterError(code: "INVALID_PHONE", message: "Cannot construct dialer URL for \(phoneNumber)", details: nil))
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "CANNOT_LAUNCH", message: "Failed to launch dialer", details: nil))
                }
            }
        }
    }

    private func launchSms(phoneNumber: String, message: String?, result: @escaping FlutterResult) {
        let trimmed = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encodedPhone = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            result(FlutterError(code: "INVALID_PHONE", message: "Invalid phone number: \(phoneNumber)", details: nil))
            return
        }

        var urlString = "sms:\(encodedPhone)"
        if let message = message, !message.isEmpty,
           let encodedBody = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&body=\(encodedBody)"
        }

        guard let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_PHONE", message: "Cannot construct SMS URL", details: nil))
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "CANNOT_LAUNCH", message: "Failed to launch SMS", details: nil))
                }
            }
        }
    }

    private func launchUrl(urlString: String, result: @escaping FlutterResult) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased() else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid URL string: \(urlString)", details: nil))
            return
        }

        // Strict validation: only HTTP and HTTPS schemes are permitted
        guard scheme == "http" || scheme == "https" else {
            result(FlutterError(code: "INVALID_URL", message: "Only HTTP and HTTPS URLs are permitted. Disallowed scheme: \(scheme)", details: nil))
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "CANNOT_LAUNCH", message: "Failed to open URL", details: nil))
                }
            }
        }
    }
}
