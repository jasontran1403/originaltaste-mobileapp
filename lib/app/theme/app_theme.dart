// lib/app/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Dark Theme ────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.primary,
      secondary: AppColors.primaryDark,
      surface:   AppColors.darkSurface,
      error:     AppColors.error,
      onPrimary: Colors.black,
      onSurface: AppColors.darkTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.darkBg,
      foregroundColor:  AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
      hintStyle:  const TextStyle(color: AppColors.darkTextHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 0,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    iconTheme: const IconThemeData(color: AppColors.darkIcon),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold),
      titleLarge:    TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600),
      titleMedium:   TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w500),
      titleSmall:    TextStyle(color: AppColors.darkTextSecondary),
      bodyLarge:     TextStyle(color: AppColors.darkTextPrimary),
      bodyMedium:    TextStyle(color: AppColors.darkTextPrimary),
      bodySmall:     TextStyle(color: AppColors.darkTextSecondary),
      labelLarge:    TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w500),
      labelSmall:    TextStyle(color: AppColors.darkTextHint),
    ),
  );

  // ── Light Theme ───────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    primaryColor: AppColors.primaryDark,
    colorScheme: const ColorScheme.light(
      primary:   AppColors.primaryDark,
      secondary: AppColors.primary,
      surface:   AppColors.lightSurface,
      error:     AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.lightTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
      hintStyle:  const TextStyle(color: AppColors.lightTextHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primaryDark),
    ),
    iconTheme: const IconThemeData(color: AppColors.lightIcon),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.bold),
      titleLarge:    TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w600),
      titleMedium:   TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
      titleSmall:    TextStyle(color: AppColors.lightTextSecondary),
      bodyLarge:     TextStyle(color: AppColors.lightTextPrimary),
      bodyMedium:    TextStyle(color: AppColors.lightTextPrimary),
      bodySmall:     TextStyle(color: AppColors.lightTextSecondary),
      labelLarge:    TextStyle(color: AppColors.lightTextPrimary, fontWeight: FontWeight.w500),
      labelSmall:    TextStyle(color: AppColors.lightTextHint),
    ),
  );
}
