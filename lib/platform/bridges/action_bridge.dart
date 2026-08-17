/// Dart abstraction for executing external OS intents (dialer, SMS, browser).
abstract class ActionBridge {
  /// Opens the native phone dialer prefilled with [phoneNumber].
  Future<bool> launchDialer(String phoneNumber);

  /// Opens the native SMS application prefilled with [phoneNumber] and optional [message].
  Future<bool> launchSms(String phoneNumber, {String? message});

  /// Opens an external URL in the default system web browser.
  Future<bool> launchUrl(String url);
}
