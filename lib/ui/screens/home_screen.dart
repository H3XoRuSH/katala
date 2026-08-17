import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../../application/providers.dart';
import '../../domain/entities/parsed_reminder.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/delivery_status.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/clarification_card.dart';
import '../widgets/confirmation_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/katala_logo.dart';
import '../widgets/reliability_banner.dart';
import '../widgets/text_input_field.dart';
import '../widgets/timeline_group.dart';
import 'reminder_detail_screen.dart';

/// The primary Home Screen displaying chronological timeline groups and input methods (KATALA_SPEC_V3.md §28.4.2, TASK-082).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _snackBarTimer;
  Timer? _autoRefreshTimer;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (mounted) {
          ref.read(reconcileNotificationsUseCaseProvider).execute();
          setState(() {});
        }
      },
    );
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _lifecycleListener.dispose();
    _snackBarTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final reconcileUseCase = ref.read(reconcileNotificationsUseCaseProvider);
    await reconcileUseCase.execute();
  }

  void _showUndoSnackBar({
    required String message,
    required Future<void> Function() onUndo,
  }) {
    _snackBarTimer?.cancel();
    unawaited(HapticFeedback.lightImpact());
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        duration: const Duration(seconds: 5),
        content: Text(message),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: AppColors.accentSecondary,
          onPressed: () async {
            _snackBarTimer?.cancel();
            unawaited(HapticFeedback.selectionClick());
            await onUndo();
          },
        ),
      ),
    );

    // Guaranteed dismiss timer bypassing Android OEM accessibility override
    _snackBarTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  Future<void> _handleProcessInput(String transcript) async {
    if (transcript.trim().isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    if (mounted && MediaQuery.of(context).viewInsets.bottom > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    if (!mounted) return;

    final nlp = ref.read(nlpPipelineProvider);
    final clock = ref.read(clockProvider);
    final parsed = nlp.parse(transcript.trim(), clock: clock);

    if (!mounted) return;

    if (parsed.issues.isNotEmpty || parsed.title == null || parsed.scheduledTime == null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final resolved = await showModalBottomSheet<ParsedReminder>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => ClarificationCard(
          initialDraft: parsed,
          onSave: (res) => Navigator.of(ctx).pop(res),
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      );
      if (!mounted || resolved == null) return;
      _showConfirmationSheet(resolved);
    } else {
      _showConfirmationSheet(parsed);
    }
  }

  void _showConfirmationSheet(ParsedReminder draft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final createUseCase = ref.read(createReminderUseCaseProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ConfirmationCard(
        parsed: draft,
        createReminderUseCase: createUseCase,
        onSaveSuccess: (savedReminder) {
          Navigator.of(ctx).pop();
          _snackBarTimer?.cancel();
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              dismissDirection: DismissDirection.horizontal,
              duration: const Duration(seconds: 4),
              content: Text('✓ Created: "${savedReminder.title}"'),
              backgroundColor: AppColors.success,
            ),
          );
          _snackBarTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          });
        },
        onCancel: () {
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  Future<void> _handleOpenDetail(Reminder reminder) async {
    final deleted = await Navigator.of(context).push<Reminder>(
      MaterialPageRoute<Reminder>(
        builder: (context) => ReminderDetailScreen(reminder: reminder),
      ),
    );

    if (deleted != null && mounted) {
      _showUndoSnackBar(
        message: 'Deleted "${deleted.title}"',
        onUndo: () async {
          final undoUseCase = ref.read(undoDeleteReminderUseCaseProvider);
          await undoUseCase.execute(deleted.id);
        },
      );
    }
  }

  Future<void> _handleComplete(Reminder reminder) async {
    final completeUseCase = ref.read(completeReminderUseCaseProvider);
    final result = await completeUseCase.execute(reminder.id);

    if (!mounted) return;

    if (result.isSuccess) {
      _showUndoSnackBar(
        message: '✓ "${reminder.title}" completed',
        onUndo: () async {
          final repo = ref.read(reminderRepositoryProvider);
          final restored = reminder.copyWith(
            completedAt: null,
            version: reminder.version + 1,
          );
          await repo.update(restored, expectedVersion: reminder.version + 1);
        },
      );
    }
  }

  Future<void> _handleDelete(Reminder reminder) async {
    final deleteUseCase = ref.read(deleteReminderUseCaseProvider);
    final result = await deleteUseCase.execute(reminder.id);

    if (!mounted) return;

    if (result.isSuccess) {
      _showUndoSnackBar(
        message: 'Deleted "${reminder.title}"',
        onUndo: () async {
          final undoUseCase = ref.read(undoDeleteReminderUseCaseProvider);
          await undoUseCase.execute(reminder.id);
        },
      );
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final remindersAsync = ref.watch(pendingRemindersStreamProvider);
    final clock = ref.watch(clockProvider);
    final nowUtc = clock.now();
    final nowLocal = nowUtc.toLocal();
    final tomorrowLocal = nowLocal.add(const Duration(days: 1));
    final endOfWeekLocal = nowLocal.add(Duration(days: 7 - nowLocal.weekday));

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const KatalaLogo(size: 26),
            ),
            const SizedBox(width: 10),
            Text(
              'Katala',
              style: AppTypography.title.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        actions: [
          // Theme Toggle
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
            onPressed: () {
              ref.read(themeModeProvider.notifier).state = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading reminders: $err'),
        ),
        data: (reminders) {
          final uncertainCount =
              reminders.where((r) => r.trigger?.deliveryStatus == DeliveryStatus.deliveryUncertain).length;

          // Categorize reminders
          final overdue = <Reminder>[];
          final today = <Reminder>[];
          final tomorrow = <Reminder>[];
          final thisWeek = <Reminder>[];
          final later = <Reminder>[];

          for (final reminder in reminders) {
            final scheduledUtc = reminder.trigger?.scheduledTimeUtc;
            if (scheduledUtc == null) {
              later.add(reminder);
              continue;
            }

            if (scheduledUtc.isBefore(nowUtc)) {
              overdue.add(reminder);
            } else {
              final scheduledLocal = scheduledUtc.toLocal();
              if (_isSameDay(scheduledLocal, nowLocal)) {
                today.add(reminder);
              } else if (_isSameDay(scheduledLocal, tomorrowLocal)) {
                tomorrow.add(reminder);
              } else if (scheduledLocal.isBefore(endOfWeekLocal) || _isSameDay(scheduledLocal, endOfWeekLocal)) {
                thisWeek.add(reminder);
              } else {
                later.add(reminder);
              }
            }
          }

          final hasAnyReminders = reminders.isNotEmpty;

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.accentPrimary,
            child: Stack(
              children: [
                if (!hasAnyReminders)
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (uncertainCount > 0) ReliabilityBanner(uncertainCount: uncertainCount),
                      const EmptyTimelineState(),
                    ],
                  )
                else
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 120),
                    children: [
                      if (uncertainCount > 0) ReliabilityBanner(uncertainCount: uncertainCount),
                      if (overdue.isNotEmpty)
                        TimelineGroup(
                          title: 'Overdue',
                          reminders: overdue,
                          accentColor: AppColors.error,
                          onTapReminder: _handleOpenDetail,
                          onCompleteReminder: _handleComplete,
                          onDeleteReminder: _handleDelete,
                        ),
                      if (today.isNotEmpty)
                        TimelineGroup(
                          title: 'Today',
                          reminders: today,
                          onTapReminder: _handleOpenDetail,
                          onCompleteReminder: _handleComplete,
                          onDeleteReminder: _handleDelete,
                        ),
                      if (tomorrow.isNotEmpty)
                        TimelineGroup(
                          title: 'Tomorrow',
                          reminders: tomorrow,
                          onTapReminder: _handleOpenDetail,
                          onCompleteReminder: _handleComplete,
                          onDeleteReminder: _handleDelete,
                        ),
                      if (thisWeek.isNotEmpty)
                        TimelineGroup(
                          title: 'This Week',
                          reminders: thisWeek,
                          onTapReminder: _handleOpenDetail,
                          onCompleteReminder: _handleComplete,
                          onDeleteReminder: _handleDelete,
                        ),
                      if (later.isNotEmpty)
                        TimelineGroup(
                          title: 'Later',
                          reminders: later,
                          onTapReminder: _handleOpenDetail,
                          onCompleteReminder: _handleComplete,
                          onDeleteReminder: _handleDelete,
                        ),
                    ],
                  ),

                // Text Input Bar at Bottom with embedded voice mic
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: TextInputField(
                    onSubmit: _handleProcessInput,
                    onVoiceResult: _handleProcessInput,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
