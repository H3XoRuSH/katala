import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'domain/entities/reminder.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/reminder_detail_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/widgets/recovery_screen.dart';
import 'ui/theme/theme.dart';

/// Provider for user theme mode preference (Dark / Light / System).
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.dark;
});

/// Checks if user has already completed the first-launch onboarding flow.
final isOnboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(OnboardingScreen.completedKey) ?? false;
});

/// Root MaterialApp widget of Katala with theme, router, and Riverpod bindings (TASK-080, TASK-081).
class KatalaApp extends ConsumerWidget {
  const KatalaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final onboardingAsync = ref.watch(isOnboardingCompletedProvider);

    return MaterialApp(
      title: 'Katala',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: Duration.zero,
      home: onboardingAsync.when(
        data: (completed) => completed ? const HomeScreen() : const OnboardingScreen(),
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const HomeScreen(),
      ),
      routes: {
        '/home': (_) => const HomeScreen(),
        '/onboarding': (_) => const OnboardingScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/recovery': (_) => const RecoveryScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/reminder/')) {
          final reminder = settings.arguments as Reminder?;
          if (reminder != null) {
            return MaterialPageRoute(
              builder: (_) => ReminderDetailScreen(reminder: reminder),
            );
          }
          return MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Reminder Details')),
              body: Center(child: Text('Reminder: ${settings.name}')),
            ),
          );
        }
        return null;
      },
    );
  }
}
