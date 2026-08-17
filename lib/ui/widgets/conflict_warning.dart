import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/reminder.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Warning display shown when a new reminder conflicts with existing ones within ±15 minutes (KATALA_SPEC_V3.md §18, TASK-086).
class ConflictWarning extends StatelessWidget {
  final List<Reminder> conflictingReminders;
  final DateTime? suggestedAlternative;
  final VoidCallback onSaveAnyway;
  final ValueChanged<DateTime>? onMoveToAlternative;
  final VoidCallback onCancel;

  const ConflictWarning({
    super.key,
    required this.conflictingReminders,
    this.suggestedAlternative,
    required this.onSaveAnyway,
    this.onMoveToAlternative,
    required this.onCancel,
  });

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time.toLocal());
  }

  String _formatDateTime(DateTime time) {
    return DateFormat('MMM d, h:mm a').format(time.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstConflict = conflictingReminders.isNotEmpty ? conflictingReminders.first : null;
    final firstTitle = firstConflict?.title ?? 'Existing Reminder';
    final firstTime =
        firstConflict?.trigger?.scheduledTimeUtc != null ? _formatTime(firstConflict!.trigger!.scheduledTimeUtc) : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Schedule Conflict',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'This overlaps with "$firstTitle"${firstTime.isNotEmpty ? ' at $firstTime' : ''}',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Conflicting Reminders List
          if (conflictingReminders.isNotEmpty) ...[
            Text(
              'Conflicting Reminders:',
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: conflictingReminders.map((reminder) {
                  final timeStr = reminder.trigger?.scheduledTimeUtc != null
                      ? _formatDateTime(reminder.trigger!.scheduledTimeUtc)
                      : 'No time';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reminder.title,
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                        Text(
                          timeStr,
                          style: AppTypography.small.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Action 1: Move to Alternative (Primary)
          if (suggestedAlternative != null && onMoveToAlternative != null) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => onMoveToAlternative!(suggestedAlternative!),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text('Move to ${_formatTime(suggestedAlternative!)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Action 2: Save Anyway (Secondary)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: onSaveAnyway,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save Anyway'),
            ),
          ),
          const SizedBox(height: 8),

          // Action 3: Cancel (Tertiary)
          Center(
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
