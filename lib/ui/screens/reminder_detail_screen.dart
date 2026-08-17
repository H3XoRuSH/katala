import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../application/providers.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/action_type.dart';
import '../../domain/enums/delivery_status.dart';
import '../../domain/enums/intent_type.dart';
import '../../domain/enums/reminder_status.dart';
import '../../domain/result.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Full reminder detail screen with lifecycle actions and inline editing (KATALA_SPEC_V3.md §28.4.6, TASK-087).
class ReminderDetailScreen extends ConsumerStatefulWidget {
  final Reminder reminder;

  const ReminderDetailScreen({
    super.key,
    required this.reminder,
  });

  @override
  ConsumerState<ReminderDetailScreen> createState() => _ReminderDetailScreenState();
}

class _ReminderDetailScreenState extends ConsumerState<ReminderDetailScreen> {
  late Reminder _currentReminder;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _titleController;
  late TextEditingController _notesController;
  DateTime? _scheduledTime;

  @override
  void initState() {
    super.initState();
    _currentReminder = widget.reminder;
    _initControllers();
  }

  void _initControllers() {
    _titleController = TextEditingController(text: _currentReminder.title);
    _notesController = TextEditingController(text: _currentReminder.notes ?? '');
    _scheduledTime = _currentReminder.trigger?.scheduledTimeUtc.toLocal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isTerminalState =>
      _currentReminder.status == ReminderStatus.completed || _currentReminder.status == ReminderStatus.dismissed;

  bool get _isOverdue {
    final sched = _currentReminder.trigger?.scheduledTimeUtc;
    if (sched == null) return false;
    final isPendingOrSnoozed =
        _currentReminder.status == ReminderStatus.pending || _currentReminder.status == ReminderStatus.snoozed;
    final now = ref.read(clockProvider).now().toUtc();
    final nowMinuteUtc = DateTime.utc(now.year, now.month, now.day, now.hour, now.minute);
    return isPendingOrSnoozed && sched.isBefore(nowMinuteUtc);
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('EEE, MMM d, yyyy  h:mm a').format(dt.toLocal());
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

  Color _getStatusColor(ReminderStatus status) {
    if (_isOverdue) {
      return AppColors.error;
    }
    switch (status) {
      case ReminderStatus.pending:
        return AppColors.accentPrimary;
      case ReminderStatus.snoozed:
        return AppColors.accentSecondary;
      case ReminderStatus.completed:
        return AppColors.success;
      case ReminderStatus.dismissed:
        return AppColors.error;
    }
  }

  Color _getDeliveryColor(DeliveryStatus? status, DateTime? firedAt) {
    if (firedAt != null) {
      return AppColors.success;
    }
    if (_isOverdue) {
      if (status == DeliveryStatus.deliveryUncertain) return AppColors.warning;
      return AppColors.error;
    }
    switch (status) {
      case DeliveryStatus.deliveryUncertain:
        return AppColors.warning;
      case DeliveryStatus.deliveryMissed:
        return AppColors.error;
      case DeliveryStatus.scheduled:
      default:
        return AppColors.accentPrimary;
    }
  }

  String _getDeliveryStatusText(DeliveryStatus? status, DateTime? firedAt) {
    if (firedAt != null) {
      return 'Delivery: Delivered';
    }
    if (_isOverdue) {
      switch (status) {
        case DeliveryStatus.deliveryUncertain:
          return 'Delivery: Uncertain (May not have arrived)';
        case DeliveryStatus.deliveryMissed:
          return 'Delivery: Missed';
        case DeliveryStatus.scheduled:
        default:
          return 'Delivery: Overdue';
      }
    }
    switch (status) {
      case DeliveryStatus.deliveryUncertain:
        return 'Delivery: Uncertain (May not have arrived)';
      case DeliveryStatus.deliveryMissed:
        return 'Delivery: Missed';
      case DeliveryStatus.scheduled:
      default:
        return 'Delivery: Scheduled';
    }
  }

  IconData _getDeliveryIcon(DeliveryStatus? status, DateTime? firedAt) {
    if (firedAt != null) {
      return Icons.check_circle_outline_rounded;
    }
    if (_isOverdue) {
      if (status == DeliveryStatus.deliveryUncertain) {
        return Icons.warning_amber_rounded;
      }
      return Icons.alarm_off_rounded;
    }
    switch (status) {
      case DeliveryStatus.deliveryUncertain:
        return Icons.warning_amber_rounded;
      case DeliveryStatus.deliveryMissed:
        return Icons.error_outline_rounded;
      case DeliveryStatus.scheduled:
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Future<void> _handleComplete() async {
    final completeUseCase = ref.read(completeReminderUseCaseProvider);
    final result = await completeUseCase.execute(_currentReminder.id);

    if (!mounted) return;

    switch (result) {
      case Success(:final value):
        setState(() {
          _currentReminder = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Completed "${value.title}"'),
            backgroundColor: AppColors.success,
          ),
        );
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _handleSnooze() async {
    final snoozeUseCase = ref.read(snoozeReminderUseCaseProvider);
    final result = await snoozeUseCase.execute(_currentReminder.id);

    if (!mounted) return;

    switch (result) {
      case Success(:final value):
        setState(() {
          _currentReminder = value;
          _scheduledTime = value.trigger?.scheduledTimeUtc.toLocal();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Snoozed for ${value.snoozeDurationMinutes} minutes'),
            backgroundColor: AppColors.accentSecondary,
          ),
        );
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _handleDelete() async {
    final deleteUseCase = ref.read(deleteReminderUseCaseProvider);
    final result = await deleteUseCase.execute(_currentReminder.id);

    if (!mounted) return;

    switch (result) {
      case Success():
        Navigator.of(context).pop(_currentReminder);
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _handleCall(String phone) async {
    final actionBridge = ref.read(actionBridgeProvider);
    await actionBridge.launchDialer(phone);
  }

  Future<void> _handleSms(String phone) async {
    final actionBridge = ref.read(actionBridgeProvider);
    await actionBridge.launchSms(phone);
  }

  Future<void> _handleOpenUrl(String url) async {
    final actionBridge = ref.read(actionBridgeProvider);
    await actionBridge.launchUrl(url);
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
      _scheduledTime = newDateTime;
    });
  }

  Future<void> _saveEdits() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final updatedTrigger = _currentReminder.trigger?.copyWith(
      scheduledTimeUtc: _scheduledTime?.toUtc() ?? _currentReminder.trigger!.scheduledTimeUtc,
    );

    final updatedReminder = _currentReminder.copyWith(
      title: _titleController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      trigger: updatedTrigger,
    );

    final editUseCase = ref.read(editReminderUseCaseProvider);
    final result = await editUseCase.execute(updatedReminder);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    switch (result) {
      case Success(:final value):
        setState(() {
          _currentReminder = value;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      case Failure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheduledTimeUtc = _currentReminder.trigger?.scheduledTimeUtc;
    final action = _currentReminder.action;
    final deliveryStatus = _currentReminder.trigger?.deliveryStatus;
    final firedAt = _currentReminder.trigger?.firedAt;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
      appBar: AppBar(
        title: const Text('Reminder Details'),
        actions: [
          if (!_isTerminalState)
            IconButton(
              key: const Key('detail_edit_toggle_button'),
              icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_outlined),
              tooltip: _isEditing ? 'Cancel Edit' : 'Edit Reminder',
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (!_isEditing) {
                    _initControllers();
                  }
                });
              },
            ),
          IconButton(
            key: const Key('detail_delete_button'),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: 'Delete Reminder',
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Intent Header
            Row(
              children: [
                // Intent Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getIntentIcon(_currentReminder.intentType),
                    color: AppColors.accentPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentReminder.intentType.value.toUpperCase(),
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AppColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_currentReminder.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isOverdue ? 'OVERDUE' : _currentReminder.status.value.toUpperCase(),
                              key: const Key('detail_status_badge'),
                              style: AppTypography.small.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(_currentReminder.status),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (_currentReminder.snoozeCount > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Snoozed ${_currentReminder.snoozeCount}x',
                              style: AppTypography.caption.copyWith(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (!_isEditing) ...[
              // Title
              Text(
                _currentReminder.title,
                key: const Key('detail_title_text'),
                style: AppTypography.headline.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Scheduled Time Tile
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppColors.accentPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scheduled Time',
                            style: AppTypography.caption.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(scheduledTimeUtc),
                            key: const Key('detail_scheduled_time_text'),
                            style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Delivery Status Tile
              if (deliveryStatus != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getDeliveryIcon(deliveryStatus, firedAt),
                        size: 20,
                        color: _getDeliveryColor(deliveryStatus, firedAt),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _getDeliveryStatusText(deliveryStatus, firedAt),
                          key: const Key('detail_delivery_status_text'),
                          style: AppTypography.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _getDeliveryColor(deliveryStatus, firedAt),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Notes Card
              if (_currentReminder.notes != null && _currentReminder.notes!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentReminder.notes!,
                        key: const Key('detail_notes_text'),
                        style: AppTypography.body.copyWith(
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Contact Action (Call / Text)
              if (action != null &&
                  (action.actionType == ActionType.call ||
                      action.actionType == ActionType.text ||
                      action.contactPhone != null)) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.person_rounded, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  action.contactName ?? 'Contact',
                                  style: AppTypography.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                                if (action.contactPhone != null)
                                  Text(
                                    action.contactPhone!,
                                    style: AppTypography.caption.copyWith(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (action.contactPhone != null) ...[
                            IconButton(
                              key: const Key('detail_call_button'),
                              icon: const Icon(Icons.phone_rounded, color: AppColors.accentPrimary),
                              tooltip: 'Call',
                              onPressed: () => _handleCall(action.contactPhone!),
                            ),
                            IconButton(
                              key: const Key('detail_sms_button'),
                              icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.accentPrimary),
                              tooltip: 'Text message',
                              onPressed: () => _handleSms(action.contactPhone!),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // URL Action (Open)
              if (action?.targetValue != null && action!.actionType == ActionType.openUrl) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: AppColors.accentPrimary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          action.targetValue!,
                          key: const Key('detail_url_text'),
                          style: AppTypography.body.copyWith(
                            color: AppColors.accentPrimary,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton(
                        key: const Key('detail_open_url_button'),
                        onPressed: () => _handleOpenUrl(action.targetValue!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Original Voice Transcript
              if (_currentReminder.originalTranscript != null && _currentReminder.originalTranscript!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceElevated.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.record_voice_over_rounded, size: 16, color: AppColors.accentSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Voice Transcript',
                            style: AppTypography.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '"${_currentReminder.originalTranscript!}"',
                        key: const Key('detail_transcript_text'),
                        style: AppTypography.caption.copyWith(
                          fontStyle: FontStyle.italic,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Timestamps History
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    _buildTimestampRow('Created', _currentReminder.createdAt, isDark),
                    const SizedBox(height: 4),
                    _buildTimestampRow('Updated', _currentReminder.updatedAt, isDark),
                    if (_currentReminder.completedAt != null) ...[
                      const SizedBox(height: 4),
                      _buildTimestampRow('Completed', _currentReminder.completedAt!, isDark),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Active Action Buttons (Complete & Snooze)
              if (!_isTerminalState) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('detail_snooze_button'),
                        onPressed: _handleSnooze,
                        icon: const Icon(Icons.snooze_rounded, size: 18),
                        label: const Text('Snooze (+10m)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        key: const Key('detail_complete_button'),
                        onPressed: _handleComplete,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ] else ...[
              // Inline Edit Mode
              Text(
                'Edit Details',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                key: const Key('detail_edit_title_input'),
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Reminder Title',
                  prefixIcon: const Icon(Icons.title_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Material(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                borderRadius: BorderRadius.circular(10),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: const Icon(Icons.calendar_month_rounded, color: AppColors.accentPrimary),
                  title: Text(
                    _formatDateTime(_scheduledTime),
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: _pickDateTime,
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                key: const Key('detail_edit_notes_input'),
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Edit Changes Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('detail_save_edits_button'),
                  onPressed: _isSaving ? null : _saveEdits,
                  icon: const Icon(Icons.save_rounded, size: 20),
                  label: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampRow(String label, DateTime dt, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        Text(
          _formatDateTime(dt),
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }
}
