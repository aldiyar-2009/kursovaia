import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_palette.dart';
import 'package:studyplan/l10n/generated/app_localizations.dart';

/// Short accessors used by every widget instead of `AppColors` / `Colors`.
extension ThemeX on BuildContext {
  /// Semantic colours of the current theme (falls back to light).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get text => Theme.of(this).textTheme;

  AppLocalizations get l10n => AppLocalizations.of(this);
}
