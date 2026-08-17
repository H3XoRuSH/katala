import 'package:katala/platform/bridges/action_bridge.dart';

/// In-memory fake implementation of [ActionBridge] recording all launched intents.
class FakeActionBridge implements ActionBridge {
  final List<String> launchedDialerNumbers = [];
  final List<({String phone, String? message})> launchedSms = [];
  final List<String> launchedUrls = [];

  bool shouldSucceed = true;

  @override
  Future<bool> launchDialer(String phoneNumber) async {
    if (!shouldSucceed) return false;
    launchedDialerNumbers.add(phoneNumber);
    return true;
  }

  @override
  Future<bool> launchSms(String phoneNumber, {String? message}) async {
    if (!shouldSucceed) return false;
    launchedSms.add((phone: phoneNumber, message: message));
    return true;
  }

  @override
  Future<bool> launchUrl(String url) async {
    if (!shouldSucceed) return false;
    launchedUrls.add(url);
    return true;
  }

  void clear() {
    launchedDialerNumbers.clear();
    launchedSms.clear();
    launchedUrls.clear();
  }
}
