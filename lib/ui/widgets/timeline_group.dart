import 'package:flutter/material.dart';
import '../../domain/entities/reminder.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'reminder_tile.dart';

/// Collapsible timeline section header with count badge and reminder items (KATALA_SPEC_V3.md §28.4.2).
class TimelineGroup extends StatefulWidget {
  final String title;
  final List<Reminder> reminders;
  final bool initialExpanded;
  final Color? accentColor;
  final void Function(Reminder)? onTapReminder;
  final void Function(Reminder)? onCompleteReminder;
  final void Function(Reminder)? onDeleteReminder;
  final void Function(Reminder)? onLongPressReminder;

  const TimelineGroup({
    super.key,
    required this.title,
    required this.reminders,
    this.initialExpanded = true,
    this.accentColor,
    this.onTapReminder,
    this.onCompleteReminder,
    this.onDeleteReminder,
    this.onLongPressReminder,
  });

  @override
  State<TimelineGroup> createState() => _TimelineGroupState();
}

class _TimelineGroupState extends State<TimelineGroup> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reminders.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = widget.accentColor ?? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.arrow_drop_down_rounded : Icons.arrow_right_rounded,
                  color: headerColor,
                  size: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.title.toUpperCase(),
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: headerColor,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.reminders.length}',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: headerColor,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Group Content
        if (_isExpanded)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: widget.reminders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final reminder = widget.reminders[index];
              return ReminderTile(
                reminder: reminder,
                onTap: () => widget.onTapReminder?.call(reminder),
                onComplete: () => widget.onCompleteReminder?.call(reminder),
                onDelete: () => widget.onDeleteReminder?.call(reminder),
                onLongPress: () => widget.onLongPressReminder?.call(reminder),
              );
            },
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}
