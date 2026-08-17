import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/delivery_status.dart';
import '../../domain/enums/intent_type.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Interactive reminder tile with swipe actions and intent icons (KATALA_SPEC_V3.md §28.4.2, §28.5, TASK-091, TASK-093).
class ReminderTile extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onDelete;
  final VoidCallback? onLongPress;

  const ReminderTile({
    super.key,
    required this.reminder,
    this.onTap,
    this.onComplete,
    this.onDelete,
    this.onLongPress,
  });

  IconData _getIntentIcon(IntentType type) {
    switch (type) {
      case IntentType.call:
        return Icons.phone_rounded;
      case IntentType.text:
        return Icons.chat_bubble_outline_rounded;
      case IntentType.openUrl:
        return Icons.link_rounded;
      case IntentType.email:
        return Icons.mail_outline_rounded;
      case IntentType.general:
        return Icons.alarm_rounded;
    }
  }

  String _formatTime(DateTime? timeUtc) {
    if (timeUtc == null) return '';
    final localTime = timeUtc.toLocal();
    final formatter = DateFormat('h:mm a');
    return formatter.format(localTime);
  }

  void _showAccessibilityActionSheet(BuildContext context) {
    unawaited(HapticFeedback.mediumImpact());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        reminder.title,
                        style: AppTypography.headline.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              if (onComplete != null)
                ListTile(
                  minLeadingWidth: 32,
                  minVerticalPadding: 16,
                  leading: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 28),
                  title: const Text('Mark as Completed'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(HapticFeedback.lightImpact());
                    onComplete?.call();
                  },
                ),
              if (onTap != null)
                ListTile(
                  minLeadingWidth: 32,
                  minVerticalPadding: 16,
                  leading: const Icon(Icons.edit_outlined, color: AppColors.accentPrimary, size: 28),
                  title: const Text('View / Edit Reminder'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onTap?.call();
                  },
                ),
              if (onDelete != null)
                ListTile(
                  minLeadingWidth: 32,
                  minVerticalPadding: 16,
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                  title: const Text('Delete Reminder'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(HapticFeedback.lightImpact());
                    onDelete?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheduledTime = reminder.trigger?.scheduledTimeUtc;
    final timeStr = _formatTime(scheduledTime);
    final deliveryStatus = reminder.trigger?.deliveryStatus;
    final isUncertain = deliveryStatus == DeliveryStatus.deliveryUncertain;
    final isMissed = deliveryStatus == DeliveryStatus.deliveryMissed;

    final content = InkWell(
      onTap: onTap,
      onLongPress: onLongPress ?? () => _showAccessibilityActionSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkSurfaceElevated : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            // Intent Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIntentIcon(reminder.intentType),
                color: AppColors.accentPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Title & Notes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    reminder.title,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (reminder.notes != null && reminder.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      reminder.notes!,
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Time & Status Indicators
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUncertain) ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.uncertain,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                    ] else if (isMissed) ...[
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      timeStr,
                      style: AppTypography.small.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Semantics(
      label:
          '${reminder.title}, scheduled for $timeStr. Swipe right to complete, swipe left to delete, or long press for actions.',
      button: true,
      child: Dismissible(
        key: Key(reminder.id),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Complete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            unawaited(HapticFeedback.lightImpact());
            onComplete?.call();
            return true;
          } else if (direction == DismissDirection.endToStart) {
            unawaited(HapticFeedback.lightImpact());
            onDelete?.call();
            return true;
          }
          return false;
        },
        child: content,
      ),
    );
  }
}
