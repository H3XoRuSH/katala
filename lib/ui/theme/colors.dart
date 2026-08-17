import 'package:flutter/material.dart';

/// Semantic and surface color tokens for Katala (KATALA_SPEC_V3.md §28.2).
abstract class AppColors {
  // Shared Accent & Semantic Tokens
  static const Color accentPrimary = Color(0xFF6C5CE7);
  static const Color accentSecondary = Color(0xFFA29BFE);
  static const Color success = Color(0xFF00D2A0);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color error = Color(0xFFFF6B6B);
  static const Color snooze = Color(0xFF74B9FF);
  static const Color uncertain = Color(0xFFE8A838);

  // Dark Theme Tokens (Default)
  static const Color darkSurfaceBg = Color(0xFF0F0F14);
  static const Color darkSurfaceCard = Color(0xFF1A1A24);
  static const Color darkSurfaceElevated = Color(0xFF252535);
  static const Color darkTextPrimary = Color(0xFFF0F0F5);
  static const Color darkTextSecondary = Color(0xFF8888A0);

  // Light Theme Tokens
  static const Color lightSurfaceBg = Color(0xFFF8F9FA);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF666680);
}
