import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF3B82F6),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF10B981),
        surface: Color(0xFF1E293B),
        background: Color(0xFF0F172A),
        error: Color(0xFFEF4444),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardTheme(
        color: const Color(0xFF1E293B),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontFamily: 'Inter'),
        bodyMedium: TextStyle(color: Colors.white70, fontFamily: 'Inter'),
        titleLarge: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontWeight: FontWeight.bold),
      ),
    );
  }
}
