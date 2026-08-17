import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/enums/speech_availability.dart';
import 'speech_bridge.dart';

/// Production [SpeechBridge] implementation using native Flutter [MethodChannel].
class MethodChannelSpeechBridge implements SpeechBridge {
  static const MethodChannel _channel = MethodChannel('com.katala.app/speech');

  StreamController<String>? _transcriptController;
  String _lastTranscript = '';

  MethodChannelSpeechBridge() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onSpeechResult':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final text = (args?['text'] as String?) ?? '';
        _lastTranscript = text;
        if (_transcriptController != null && !_transcriptController!.isClosed) {
          _transcriptController!.add(text);
        }
        break;
      case 'onSpeechError':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final message = (args?['message'] as String?) ?? 'Speech recognition error';
        if (_transcriptController != null && !_transcriptController!.isClosed) {
          _transcriptController!.addError(Exception(message));
        }
        break;
      case 'onEndOfSpeech':
        // Native signals that speech input completed
        break;
    }
  }

  @override
  Future<SpeechAvailability> get availability async {
    try {
      final result = await _channel.invokeMethod<String>('getAvailability');
      switch (result) {
        case 'available':
          return SpeechAvailability.available;
        case 'restricted':
        case 'permission_denied':
          return SpeechAvailability.permissionDenied;
        case 'notSupported':
        case 'not_installed':
        case 'disabled':
        default:
          return SpeechAvailability.unavailable;
      }
    } catch (_) {
      return SpeechAvailability.unavailable;
    }
  }

  @override
  Future<bool> get isOnDeviceAvailable async {
    try {
      final result = await _channel.invokeMethod<bool>('isOnDeviceAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<String> startListening({double? silenceTimeout}) {
    _lastTranscript = '';
    _transcriptController?.close();
    _transcriptController = StreamController<String>.broadcast();

    _channel.invokeMethod<bool>('startListening', {
      'silenceTimeout': silenceTimeout ?? 5.0,
    }).catchError((Object err) {
      if (_transcriptController != null && !_transcriptController!.isClosed) {
        _transcriptController!.addError(err);
      }
      return false;
    });

    return _transcriptController!.stream;
  }

  @override
  Future<String> stopListening() async {
    try {
      await _channel.invokeMethod<bool>('stopListening');
    } catch (_) {}
    return _lastTranscript;
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
    _lastTranscript = '';
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _transcriptController?.close();
    _transcriptController = null;
  }
}
