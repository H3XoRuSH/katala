import 'package:katala/platform/permissions.dart';
import 'package:permission_handler/permission_handler.dart';

/// In-memory fake implementation of [PermissionBridge] for testing UI and providers.
class FakePermissionBridge implements PermissionBridge {
  PermissionStatus microphoneStatus;
  PermissionStatus speechRecognitionStatus;
  PermissionStatus notificationStatus;
  PermissionStatus contactsStatus;
  PermissionStatus exactAlarmStatus;
  bool appSettingsOpened = false;

  FakePermissionBridge({
    this.microphoneStatus = PermissionStatus.granted,
    this.speechRecognitionStatus = PermissionStatus.granted,
    this.notificationStatus = PermissionStatus.granted,
    this.contactsStatus = PermissionStatus.granted,
    this.exactAlarmStatus = PermissionStatus.granted,
  });

  @override
  Future<PermissionStatus> checkMicrophonePermission() async => microphoneStatus;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async => microphoneStatus;

  @override
  Future<PermissionStatus> checkSpeechRecognitionPermission() async => speechRecognitionStatus;

  @override
  Future<PermissionStatus> requestSpeechRecognitionPermission() async => speechRecognitionStatus;

  @override
  Future<PermissionStatus> checkNotificationPermission() async => notificationStatus;

  @override
  Future<PermissionStatus> requestNotificationPermission() async => notificationStatus;

  @override
  Future<PermissionStatus> checkContactsPermission() async => contactsStatus;

  @override
  Future<PermissionStatus> requestContactsPermission() async => contactsStatus;

  @override
  Future<PermissionStatus> checkExactAlarmPermission() async => exactAlarmStatus;

  @override
  Future<PermissionStatus> requestExactAlarmPermission() async => exactAlarmStatus;

  @override
  Future<bool> openAppSettings() async {
    appSettingsOpened = true;
    return true;
  }
}
