import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF81CEF2); // Sky Blue from Login Page
  static const secondaryColor = Color(0xFF141416); // Dark background
  static const errorColor = Color(0xFFE53935);
  static const successColor = Color(0xFF3ECC58);

  // Line Seed Sans TH font family
  static const String fontFamily = 'LINESeedSansTH';

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: Colors.white,
        error: errorColor,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.3,
          letterSpacing: -0.2,
        ),
        titleSmall: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.3,
          letterSpacing: -0.2,
        ),
        bodyLarge: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: -0.2,
        ),
        bodySmall: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: -0.1,
        ),
        labelLarge: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.1,
        ),
        labelMedium: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.2,
          letterSpacing: -0.1,
        ),
        labelSmall: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.2,
          letterSpacing: -0.1,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 20,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
      ),
    );
  }

  // Dark theme can be added later if needed
}
