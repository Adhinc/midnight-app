import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MidnightTheme {
  static const Color bgColor = Color(0xFF050511);
  static const Color surfaceColor = Color(0xFF141428); // Slightly lighter for cards
  static const Color primaryColor = Color(0xFF7B61FF);
  static const Color secondaryColor = Color(0xFF00D4FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0B0);

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgColor,
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: surfaceColor,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
      displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 8,
        shadowColor: primaryColor.withOpacity(0.4),
      ),
    ),
    useMaterial3: true,
  );
}
