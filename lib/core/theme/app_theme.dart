import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    primaryColor: const Color(0xFFD900EE), // Neon Pink
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFD900EE), // Neon Pink
      secondary: Color(0xFF00D2FF), // Neon Blue
      surface: Colors.black,
      background: Colors.black,
      // Add tertiary for other accents if needed
      tertiary: Color(0xFF00D2FF),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
    // Customize floating action button to use the gradient aesthetic if possible (via container),
    // otherwise fallback to primary pink.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFFD900EE),
      foregroundColor: Colors.white,
    ),
  );
}
