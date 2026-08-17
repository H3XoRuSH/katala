import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:katala/ui/theme/colors.dart';
import 'package:katala/ui/widgets/katala_logo.dart';

void main() {
  group('KatalaLogo Widget', () {
    testWidgets('renders in Dark Theme with SvgPicture', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: KatalaLogo(size: 64),
          ),
        ),
      );

      expect(find.byType(KatalaLogo), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders in Light Theme with SvgPicture', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: const Scaffold(
            body: KatalaLogo(size: 64),
          ),
        ),
      );

      expect(find.byType(KatalaLogo), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('renders with background container and custom color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: KatalaLogo(
              size: 48,
              showBackground: true,
              color: AppColors.success,
            ),
          ),
        ),
      );

      expect(find.byType(KatalaLogo), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });
  });
}
