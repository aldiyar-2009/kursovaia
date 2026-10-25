import 'package:flutter/material.dart';

/// Semantic colours of the app.
///
/// Neutral zinc-like greys plus a single blue [accent]. Status colours are
/// muted and used only for grades and statuses. Text colours meet WCAG AA
/// (>= 4.5:1) on [background], [surface] and [surfaceMuted] in both themes.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Page background behind lists and grouped sections.
  final Color background;

  /// Rows, cards, sheets, app bars.
  final Color surface;

  /// Inputs, selected rows, segmented controls, subtle fills.
  final Color surfaceMuted;

  /// 1 px separators and outlines.
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Primary button fill: near-black in light, near-white in dark.
  final Color primary;
  final Color onPrimary;

  /// The only accent: links, selection, focus.
  final Color accent;

  final Color success;
  final Color successMuted;
  final Color warning;
  final Color warningMuted;
  final Color danger;
  final Color dangerMuted;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.success,
    required this.successMuted,
    required this.warning,
    required this.warningMuted,
    required this.danger,
    required this.dangerMuted,
  });

  static const light = AppPalette(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF4F4F5),
    border: Color(0xFFE4E4E7),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFF6B6B74),
    primary: Color(0xFF18181B),
    onPrimary: Color(0xFFFAFAFA),
    accent: Color(0xFF2563EB),
    success: Color(0xFF146C37),
    successMuted: Color(0xFFE8F5EC),
    warning: Color(0xFFA15C07),
    warningMuted: Color(0xFFFBF1DE),
    danger: Color(0xFFB91C1C),
    dangerMuted: Color(0xFFFBEAEA),
  );

  static const dark = AppPalette(
    background: Color(0xFF0B0B0C),
    surface: Color(0xFF141416),
    surfaceMuted: Color(0xFF1C1C1F),
    border: Color(0xFF27272A),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF85858E),
    primary: Color(0xFFF4F4F5),
    onPrimary: Color(0xFF18181B),
    accent: Color(0xFF6EA8FE),
    success: Color(0xFF5CB87F),
    successMuted: Color(0xFF15241A),
    warning: Color(0xFFD9A441),
    warningMuted: Color(0xFF2A2113),
    danger: Color(0xFFEA6F6F),
    dangerMuted: Color(0xFF2E1718),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? success,
    Color? successMuted,
    Color? warning,
    Color? warningMuted,
    Color? danger,
    Color? dangerMuted,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      successMuted: successMuted ?? this.successMuted,
      warning: warning ?? this.warning,
      warningMuted: warningMuted ?? this.warningMuted,
      danger: danger ?? this.danger,
      dangerMuted: dangerMuted ?? this.dangerMuted,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      success: l(success, other.success),
      successMuted: l(successMuted, other.successMuted),
      warning: l(warning, other.warning),
      warningMuted: l(warningMuted, other.warningMuted),
      danger: l(danger, other.danger),
      dangerMuted: l(dangerMuted, other.dangerMuted),
    );
  }
}
