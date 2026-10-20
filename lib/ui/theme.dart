import 'package:flutter/material.dart';

/// Black glassmorphism palette: near-black canvas, translucent white
/// surfaces, hairline borders, one soft accent.
abstract final class Palette {
  static const background = Color(0xFF050507);
  static const accent = Color(0xFFC9B8FF); // soft lilac
  static const text = Color(0xF2FFFFFF);
  static const textDim = Color(0x99FFFFFF);
  static const textFaint = Color(0x5CFFFFFF);
  static const glass = Color(0x0FFFFFFF); // ~6% white
  static const glassStrong = Color(0x1AFFFFFF); // ~10% white
  static const border = Color(0x1FFFFFFF); // ~12% white
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: Palette.accent,
        onPrimary: Colors.black,
        surface: Palette.background,
        onSurface: Palette.text,
        onSurfaceVariant: Palette.textDim,
        surfaceContainerHighest: const Color(0xFF16161B),
        outline: Palette.border,
        outlineVariant: Palette.border,
      );

  final base = ThemeData(colorScheme: scheme, brightness: Brightness.dark);
  final text = base.textTheme.apply(
    bodyColor: Palette.text,
    displayColor: Palette.text,
  );

  OutlineInputBorder field(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c),
  );

  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Palette.background,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodySmall: text.bodySmall?.copyWith(color: Palette.textDim),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: Palette.border, thickness: 1),
    iconTheme: const IconThemeData(color: Palette.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.glass,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: const TextStyle(color: Palette.textFaint),
      labelStyle: const TextStyle(color: Palette.textDim),
      border: field(Palette.border),
      enabledBorder: field(Palette.border),
      focusedBorder: field(Palette.accent.withValues(alpha: 0.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.text,
        side: const BorderSide(color: Palette.border),
        backgroundColor: Palette.glass,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Palette.text),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Colors.black : Palette.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : Palette.glass,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Palette.border),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Colors.white,
      inactiveTrackColor: Palette.glassStrong,
      thumbColor: Colors.white,
      overlayColor: Color(0x14FFFFFF),
      trackHeight: 3,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.accent,
      linearTrackColor: Palette.glassStrong,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: Palette.glass,
        foregroundColor: Palette.textDim,
        selectedBackgroundColor: Colors.white,
        selectedForegroundColor: Colors.black,
        side: const BorderSide(color: Palette.border),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: const Color(0xF0141418),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Palette.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xE6101014),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Palette.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xE61A1A20),
      contentTextStyle: const TextStyle(color: Palette.text),
      actionTextColor: Palette.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Palette.border),
      ),
      width: 420,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: const Color(0xF01A1A20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Palette.border),
      ),
      textStyle: const TextStyle(color: Palette.text, fontSize: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Palette.textDim,
      textColor: Palette.text,
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Color(0xF0141418)),
      ),
    ),
  );
}
