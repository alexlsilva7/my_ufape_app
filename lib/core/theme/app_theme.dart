import 'package:flutter/material.dart';

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xff4f46e5),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xffa5b4fc) : const Color(0xff635bff),
        onPrimary: dark ? const Color(0xff1e1b4b) : Colors.white,
      );
  final interactionOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.hovered)) {
      return scheme.primary.withValues(alpha: dark ? .16 : .08);
    }
    if (states.contains(WidgetState.focused)) {
      return scheme.primary.withValues(alpha: dark ? .2 : .12);
    }
    return null;
  });
  return ThemeData(
    fontFamily: 'Inter',
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    hoverColor: scheme.primary.withValues(alpha: dark ? .16 : .08),
    focusColor: scheme.primary.withValues(alpha: dark ? .2 : .12),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(overlayColor: interactionOverlay),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(overlayColor: interactionOverlay),
    ),
    scaffoldBackgroundColor: dark
        ? const Color(0xff020617)
        : const Color(0xfff8fafc),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xff0f172a) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xff0f172a) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: dark ? const Color(0xff1e293b) : const Color(0xffe2e8f0),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -.6,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}
