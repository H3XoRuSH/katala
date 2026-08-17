import 'package:flutter/services.dart';
import 'action_bridge.dart';

/// Production [ActionBridge] implementation using native Flutter [MethodChannel].
class MethodChannelActionBridge implements ActionBridge {
  static const MethodChannel _channel = MethodChannel('com.katala.app/actions');

  @override
  Future<bool> launchDialer(String phoneNumber) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchDialer', {
        'phoneNumber': phoneNumber,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> launchSms(String phoneNumber, {String? message}) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> launchUrl(String url) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchUrl', {
        'url': url,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
