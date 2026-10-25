import 'package:flutter/material.dart';
import 'package:studyplan/core/theme/app_palette.dart';

/// Radii and spacing shared by the design system.
abstract final class AppRadius {
  /// Buttons, inputs, cards, chips.
  static const double md = 8;

  /// Bottom sheets and dialogs only.
  static const double lg = 12;
}

/// Tabular figures for grades, times and other numbers in columns.
extension TabularFigures on TextStyle {
  TextStyle get tabular =>
      copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}

abstract final class AppTheme {
  static const fontFamily = 'Inter';

  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  /// Type scale 28 / 22 / 17 / 15 / 13 / 12.
  static TextTheme textTheme(AppPalette p) {
    TextStyle s(double size, FontWeight w, Color c,
            {double spacing = 0, double height = 1.35}) =>
        TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: w,
          color: c,
          letterSpacing: spacing,
          height: height,
        );
    return TextTheme(
      displayLarge: s(28, FontWeight.w600, p.textPrimary, spacing: -0.5, height: 1.2),
      displayMedium: s(28, FontWeight.w600, p.textPrimary, spacing: -0.5, height: 1.2),
      displaySmall: s(28, FontWeight.w600, p.textPrimary, spacing: -0.5, height: 1.2),
      headlineLarge: s(28, FontWeight.w600, p.textPrimary, spacing: -0.5, height: 1.2),
      headlineMedium: s(28, FontWeight.w600, p.textPrimary, spacing: -0.5, height: 1.2),
      headlineSmall: s(22, FontWeight.w600, p.textPrimary, spacing: -0.3, height: 1.25),
      titleLarge: s(22, FontWeight.w600, p.textPrimary, spacing: -0.3, height: 1.25),
      titleMedium: s(17, FontWeight.w600, p.textPrimary, spacing: -0.2, height: 1.3),
      titleSmall: s(15, FontWeight.w600, p.textPrimary, spacing: -0.1),
      bodyLarge: s(17, FontWeight.w400, p.textPrimary, spacing: -0.2),
      bodyMedium: s(15, FontWeight.w400, p.textPrimary, spacing: -0.1, height: 1.4),
      bodySmall: s(13, FontWeight.w400, p.textSecondary),
      labelLarge: s(15, FontWeight.w500, p.textPrimary, spacing: -0.1),
      labelMedium: s(13, FontWeight.w500, p.textSecondary),
      labelSmall: s(12, FontWeight.w500, p.textSecondary, height: 1.3),
    );
  }

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final text = textTheme(p);
    const md = BorderRadius.all(Radius.circular(AppRadius.md));
    const mdShape = RoundedRectangleBorder(borderRadius: md);
    final borderSide = BorderSide(color: p.border);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      secondary: p.accent,
      onSecondary: p.onPrimary,
      tertiary: p.accent,
      onTertiary: p.onPrimary,
      error: p.danger,
      onError: p.surface,
      errorContainer: p.dangerMuted,
      onErrorContainer: p.danger,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.surface,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceMuted,
      surfaceContainerHighest: p.surfaceMuted,
      outline: p.border,
      outlineVariant: p.border,
      inverseSurface: p.textPrimary,
      onInverseSurface: p.background,
      inversePrimary: p.accent,
      primaryContainer: p.surfaceMuted,
      onPrimaryContainer: p.textPrimary,
      secondaryContainer: p.surfaceMuted,
      onSecondaryContainer: p.textPrimary,
      shadow: Colors.transparent,
      scrim: p.textPrimary.withValues(alpha: 0.32),
      surfaceTint: Colors.transparent,
    );

    final buttonText = text.labelLarge!;
    const buttonPadding = EdgeInsets.symmetric(horizontal: 16);
    // Min height 44 for every button; full-width primary actions use 48
    // (`kPrimaryButtonHeight`, applied by AppSheetLayout).
    const buttonMinSize = Size(64, 44);

    return ThemeData(
      useMaterial3: true,
      // Desktop and web would otherwise default to compact density, which
      // shrinks buttons to 36 px and inputs/list rows accordingly.
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      primaryTextTheme: text,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      cardColor: p.surface,
      dividerColor: p.border,
      splashFactory: InkRipple.splashFactory,
      highlightColor: p.surfaceMuted,
      splashColor: p.border.withValues(alpha: 0.4),
      hoverColor: p.surfaceMuted,
      focusColor: p.surfaceMuted,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        iconTheme: IconThemeData(color: p.textPrimary, size: 22),
        actionsIconTheme: IconThemeData(color: p.textPrimary, size: 22),
        titleTextStyle: text.titleMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: p.surfaceMuted,
        indicatorShape: mdShape,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? p.textPrimary
                : p.textTertiary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall!.copyWith(
            color: s.contains(WidgetState.selected)
                ? p.textPrimary
                : p.textTertiary,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        indicatorColor: p.surfaceMuted,
        indicatorShape: mdShape,
        useIndicator: true,
        selectedIconTheme: IconThemeData(color: p.textPrimary, size: 24),
        unselectedIconTheme: IconThemeData(color: p.textTertiary, size: 24),
        selectedLabelTextStyle:
            text.labelMedium!.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle:
            text.labelMedium!.copyWith(color: p.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: md, side: borderSide),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        minTileHeight: 56,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall,
        shape: const RoundedRectangleBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceMuted,
          disabledForegroundColor: p.textTertiary,
          elevation: 0,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: mdShape,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          disabledBackgroundColor: p.surfaceMuted,
          disabledForegroundColor: p.textTertiary,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: mdShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: borderSide,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: mdShape,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: mdShape,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textPrimary,
          shape: mdShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        disabledElevation: 0,
        shape: mdShape,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        isDense: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: text.bodyMedium!.copyWith(color: p.textTertiary),
        labelStyle: text.bodyMedium!.copyWith(color: p.textSecondary),
        floatingLabelStyle: text.bodySmall!.copyWith(color: p.textSecondary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: p.danger),
        prefixIconColor: p.textTertiary,
        suffixIconColor: p.textTertiary,
        border: OutlineInputBorder(borderRadius: md, borderSide: borderSide),
        enabledBorder:
            OutlineInputBorder(borderRadius: md, borderSide: borderSide),
        disabledBorder:
            OutlineInputBorder(borderRadius: md, borderSide: borderSide),
        focusedBorder: OutlineInputBorder(
          borderRadius: md,
          borderSide: BorderSide(color: p.textPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: md,
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: md,
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.textPrimary,
        selectionColor: p.accent.withValues(alpha: 0.25),
        selectionHandleColor: p.accent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
          side: borderSide,
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium!.copyWith(color: p.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: md, side: borderSide),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: md, side: borderSide),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.surfaceMuted,
        disabledColor: p.surfaceMuted,
        side: borderSide,
        shape: mdShape,
        labelStyle: text.labelMedium!.copyWith(color: p.textPrimary),
        secondaryLabelStyle: text.labelMedium!.copyWith(color: p.textPrimary),
        checkmarkColor: p.textPrimary,
        elevation: 0,
        pressElevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        showCheckmark: false,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(mdShape),
          side: WidgetStatePropertyAll(borderSide),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.surfaceMuted : p.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? p.textPrimary
                : p.textSecondary,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        side: BorderSide(color: p.textTertiary, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.textTertiary,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.textPrimary,
        linearTrackColor: p.surfaceMuted,
        circularTrackColor: Colors.transparent,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.primary,
        inactiveTrackColor: p.border,
        thumbColor: p.primary,
        overlayColor: p.primary.withValues(alpha: 0.08),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textSecondary,
        labelStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: text.labelLarge,
        indicatorColor: p.textPrimary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.border,
        dividerHeight: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.textPrimary,
        contentTextStyle: text.bodyMedium!.copyWith(color: p.background),
        actionTextColor: p.background,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: mdShape,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textPrimary,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        textStyle: text.labelSmall!.copyWith(color: p.background),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
    );
  }
}
