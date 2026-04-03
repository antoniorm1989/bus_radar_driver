import 'package:flutter/material.dart';

const Color _primaryBlue = Color(0xFF17325C);
const Color _secondaryBlue = Color(0xFF335B8E);
const Color _surfaceTint = Color(0xFFE8EEF6);
const Color _pageBackground = Color(0xFFF3F5F8);
const Color _textPrimary = Color(0xFF162033);
const Color _textMuted = Color(0xFF5C6779);

final ColorScheme _appColorScheme = ColorScheme.fromSeed(
  seedColor: _primaryBlue,
  brightness: Brightness.light,
).copyWith(
  primary: _primaryBlue,
  secondary: _secondaryBlue,
  surface: Colors.white,
  onSurface: _textPrimary,
  onPrimary: Colors.white,
  onSecondary: Colors.white,
  surfaceTint: _surfaceTint,
  outline: const Color(0xFFD2DAE6),
  error: const Color(0xFFB3261E),
  onError: Colors.white,
);

final ThemeData professionalTheme = ThemeData(
  colorScheme: _appColorScheme,
  scaffoldBackgroundColor: _pageBackground,
  useMaterial3: true,
  appBarTheme: const AppBarTheme(
    backgroundColor: _primaryBlue,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.2,
    ),
  ),
  drawerTheme: const DrawerThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: _textPrimary,
      height: 1.1,
    ),
    titleLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: _textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: _textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: _textPrimary,
      height: 1.35,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      color: _textMuted,
      height: 1.45,
    ),
    labelLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return _primaryBlue.withValues(alpha: 0.38);
        }
        return _primaryBlue;
      }),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      minimumSize: const WidgetStatePropertyAll(Size(220, 58)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primaryBlue,
      side: const BorderSide(color: Color(0xFFD2DAE6)),
      minimumSize: const Size(180, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shadowColor: Colors.black.withValues(alpha: 0.08),
    surfaceTintColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFE3E8F0),
    thickness: 1,
    space: 1,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD2DAE6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFD2DAE6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _primaryBlue, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
  ),
);
