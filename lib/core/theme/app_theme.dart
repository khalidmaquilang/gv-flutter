import 'package:flutter/material.dart';

class AppColors {
  static const Color neonPink = Color(0xFFD900EE);
  static const Color neonBlue = Color(0xFF00D2FF);
  static const Color background = Colors.black;
  static const Color textMain = Colors.white;
}

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.neonPink,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.neonPink,
      secondary: AppColors.neonBlue,
      surface: AppColors.background,
      background: AppColors.background,
      tertiary: AppColors.neonBlue,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textMain),
      bodyMedium: TextStyle(color: AppColors.textMain),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.neonPink,
      foregroundColor: AppColors.textMain,
    ),
  );
}
