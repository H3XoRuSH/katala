import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String prefSnoozeDurationKey = 'pref_snooze_duration_minutes';
const String prefBackupOptInKey = 'pref_backup_opt_in';
const String prefThemeModeKey = 'pref_theme_mode';

/// State notifier for default snooze duration preference (in minutes).
class SnoozeDurationNotifier extends StateNotifier<int> {
  SnoozeDurationNotifier([super.state = 15]) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(prefSnoozeDurationKey);
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setDuration(int minutes) async {
    state = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefSnoozeDurationKey, minutes);
  }
}

final snoozeDurationProvider = StateNotifierProvider<SnoozeDurationNotifier, int>((ref) {
  return SnoozeDurationNotifier(15);
});

/// State notifier for database backup opt-in.
class BackupOptInNotifier extends StateNotifier<bool> {
  BackupOptInNotifier([super.state = false]) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(prefBackupOptInKey);
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> setOptIn(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefBackupOptInKey, value);
  }
}

final backupOptInProvider = StateNotifierProvider<BackupOptInNotifier, bool>((ref) {
  return BackupOptInNotifier(false);
});

/// State notifier for theme mode with persistence.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier([super.state = ThemeMode.dark]) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefThemeModeKey);
    if (saved != null) {
      switch (saved) {
        case 'light':
          state = ThemeMode.light;
          break;
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'system':
          state = ThemeMode.system;
          break;
      }
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefThemeModeKey, mode.name);
  }
}
