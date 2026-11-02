import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studyplan/core/settings/app_edition.dart';

export 'package:studyplan/core/settings/app_edition.dart';

/// Locales the app ships with. Russian is the source language.
const kSupportedLocales = <Locale>[Locale('ru'), Locale('en'), Locale('kk')];

/// Picks the first device locale whose language the app supports
/// (kk / en / ru), otherwise Russian.
Locale resolveLocale(List<Locale> device) {
  for (final locale in device) {
    final supported = _supported(locale.languageCode);
    if (supported != null) return supported;
  }
  return const Locale('ru');
}

Locale? _supported(String languageCode) =>
    kSupportedLocales.where((l) => l.languageCode == languageCode).firstOrNull;

/// The app language where no BuildContext is available (notifications):
/// the saved `settings.locale`, otherwise [resolveLocale] of the device
/// locales — the same choice `MaterialApp` makes.
Future<Locale> currentAppLocale() async {
  Locale? saved;
  try {
    final prefs = await SharedPreferences.getInstance();
    saved = _supported(prefs.getString(AppSettings.localeKey) ?? '');
  } catch (_) {
    saved = null;
  }
  return saved ??
      resolveLocale(WidgetsBinding.instance.platformDispatcher.locales);
}

/// User preferences for appearance and language, persisted in
/// SharedPreferences. Passed down through constructors like `db`.
class AppSettings extends ChangeNotifier {
  static const themeModeKey = 'settings.theme_mode';
  static const localeKey = 'settings.locale';
  static const editionKey = 'settings.edition';

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  AppEdition? _edition;

  ThemeMode get themeMode => _themeMode;

  /// Explicit app language, or `null` to follow the device.
  Locale? get locale => _locale;

  /// University or college, chosen on the first screen; `null` until then.
  AppEdition? get edition => _edition;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = switch (prefs.getString(themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _locale = _supported(prefs.getString(localeKey) ?? '');
    final edition = prefs.getString(editionKey);
    _edition = edition == null || edition.isEmpty
        ? null
        : AppEdition.fromName(edition);
    notifyListeners();
  }

  /// `null` sends the user back to the edition choice.
  Future<void> setEdition(AppEdition? edition) async {
    if (edition == _edition) return;
    _edition = edition;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(editionKey, edition?.name ?? '');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, mode.name);
  }

  /// `null` (or an unsupported language) means "follow the device".
  Future<void> setLocale(Locale? locale) async {
    final value = locale == null ? null : _supported(locale.languageCode);
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeKey, value?.languageCode ?? '');
  }
}
