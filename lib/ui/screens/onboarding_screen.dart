import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';
import '../../platform/permissions.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'home_screen.dart';

/// 3-Screen Onboarding Flow (KATALA_SPEC_V3.md §28.6).
/// Screens: 1. Welcome -> 2. How It Works -> 3. Permissions.
class OnboardingScreen extends ConsumerStatefulWidget {
  static const String completedKey = 'has_completed_onboarding';

  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.completedKey, true);

    if (mounted) {
      ref.invalidate(isOnboardingCompletedProvider);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurfaceBg : AppColors.lightSurfaceBg;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentPage < 2)
            TextButton(
              onPressed: _completeOnboarding,
              child: Text(
                'Skip',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomeScreen(isDark),
                  _buildHowItWorksScreen(isDark),
                  _buildPermissionsScreen(isDark),
                ],
              ),
            ),
            _buildBottomControls(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Katala',
            style: AppTypography.headline.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reliable, voice-first reminders that never get lost in the background.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksScreen(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFeatureRow(
            icon: Icons.mic_rounded,
            title: 'Speak Naturally',
            description: 'Say "Remind me to buy groceries tomorrow at 5pm" or type anytime.',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildFeatureRow(
            icon: Icons.bolt_rounded,
            title: 'Intelligent Actions',
            description: 'Automatically link calls, texts, and links right from notifications.',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          _buildFeatureRow(
            icon: Icons.security_rounded,
            title: 'Rock-Solid Delivery',
            description: 'Self-healing alarms and transparent warnings keep you in control.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accentPrimary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.title.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTypography.small.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsScreen(bool isDark) {
    final micPerm = ref.watch(microphonePermissionProvider);
    final notifPerm = ref.watch(notificationPermissionProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Permissions',
            style: AppTypography.headline.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Katala needs microphone and notification permissions to function smoothly.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 32),
          _buildPermissionTile(
            title: 'Microphone',
            subtitle: 'Required for hands-free voice input capture.',
            isGranted: micPerm.valueOrNull?.isGranted ?? false,
            onRequest: () async {
              final bridge = ref.read(permissionBridgeProvider);
              await bridge.requestMicrophonePermission();
              ref.invalidate(microphonePermissionProvider);
            },
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildPermissionTile(
            title: 'Notifications',
            subtitle: 'Required for scheduled reminder alerts.',
            isGranted: notifPerm.valueOrNull?.isGranted ?? false,
            onRequest: () async {
              final bridge = ref.read(permissionBridgeProvider);
              await bridge.requestNotificationPermission();
              ref.invalidate(notificationPermissionProvider);
            },
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onRequest,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.title.copyWith(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTypography.small.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isGranted)
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28)
          else
            ElevatedButton(
              onPressed: onRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Grant',
                style: AppTypography.caption.copyWith(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page Indicator Dots
          Row(
            children: List.generate(3, (index) {
              final isActive = _currentPage == index;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.accentPrimary
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Get Started Button
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _currentPage == 0 ? 'Get Started' : (_currentPage == 2 ? 'Done' : 'Next'),
              style: AppTypography.caption.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
