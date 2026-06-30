import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'isDark';

  ThemeMode _mode;
  ThemeMode get themeMode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  /// Pass the persisted value (read synchronously at startup via [loadSaved]) so
  /// the app — and the Google Map — build in the correct mode from the first
  /// frame, instead of flashing light then flipping to dark asynchronously.
  ThemeProvider({bool isDark = false})
      : _mode = isDark ? ThemeMode.dark : ThemeMode.light;

  /// Reads the saved theme before [runApp]. Call once during startup.
  static Future<bool> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isDark);
  }
}
