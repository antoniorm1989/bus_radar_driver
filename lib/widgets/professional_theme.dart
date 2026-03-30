import 'package:flutter/material.dart';

final ThemeData professionalTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.blue.shade800,
    primary: Colors.blue.shade800,
    secondary: Colors.blueGrey.shade700,
    background: Colors.grey.shade50,
    surface: Colors.white,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onBackground: Colors.black87,
    onSurface: Colors.black87,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1A237E),
    foregroundColor: Colors.white,
    elevation: 1,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 22,
      color: Colors.white,
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: 16),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: MaterialStatePropertyAll(Color(0xFF1A237E)),
      foregroundColor: MaterialStatePropertyAll(Colors.white),
      minimumSize: MaterialStatePropertyAll(Size(220, 56)),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      ),
      textStyle: MaterialStatePropertyAll(
        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  ),
  scaffoldBackgroundColor: Colors.grey.shade50,
  useMaterial3: true,
);
