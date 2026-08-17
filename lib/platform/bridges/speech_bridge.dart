import '../../domain/enums/speech_availability.dart';

/// Dart abstraction for platform-specific Speech-to-Text (STT) services.
abstract class SpeechBridge {
  /// Queries speech recognition availability on the device.
  Future<SpeechAvailability> get availability;

  /// Returns true if on-device speech recognition is strictly available.
  Future<bool> get isOnDeviceAvailable;

  /// Starts listening to the microphone and emits real-time transcript updates.
  Stream<String> startListening({double? silenceTimeout});

  /// Stops listening and returns the final transcribed text.
  Future<String> stopListening();

  /// Cancels the current speech recognition session without a result.
  Future<void> cancel();

  /// Releases speech recognition resources.
  Future<void> dispose();
}
