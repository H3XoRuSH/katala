import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/platform/permissions.dart';
import 'package:permission_handler/permission_handler.dart';
import '../test_helpers/fake_permission_bridge.dart';

void main() {
  group('PermissionBridge & Riverpod Providers', () {
    test('Riverpod providers reactively reflect FakePermissionBridge state', () async {
      final fakeBridge = FakePermissionBridge(
        microphoneStatus: PermissionStatus.granted,
        speechRecognitionStatus: PermissionStatus.granted,
        notificationStatus: PermissionStatus.denied,
        contactsStatus: PermissionStatus.permanentlyDenied,
        exactAlarmStatus: PermissionStatus.restricted,
      );

      final container = ProviderContainer(
        overrides: [
          permissionBridgeProvider.overrideWithValue(fakeBridge),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(microphonePermissionProvider.future), PermissionStatus.granted);
      expect(await container.read(speechRecognitionPermissionProvider.future), PermissionStatus.granted);
      expect(await container.read(notificationPermissionProvider.future), PermissionStatus.denied);
      expect(await container.read(contactsPermissionProvider.future), PermissionStatus.permanentlyDenied);
      expect(await container.read(exactAlarmPermissionProvider.future), PermissionStatus.restricted);
    });
  });
}
