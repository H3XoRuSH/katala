import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../application/providers.dart';
import '../../domain/enums/speech_availability.dart';
import '../../platform/permissions.dart';
import '../theme/colors.dart';
import 'voice_input_overlay.dart';

/// Floating mic button with permission checks & speech availability handling (KATALA_SPEC_V3.md §28.4.2).
class MicButton extends ConsumerWidget {
  final void Function(String transcript) onResult;
  final bool isCompact;

  const MicButton({
    super.key,
    required this.onResult,
    this.isCompact = false,
  });

  Future<void> _handlePress(BuildContext context, WidgetRef ref) async {
    final permissionBridge = ref.read(permissionBridgeProvider);
    final micStatus = await permissionBridge.checkMicrophonePermission();

    if (!micStatus.isGranted) {
      final granted = await permissionBridge.requestMicrophonePermission();
      if (!granted.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required for voice input.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    final speechBridge = ref.read(speechBridgeProvider);
    final availability = await speechBridge.availability;

    if (availability != SpeechAvailability.available) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              availability == SpeechAvailability.permissionDenied
                  ? 'Microphone permission denied for speech recognition.'
                  : 'Speech recognition is unavailable on this device.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      final transcript = await VoiceInputOverlay.show(
        context: context,
      );
      if (transcript != null && transcript.isNotEmpty) {
        onResult(transcript);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isCompact) {
      return IconButton(
        key: const ValueKey('mic_button_compact'),
        icon: const Icon(Icons.mic_rounded),
        color: AppColors.accentPrimary,
        tooltip: 'Voice Input',
        visualDensity: VisualDensity.compact,
        onPressed: () => _handlePress(context, ref),
      );
    }

    return FloatingActionButton(
      onPressed: () => _handlePress(context, ref),
      backgroundColor: AppColors.accentPrimary,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}
