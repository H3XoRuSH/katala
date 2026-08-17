import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

/// Banner shown when any reminder delivery is uncertain (KATALA_SPEC_V3.md §28.4.2).
class ReliabilityBanner extends StatelessWidget {
  final int uncertainCount;
  final VoidCallback? onTap;

  const ReliabilityBanner({
    super.key,
    required this.uncertainCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (uncertainCount <= 0) return const SizedBox.shrink();

    return Semantics(
      label: 'Reliability Warning: $uncertainCount reminders may need attention',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.uncertain.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.uncertain.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.uncertain,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Uncertain',
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.uncertain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$uncertainCount reminder${uncertainCount > 1 ? 's' : ''} may have been missed or delayed.',
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: AppColors.uncertain,
                onPressed: onTap,
              ),
          ],
        ),
      ),
    );
  }
}
