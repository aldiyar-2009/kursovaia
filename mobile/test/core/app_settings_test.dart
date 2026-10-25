import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/settings/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to system theme and device language', () async {
    final settings = AppSettings();
    await settings.load();
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.locale, isNull);
  });

  test('theme mode and locale persist and reload', () async {
    final settings = AppSettings();
    await settings.load();
    await settings.setThemeMode(ThemeMode.dark);
    await settings.setLocale(const Locale('kk'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppSettings.themeModeKey), 'dark');
    expect(prefs.getString(AppSettings.localeKey), 'kk');

    final reloaded = AppSettings();
    await reloaded.load();
    expect(reloaded.themeMode, ThemeMode.dark);
    expect(reloaded.locale, const Locale('kk'));
  });

  test('setLocale(null) returns to system language', () async {
    final settings = AppSettings();
    await settings.load();
    await settings.setLocale(const Locale('en'));
    await settings.setLocale(null);

    final reloaded = AppSettings();
    await reloaded.load();
    expect(reloaded.locale, isNull);
  });

  test('setters notify listeners', () async {
    final settings = AppSettings();
    await settings.load();
    var calls = 0;
    settings.addListener(() => calls++);
    await settings.setThemeMode(ThemeMode.light);
    await settings.setLocale(const Locale('ru'));
    expect(calls, 2);
  });

  group('resolveLocale', () {
    test('picks supported language by code', () {
      expect(resolveLocale([const Locale('kk', 'KZ')]), const Locale('kk'));
      expect(resolveLocale([const Locale('en', 'US')]), const Locale('en'));
    });

    test('falls back to Russian', () {
      expect(resolveLocale([const Locale('de')]), const Locale('ru'));
      expect(resolveLocale(const []), const Locale('ru'));
    });

    test('uses the first supported locale in device order', () {
      expect(
        resolveLocale([const Locale('de'), const Locale('en')]),
        const Locale('en'),
      );
    });
  });
}
