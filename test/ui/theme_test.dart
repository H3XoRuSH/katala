import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/ui/theme/colors.dart';
import 'package:katala/ui/theme/theme.dart';
import 'package:katala/ui/theme/typography.dart';

void main() {
  group('Theme, Typography & Color Tokens (TASK-080)', () {
    test('Dark theme tokens match KATALA_SPEC_V3 §28.2', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, AppColors.darkSurfaceBg);
      expect(theme.cardColor, AppColors.darkSurfaceCard);
      expect(theme.colorScheme.primary, AppColors.accentPrimary);
      expect(theme.colorScheme.secondary, AppColors.accentSecondary);
    });

    test('Light theme tokens match KATALA_SPEC_V3 §28.2', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.lightSurfaceBg);
      expect(theme.cardColor, AppColors.lightSurfaceCard);
      expect(theme.colorScheme.primary, AppColors.accentPrimary);
    });

    test('Typography uses Inter font family and defined hierarchy', () {
      expect(AppTypography.fontFamily, 'Inter');
      expect(AppTypography.headline.fontSize, 28);
      expect(AppTypography.headline.fontWeight, FontWeight.w700);

      expect(AppTypography.title.fontSize, 20);
      expect(AppTypography.title.fontWeight, FontWeight.w600);

      expect(AppTypography.body.fontSize, 16);
      expect(AppTypography.body.fontWeight, FontWeight.w400);

      expect(AppTypography.caption.fontSize, 14);
      expect(AppTypography.small.fontSize, 12);
    });

    testWidgets('Theme renders correctly in widget tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: Column(
              children: [
                Text('Headline', style: AppTypography.headline),
                Text('Body', style: AppTypography.body),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Headline'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });
  });
}
