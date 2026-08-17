import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/providers.dart';
import '../../domain/entities/parsed_reminder.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'mic_button.dart';

/// Always-available text input field with 300ms debounced real-time NLP parsing (KATALA_SPEC_V3.md §6.3, TASK-088).
class TextInputField extends ConsumerStatefulWidget {
  final void Function(String text) onSubmit;
  final void Function(String transcript)? onVoiceResult;
  final String? hintText;

  const TextInputField({
    super.key,
    required this.onSubmit,
    this.onVoiceResult,
    this.hintText,
  });

  @override
  ConsumerState<TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends ConsumerState<TextInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  ParsedReminder? _livePreview;
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = _controller.text;
    final hasInput = text.trim().isNotEmpty;
    if (_hasInput != hasInput) {
      setState(() {
        _hasInput = hasInput;
      });
    }

    _debounceTimer?.cancel();
    if (text.trim().isEmpty) {
      if (_livePreview != null) {
        setState(() {
          _livePreview = null;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final pipeline = ref.read(nlpPipelineProvider);
      final clock = ref.read(clockProvider);
      final parsed = pipeline.parse(text.trim(), clock: clock);
      setState(() {
        _livePreview = parsed;
      });
    });
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _debounceTimer?.cancel();
    _controller.clear();
    setState(() {
      _livePreview = null;
      _hasInput = false;
    });
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onSubmit(text);
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
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

    return Column(
      key: const ValueKey('text_input_column'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live NLP Preview Pill with AnimatedSwitcher to prevent layout re-seating
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: (_hasInput && _livePreview != null)
              ? Container(
                  key: const ValueKey('live_nlp_preview_pill'),
                  margin: const EdgeInsets.only(bottom: 8),
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
                          _livePreview!.title ?? 'Parsing reminder...',
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

        // Input Bar (Explicitly keyed to maintain keyboard focus)
        Container(
          key: const ValueKey('text_input_bar_container'),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.only(left: 18, right: 6, top: 4, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('text_input_field_textfield'),
                  controller: _controller,
                  focusNode: _focusNode,
                  maxLength: 500,
                  onChanged: (_) => _onTextChanged(),
                  style: AppTypography.body.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Type a reminder (e.g. "Meeting at 3pm")...',
                    hintStyle: AppTypography.body.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
              if (_hasInput)
                IconButton(
                  key: const ValueKey('text_input_submit_button'),
                  icon: const Icon(Icons.arrow_upward_rounded),
                  color: AppColors.accentPrimary,
                  visualDensity: VisualDensity.compact,
                  onPressed: _handleSubmit,
                )
              else if (widget.onVoiceResult != null)
                MicButton(
                  isCompact: true,
                  onResult: widget.onVoiceResult!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
