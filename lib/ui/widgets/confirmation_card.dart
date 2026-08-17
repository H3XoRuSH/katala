import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../application/use_cases/create_reminder_use_case.dart';
import '../../domain/entities/parsed_reminder.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/entities/resolved_contact.dart';
import '../../domain/entities/validated_reminder.dart';
import '../../domain/enums/intent_type.dart';
import '../../domain/errors.dart';
import '../../domain/result.dart';
import '../../platform/bridges/method_channel_notification_bridge.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'conflict_warning.dart';

/// Bottom sheet confirmation card for reviewing and saving NLP-parsed reminders (KATALA_SPEC_V3.md §28.4.4, TASK-084).
class ConfirmationCard extends StatefulWidget {
  final ParsedReminder parsed;
  final CreateReminderUseCase createReminderUseCase;
  final ValueChanged<Reminder>? onSaveSuccess;
  final VoidCallback? onCancel;
  final ValueChanged<ParsedReminder>? onEdit;

  const ConfirmationCard({
    super.key,
    required this.parsed,
    required this.createReminderUseCase,
    this.onSaveSuccess,
    this.onCancel,
    this.onEdit,
  });

  /// Static helper to display the confirmation card as a bottom sheet.
  static Future<Reminder?> show({
    required BuildContext context,
    required ParsedReminder parsed,
    required CreateReminderUseCase createReminderUseCase,
  }) {
    return showModalBottomSheet<Reminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConfirmationCard(
        parsed: parsed,
        createReminderUseCase: createReminderUseCase,
        onSaveSuccess: (reminder) {
          Navigator.of(context).pop(reminder);
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  State<ConfirmationCard> createState() => _ConfirmationCardState();
}

class _ConfirmationCardState extends State<ConfirmationCard> with SingleTickerProviderStateMixin {
  late ParsedReminder _currentReminder;
  late TextEditingController _titleEditController;
  late TextEditingController _notesEditController;
  late TextEditingController _urlEditController;

  bool _isSaving = false;
  bool _isSuccess = false;
  bool _isEditing = false;
  String? _errorMessage;

  // Conflict handling state
  List<Reminder>? _conflicts;
  DateTime? _suggestedAlternative;

  // Contact disambiguation state
  List<ResolvedContact>? _contactCandidates;
  ResolvedContact? _selectedContact;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _currentReminder = widget.parsed;
    _titleEditController = TextEditingController(text: _currentReminder.title ?? '');
    _notesEditController = TextEditingController(text: _currentReminder.notes ?? '');
    _urlEditController = TextEditingController(text: _currentReminder.url ?? '');

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _titleEditController.dispose();
    _notesEditController.dispose();
    _urlEditController.dispose();
    _animController.dispose();
    super.dispose();
  }

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

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'No scheduled time';
    return DateFormat('EEE, MMM d, h:mm a').format(dt.toLocal());
  }

  Future<void> _handleSave({bool saveAnyway = false}) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final validated = ValidatedReminder(
      title: _currentReminder.title ?? 'Reminder',
      resolvedContact: _selectedContact,
      phoneNumber: _selectedContact?.phoneNumber ?? _currentReminder.phoneNumber,
      validatedUrl: _currentReminder.url,
      notes: _currentReminder.notes,
      scheduledTime: _currentReminder.scheduledTime ?? DateTime.now().add(const Duration(hours: 1)),
      timezone: _currentReminder.timezone ?? 'UTC',
      intentType: _currentReminder.intentType,
      originalTranscript: _currentReminder.originalTranscript,
    );

    final result = await widget.createReminderUseCase.executeFromValidated(
      validated,
      saveAnyway: saveAnyway,
    );

    if (!mounted) return;

    switch (result) {
      case Success(:final value):
        unawaited(HapticFeedback.heavyImpact().catchError((_) {}));
        unawaited(HapticFeedback.vibrate().catchError((_) {}));
        unawaited(MethodChannelNotificationBridge().playSaveSound());
        setState(() {
          _isSaving = false;
          _isSuccess = true;
          _conflicts = null;
          _contactCandidates = null;
        });
        widget.onSaveSuccess?.call(value);
        unawaited(_animController.forward());
      case Failure(:final error):
        setState(() {
          _isSaving = false;
        });

        if (error is ConflictDetected) {
          setState(() {
            _conflicts = error.conflicts;
            _suggestedAlternative = error.suggestedAlternative;
          });
        } else if (error is ContactDisambiguationRequired) {
          setState(() {
            _contactCandidates = error.candidates;
          });
        } else {
          setState(() {
            _errorMessage = error.userMessage.isNotEmpty ? error.userMessage : "Couldn't save. Try again.";
          });
        }
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initialDate = _currentReminder.scheduledTime ?? now.add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? initialDate : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
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
      _currentReminder = _currentReminder.copyWith(scheduledTime: newDateTime);
    });
  }

  void _saveEditChanges() {
    setState(() {
      _currentReminder = _currentReminder.copyWith(
        title: _titleEditController.text.trim(),
        notes: _notesEditController.text.trim().isNotEmpty ? _notesEditController.text.trim() : null,
        url: _urlEditController.text.trim().isNotEmpty ? _urlEditController.text.trim() : null,
      );
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If success state
    if (_isSuccess) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reminder Saved!',
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
      );
    }

    // If conflict detected state
    if (_conflicts != null && _conflicts!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ConflictWarning(
          conflictingReminders: _conflicts!,
          suggestedAlternative: _suggestedAlternative,
          onSaveAnyway: () => _handleSave(saveAnyway: true),
          onMoveToAlternative: (newTime) {
            setState(() {
              _currentReminder = _currentReminder.copyWith(scheduledTime: newTime);
              _conflicts = null;
            });
            _handleSave();
          },
          onCancel: () {
            setState(() {
              _conflicts = null;
            });
          },
        ),
      );
    }

    // If contact disambiguation state
    if (_contactCandidates != null && _contactCandidates!.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Contact',
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Multiple contacts found for "${_currentReminder.contactName}". Which one did you mean?',
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ..._contactCandidates!.map((contact) {
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(contact.displayName),
                subtitle: contact.phoneNumber != null ? Text(contact.phoneNumber!) : null,
                onTap: () {
                  setState(() {
                    _selectedContact = contact;
                    _currentReminder = _currentReminder.copyWith(
                      contactName: contact.displayName,
                      phoneNumber: contact.phoneNumber,
                    );
                    _contactCandidates = null;
                  });
                  _handleSave();
                },
              );
            }),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _contactCandidates = null;
                  });
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      );
    }

    // Normal Confirmation / Edit Sheet
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
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

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getIntentIcon(_currentReminder.intentType),
                    color: AppColors.accentPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Reminder' : 'Confirm Reminder',
                    style: AppTypography.title.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                if (!_isEditing)
                  IconButton(
                    key: const Key('confirmation_edit_button'),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () {
                      if (widget.onEdit != null) {
                        widget.onEdit!(_currentReminder);
                      } else {
                        setState(() {
                          _isEditing = true;
                        });
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancel',
                  onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error display if any
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.small.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _handleSave(),
                      child: const Text('Retry', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (!_isEditing) ...[
              // Title Preview
              Text(
                _currentReminder.title ?? 'No title',
                key: const Key('confirmation_title_text'),
                style: AppTypography.headline.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Time Tile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_rounded, color: AppColors.accentPrimary),
                title: Text(
                  _formatDateTime(_currentReminder.scheduledTime),
                  key: const Key('confirmation_time_text'),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                subtitle: _currentReminder.timezone != null
                    ? Text(
                        'Timezone: ${_currentReminder.timezone}',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      )
                    : null,
              ),

              // Contact (if any)
              if (_currentReminder.contactName != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline_rounded, color: AppColors.accentPrimary),
                  title: Text(
                    _currentReminder.contactName!,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  subtitle: _currentReminder.phoneNumber != null
                      ? Text(
                          _currentReminder.phoneNumber!,
                          style: AppTypography.caption.copyWith(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        )
                      : null,
                ),
              ],

              // URL (if any)
              if (_currentReminder.url != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_rounded, color: AppColors.accentPrimary),
                  title: Text(
                    _currentReminder.url!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.accentPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Notes (if any)
              if (_currentReminder.notes != null && _currentReminder.notes!.isNotEmpty) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notes_rounded, color: AppColors.accentPrimary),
                  title: Text(
                    _currentReminder.notes!,
                    style: AppTypography.body.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Editable Fields Form
              TextField(
                key: const Key('confirmation_title_edit_input'),
                controller: _titleEditController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  prefixIcon: const Icon(Icons.title_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Time selector
              Material(
                color: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.accentPrimary),
                  title: Text(
                    _formatDateTime(_currentReminder.scheduledTime),
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.edit_calendar_rounded, size: 20),
                  onTap: _pickDateTime,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                key: const Key('confirmation_url_edit_input'),
                controller: _urlEditController,
                decoration: InputDecoration(
                  labelText: 'URL (optional)',
                  prefixIcon: const Icon(Icons.link_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                key: const Key('confirmation_notes_edit_input'),
                controller: _notesEditController,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Apply Edits'),
                  onPressed: _saveEditChanges,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
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
                    key: const Key('confirmation_save_button'),
                    onPressed: _isSaving ? null : () => _handleSave(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
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
    );
  }
}
