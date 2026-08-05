import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vers_reminder/shared/locale_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('init defaults to es when no override', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = LocaleProvider();
    await provider.init();

    expect(provider.isInitialized, true);
    expect(provider.locale.languageCode, 'es');
  });

  test('init reads saved override', () async {
    SharedPreferences.setMockInitialValues({'locale_override': 'pt'});
    final provider = LocaleProvider();
    await provider.init();

    expect(provider.locale.languageCode, 'pt');
  });

  test('setLocale persists and notifies', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = LocaleProvider();
    await provider.init();

    var notified = false;
    provider.addListener(() {
      notified = true;
    });

    await provider.setLocale(const Locale('pt'));
    expect(provider.locale.languageCode, 'pt');
    expect(notified, true);

    // Verify persistence
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale_override'), 'pt');
  });
}
