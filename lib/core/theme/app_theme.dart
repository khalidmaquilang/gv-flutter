import 'package:flutter/material.dart';

class AppColors {
  static const Color neonPink = Color(0xFFFF00DE);
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonPurple = Color(0xFF7B00FF);
  static const Color deepVoid = Color(0xFF050505);
  static const Color textMain = Colors.white;

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [neonPink, neonCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.deepVoid,
    primaryColor: AppColors.neonPink,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.neonPink,
      secondary: AppColors.neonCyan,
      surface: AppColors.deepVoid,
      tertiary: AppColors.neonPurple,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deepVoid,
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
