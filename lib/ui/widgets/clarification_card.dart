import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/parsed_reminder.dart';
import '../../domain/enums/validation_issue.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Clarification card shown when NLP validation encounters missing, ambiguous, or invalid data (KATALA_SPEC_V3.md §28.4.5, TASK-085).
class ClarificationCard extends StatefulWidget {
  final ParsedReminder initialDraft;
  final ValueChanged<ParsedReminder> onSave;
  final VoidCallback onCancel;

  const ClarificationCard({
    super.key,
    required this.initialDraft,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<ClarificationCard> createState() => _ClarificationCardState();
}

class _ClarificationCardState extends State<ClarificationCard> {
  late TextEditingController _titleController;
  late TextEditingController _contactController;
  late TextEditingController _urlController;
  late TextEditingController _notesController;

  DateTime? _scheduledTime;
  String? _selectedAmPm; // 'AM' or 'PM'

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialDraft.title ?? '');
    _contactController = TextEditingController(text: widget.initialDraft.contactName ?? '');
    _urlController = TextEditingController(text: widget.initialDraft.url ?? '');
    _notesController = TextEditingController(text: widget.initialDraft.notes ?? '');
    _scheduledTime = widget.initialDraft.scheduledTime;

    _titleController.addListener(_onFieldChanged);
    _contactController.addListener(_onFieldChanged);
    _urlController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contactController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  bool get _isTimeInPast {
    if (_scheduledTime == null) return false;
    return _scheduledTime!.toUtc().isBefore(DateTime.now().toUtc());
  }

  bool get _isValid {
    final titleValid = _titleController.text.trim().isNotEmpty;
    final timeValid = _scheduledTime != null && !_isTimeInPast;
    return titleValid && timeValid;
  }

  void _handleQuickChipSelected(String choice) {
    final now = DateTime.now();
    DateTime target;

    switch (choice) {
      case 'Later today':
        target = now.add(const Duration(hours: 3));
        break;
      case 'Tomorrow 9 AM':
        target = DateTime(now.year, now.month, now.day + 1, 9, 0);
        break;
      case 'Tomorrow 5 PM':
        target = DateTime(now.year, now.month, now.day + 1, 17, 0);
        break;
      case 'Tonight 8 PM':
        target = DateTime(now.year, now.month, now.day, 20, 0);
        if (target.isBefore(now)) {
          target = target.add(const Duration(days: 1));
        }
        break;
      default:
        target = now.add(const Duration(hours: 1));
    }

    setState(() {
      _scheduledTime = target;
    });
  }

  void _handleAmPmToggle(String amPm) {
    _selectedAmPm = amPm;
    if (_scheduledTime != null) {
      int hour = _scheduledTime!.hour;
      final minute = _scheduledTime!.minute;
      if (amPm == 'AM' && hour >= 12) {
        hour -= 12;
      } else if (amPm == 'PM' && hour < 12) {
        hour += 12;
      }
      var newTime = DateTime(
        _scheduledTime!.year,
        _scheduledTime!.month,
        _scheduledTime!.day,
        hour,
        minute,
      );
      // If newly calculated time is in past, push to next day
      if (newTime.isBefore(DateTime.now())) {
        newTime = newTime.add(const Duration(days: 1));
      }
      setState(() {
        _scheduledTime = newTime;
      });
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _scheduledTime ?? now;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? initialDate : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final initialTime = TimeOfDay.fromDateTime(_scheduledTime ?? now.add(const Duration(hours: 1)));
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime == null || !mounted) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _scheduledTime = newDateTime;
    });
  }

  void _submit() {
    if (!_isValid) return;

    final updated = widget.initialDraft.copyWith(
      title: _titleController.text.trim(),
      scheduledTime: _scheduledTime,
      contactName: _contactController.text.trim().isNotEmpty ? _contactController.text.trim() : null,
      url: _urlController.text.trim().isNotEmpty ? _urlController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      issues: const [],
    );

    widget.onSave(updated);
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'No time set';
    return DateFormat('EEE, MMM d, h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final issues = widget.initialDraft.issues;

    final hasMissingTitle = issues.contains(ValidationIssue.missingTitle) || _titleController.text.trim().isEmpty;
    final hasMissingTime = issues.contains(ValidationIssue.missingTime) || _scheduledTime == null;
    final hasAmbiguousTime = issues.contains(ValidationIssue.ambiguousTime);
    final hasTimeInPast = issues.contains(ValidationIssue.timeInPast) || _isTimeInPast;
    final hasContactIssue = issues.contains(ValidationIssue.ambiguousContact) ||
        issues.contains(ValidationIssue.unresolvedContact) ||
        issues.contains(ValidationIssue.contactNotFound);
    final hasUrlIssue = issues.contains(ValidationIssue.invalidUrl);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: AppColors.accentSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clarification Needed',
                          style: AppTypography.title.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        if (widget.initialDraft.originalTranscript.isNotEmpty)
                          Text(
                            '"${widget.initialDraft.originalTranscript}"',
                            style: AppTypography.small.copyWith(
                              fontStyle: FontStyle.italic,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onCancel,
                    tooltip: 'Cancel',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Specific Issue 1: Missing Title
              if (hasMissingTitle) ...[
                Text(
                  'What should I remind you about?',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('clarification_title_input'),
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Buy groceries, Call mom',
                    prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Standard Title Editor
                TextField(
                  key: const Key('clarification_title_input'),
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Reminder Title',
                    prefixIcon: const Icon(Icons.title_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Specific Issue 2: Ambiguous Time (AM vs PM)
              if (hasAmbiguousTime) ...[
                Text(
                  'Did you mean AM or PM?',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      key: const Key('am_choice_chip'),
                      label: const Text('AM (Morning)'),
                      selected: _selectedAmPm == 'AM',
                      onSelected: (_) => _handleAmPmToggle('AM'),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      key: const Key('pm_choice_chip'),
                      label: const Text('PM (Evening)'),
                      selected: _selectedAmPm == 'PM',
                      onSelected: (_) => _handleAmPmToggle('PM'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Specific Issue 3: Missing Time or Time in Past
              if (hasMissingTime || hasTimeInPast) ...[
                Text(
                  hasTimeInPast ? 'That time has passed. Pick a future time.' : 'When should I remind you?',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: hasTimeInPast
                        ? AppColors.error
                        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      key: const Key('chip_later_today'),
                      avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                      label: const Text('Later today'),
                      onPressed: () => _handleQuickChipSelected('Later today'),
                    ),
                    ActionChip(
                      key: const Key('chip_tomorrow_9am'),
                      avatar: const Icon(Icons.wb_twilight_rounded, size: 16),
                      label: const Text('Tomorrow 9 AM'),
                      onPressed: () => _handleQuickChipSelected('Tomorrow 9 AM'),
                    ),
                    ActionChip(
                      key: const Key('chip_tomorrow_5pm'),
                      avatar: const Icon(Icons.nightlight_round_outlined, size: 16),
                      label: const Text('Tomorrow 5 PM'),
                      onPressed: () => _handleQuickChipSelected('Tomorrow 5 PM'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Date & Time Selector Tile
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isTimeInPast
                        ? AppColors.error
                        : (_scheduledTime == null ? AppColors.warning : Colors.transparent),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 20,
                      color: _isTimeInPast ? AppColors.error : AppColors.accentPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _formatDateTime(_scheduledTime),
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _isTimeInPast
                              ? AppColors.error
                              : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('clarification_time_picker_button'),
                      onPressed: _pickDateTime,
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text('Pick Time'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Specific Issue 4: Contact Resolution
              if (hasContactIssue || widget.initialDraft.contactName != null) ...[
                Text(
                  'Who would you like to contact?',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('clarification_contact_input'),
                  controller: _contactController,
                  decoration: InputDecoration(
                    hintText: 'Contact name or phone number',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Specific Issue 5: Invalid URL
              if (hasUrlIssue || widget.initialDraft.url != null) ...[
                Text(
                  'Please check the website URL:',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('clarification_url_input'),
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'https://...',
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Optional Notes
              TextField(
                key: const Key('clarification_notes_input'),
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons: Save & Cancel
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('clarification_save_button'),
                      onPressed: _isValid ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save Reminder',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
