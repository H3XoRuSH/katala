import 'dart:async';
import 'package:katala/domain/enums/speech_availability.dart';
import 'package:katala/platform/bridges/speech_bridge.dart';

/// In-memory fake implementation of [SpeechBridge] for deterministic testing.
class FakeSpeechBridge implements SpeechBridge {
  SpeechAvailability mockAvailability;
  bool mockOnDeviceAvailable;
  List<String> transcriptsToEmit;
  Exception? errorToThrow;
  bool isListening = false;
  StreamController<String>? _controller;

  FakeSpeechBridge({
    this.mockAvailability = SpeechAvailability.available,
    this.mockOnDeviceAvailable = true,
    this.transcriptsToEmit = const [],
    this.errorToThrow,
  });

  @override
  Future<SpeechAvailability> get availability async => mockAvailability;

  @override
  Future<bool> get isOnDeviceAvailable async => mockOnDeviceAvailable;

  @override
  Stream<String> startListening({double? silenceTimeout}) {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    isListening = true;
    _controller = StreamController<String>(
      onListen: () {
        for (final transcript in transcriptsToEmit) {
          _controller?.add(transcript);
        }
      },
    );

    return _controller!.stream;
  }

  @override
  Future<String> stopListening() async {
    isListening = false;
    final finalResult = transcriptsToEmit.isNotEmpty ? transcriptsToEmit.last : '';
    unawaited(_controller?.close());
    return finalResult;
  }

  @override
  Future<void> cancel() async {
    isListening = false;
    unawaited(_controller?.close());
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}
