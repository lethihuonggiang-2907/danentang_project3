import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State notifier to manage ThemeMode (light, dark, system).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

/// Provider for application theme mode.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
