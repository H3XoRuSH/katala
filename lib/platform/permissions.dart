import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Contract for checking and requesting OS permissions.
abstract class PermissionBridge {
  Future<ph.PermissionStatus> checkMicrophonePermission();
  Future<ph.PermissionStatus> requestMicrophonePermission();

  Future<ph.PermissionStatus> checkSpeechRecognitionPermission();
  Future<ph.PermissionStatus> requestSpeechRecognitionPermission();

  Future<ph.PermissionStatus> checkNotificationPermission();
  Future<ph.PermissionStatus> requestNotificationPermission();

  Future<ph.PermissionStatus> checkContactsPermission();
  Future<ph.PermissionStatus> requestContactsPermission();

  Future<ph.PermissionStatus> checkExactAlarmPermission();
  Future<ph.PermissionStatus> requestExactAlarmPermission();

  Future<bool> openAppSettings();
}

/// Default implementation using `permission_handler`.
class PermissionBridgeImpl implements PermissionBridge {
  const PermissionBridgeImpl();

  @override
  Future<ph.PermissionStatus> checkMicrophonePermission() => ph.Permission.microphone.status;

  @override
  Future<ph.PermissionStatus> requestMicrophonePermission() => ph.Permission.microphone.request();

  @override
  Future<ph.PermissionStatus> checkSpeechRecognitionPermission() => ph.Permission.speech.status;

  @override
  Future<ph.PermissionStatus> requestSpeechRecognitionPermission() => ph.Permission.speech.request();

  @override
  Future<ph.PermissionStatus> checkNotificationPermission() => ph.Permission.notification.status;

  @override
  Future<ph.PermissionStatus> requestNotificationPermission() => ph.Permission.notification.request();

  @override
  Future<ph.PermissionStatus> checkContactsPermission() => ph.Permission.contacts.status;

  @override
  Future<ph.PermissionStatus> requestContactsPermission() => ph.Permission.contacts.request();

  @override
  Future<ph.PermissionStatus> checkExactAlarmPermission() => ph.Permission.scheduleExactAlarm.status;

  @override
  Future<ph.PermissionStatus> requestExactAlarmPermission() => ph.Permission.scheduleExactAlarm.request();

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();
}

// ----------------------------------------------------------------------
// Riverpod Providers (ARCHITECTURE.md §20.2)
// ----------------------------------------------------------------------

final permissionBridgeProvider = Provider<PermissionBridge>((ref) {
  return const PermissionBridgeImpl();
});

final microphonePermissionProvider = FutureProvider<ph.PermissionStatus>((ref) {
  return ref.watch(permissionBridgeProvider).checkMicrophonePermission();
});

final speechRecognitionPermissionProvider = FutureProvider<ph.PermissionStatus>((ref) {
  return ref.watch(permissionBridgeProvider).checkSpeechRecognitionPermission();
});

final notificationPermissionProvider = FutureProvider<ph.PermissionStatus>((ref) {
  return ref.watch(permissionBridgeProvider).checkNotificationPermission();
});

final contactsPermissionProvider = FutureProvider<ph.PermissionStatus>((ref) {
  return ref.watch(permissionBridgeProvider).checkContactsPermission();
});

final exactAlarmPermissionProvider = FutureProvider<ph.PermissionStatus>((ref) {
  return ref.watch(permissionBridgeProvider).checkExactAlarmPermission();
});
