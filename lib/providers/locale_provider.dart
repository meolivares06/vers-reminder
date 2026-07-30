import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'locale_override';

  Locale _locale = const Locale('es');
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(_localeKey);

    if (override != null && override.isNotEmpty) {
      _locale = Locale(override);
    } else {
      // Detect from device
      final deviceLocale = WidgetsBinding
          .instance.platformDispatcher.locale;
      final langCode = deviceLocale.languageCode;
      if (langCode == 'pt') {
        _locale = const Locale('pt');
      } else {
        _locale = const Locale('es');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}
