import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Database corruption recovery screen offering recovery options (TASK-092, KATALA_SPEC_V3.md §35.2).
class RecoveryScreen extends StatefulWidget {
  final Future<void> Function()? onRestoreBackup;
  final Future<void> Function()? onResetDatabase;

  const RecoveryScreen({
    super.key,
    this.onRestoreBackup,
    this.onResetDatabase,
  });

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _handleRestore() async {
    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Attempting backup restoration...';
    });

    try {
      if (widget.onRestoreBackup != null) {
        await widget.onRestoreBackup!();
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Restoration completed successfully.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'No valid backup found to restore.';
        });
      }
    }
  }

  Future<void> _handleReset() async {
    unawaited(HapticFeedback.mediumImpact());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Database?'),
        content: const Text(
          'This will permanently delete all corrupted local records and initialize a fresh database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Resetting database...';
      });

      try {
        if (widget.onResetDatabase != null) {
          await widget.onResetDatabase!();
        }
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Database reset successfully.';
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusMessage = 'Error resetting database: $e';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg,
      appBar: AppBar(
        title: const Text('Database Recovery'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Warning Icon Badge
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 54,
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Database integrity check failed',
                style: AppTypography.headline.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Katala detected corrupted local storage. To protect your data integrity, you can restore from a backup or reset the database.',
                style: AppTypography.body.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _statusMessage!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const Spacer(),
              if (_isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Semantics(
                  button: true,
                  label: 'Restore database from backup',
                  child: FilledButton.icon(
                    onPressed: _handleRestore,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.restore_rounded),
                    label: Text(
                      'Restore from Backup',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  button: true,
                  label: 'Reset database',
                  child: OutlinedButton.icon(
                    onPressed: _handleReset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: Text(
                      'Reset Database',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
