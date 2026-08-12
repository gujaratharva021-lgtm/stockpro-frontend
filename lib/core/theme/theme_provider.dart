import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final saved = await _storage.read(key: _key);
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _storage.write(key: _key, value: isDark ? 'dark' : 'light');
    notifyListeners();
  }
}