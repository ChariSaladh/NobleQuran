import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app theme (dark/light mode)
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  static const String _storageKey = 'theme_mode';

  ThemeProvider() {
    _loadTheme();
  }

  /// Load saved theme preference
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int? savedMode = prefs.getInt(_storageKey);
      if (savedMode != null) {
        _themeMode = ThemeMode.values[savedMode];
        _isDarkMode = savedMode == 2; // 2 = dark mode
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _isDarkMode = mode == ThemeMode.dark;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, mode.index);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }

    notifyListeners();
  }

  /// Toggle between dark and light mode
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}
