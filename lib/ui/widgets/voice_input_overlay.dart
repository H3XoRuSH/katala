import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/providers.dart';
import '../../domain/entities/parsed_reminder.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Modal overlay for voice input with waveform animation, live transcript, real-time AI understanding pill, and 30s auto-stop (KATALA_SPEC_V3.md §28.4.3).
class VoiceInputOverlay extends ConsumerStatefulWidget {
  final void Function(String transcript)? onResult;
  final VoidCallback? onCancel;

  const VoiceInputOverlay({
    super.key,
    this.onResult,
    this.onCancel,
  });

  /// Static helper to display the voice overlay as a bottom sheet.
  static Future<String?> show({
    required BuildContext context,
    void Function(String transcript)? onResult,
    VoidCallback? onCancel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceInputOverlay(
        onResult: onResult,
        onCancel: onCancel,
      ),
    );
  }

  @override
  ConsumerState<VoiceInputOverlay> createState() => _VoiceInputOverlayState();
}

class _VoiceInputOverlayState extends ConsumerState<VoiceInputOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  StreamSubscription<String>? _speechSubscription;
  Timer? _autoStopTimer;

  String _currentTranscript = '';
  ParsedReminder? _livePreview;
  String? _errorMessage;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startListeningSession();
  }

  void _startListeningSession() {
    try {
      final speechBridge = ref.read(speechBridgeProvider);

      _isListening = true;
      _errorMessage = null;
      _currentTranscript = '';
      _livePreview = null;

      _speechSubscription = speechBridge.startListening().listen(
        (transcript) {
          if (mounted) {
            final pipeline = ref.read(nlpPipelineProvider);
            final clock = ref.read(clockProvider);
            final parsed = transcript.trim().isNotEmpty ? pipeline.parse(transcript.trim(), clock: clock) : null;

            setState(() {
              _currentTranscript = transcript;
              _livePreview = parsed;
            });
          }
        },
        onError: (Object err) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Speech recognition error: $err';
              _isListening = false;
            });
            _pulseController.stop();
          }
        },
      );

      // Auto-stop after 30 seconds
      _autoStopTimer = Timer(const Duration(seconds: 30), () {
        _stopListeningSession();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not start voice session: $e';
          _isListening = false;
        });
        _pulseController.stop();
      }
    }
  }

  void _stopListeningSession() {
    _autoStopTimer?.cancel();
    _pulseController.stop();

    final textToUse = _currentTranscript.trim();

    try {
      final speechBridge = ref.read(speechBridgeProvider);
      speechBridge.stopListening();
    } catch (_) {}

    _speechSubscription?.cancel();
    _speechSubscription = null;

    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(textToUse);
      }
      if (textToUse.isNotEmpty) {
        widget.onResult?.call(textToUse);
      }
    }
  }

  void _cancelSession() {
    _autoStopTimer?.cancel();
    _pulseController.stop();

    try {
      final speechBridge = ref.read(speechBridgeProvider);
      speechBridge.cancel();
    } catch (_) {}

    _speechSubscription?.cancel();
    _speechSubscription = null;

    if (mounted) {
      widget.onCancel?.call();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _speechSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;

    final scheduledTime = _livePreview?.scheduledTime;
    String? timeStr;
    if (scheduledTime != null) {
      timeStr = DateFormat('MMM d, h:mm a').format(scheduledTime.toLocal());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar with Cancel
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Listening...',
                  style: AppTypography.title.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                IconButton(
                  key: const Key('cancel_voice_button'),
                  icon: const Icon(Icons.close_rounded),
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  onPressed: _cancelSession,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live AI Understanding Pill in Voice Mode
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: (_currentTranscript.trim().isNotEmpty && _livePreview != null && _livePreview!.title != null)
                  ? Container(
                      key: const ValueKey('voice_live_nlp_preview_pill'),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.accentPrimary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: AppColors.accentPrimary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _livePreview!.title!,
                              style: AppTypography.small.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
                              style: AppTypography.small.copyWith(
                                color: AppColors.accentPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Live Transcript Display
            Container(
              constraints: const BoxConstraints(minHeight: 80, maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _errorMessage ??
                      (_currentTranscript.isEmpty
                          ? 'Speak now (e.g. "Remind me to call Adam tomorrow at 3pm")'
                          : _currentTranscript),
                  style: AppTypography.body.copyWith(
                    color: _errorMessage != null
                        ? AppColors.error
                        : (_currentTranscript.isEmpty
                            ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    fontStyle: _currentTranscript.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Pulsing Mic FAB
            InkWell(
              key: const Key('stop_listening_button'),
              onTap: _stopListeningSession,
              borderRadius: BorderRadius.circular(40),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentPrimary,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPrimary.withValues(
                              alpha: _isListening ? 0.3 : 0.15,
                            ),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tap to Stop & Save',
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
