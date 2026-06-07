import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Professional type scale.
///
/// Headings -> Poppins (geometric, confident).
/// Body     -> Inter (highly legible at small sizes).
///
/// If you bundle fonts offline (see pubspec), swap GoogleFonts.poppins(...)
/// for TextStyle(fontFamily: 'Poppins').
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color onColor) {
    final body = AppColors.ink;
    return TextTheme(
      displayLarge: GoogleFonts.poppins(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -1.0,
        color: onColor,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.1,
        letterSpacing: -0.5,
        color: onColor,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: onColor,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: onColor,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onColor,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: onColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: body,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: body,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.slate,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: onColor,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: AppColors.slate,
      ),
    );
  }

  /// Wordmark style used in the splash & app bar ("KEYFRAMES").
  static TextStyle wordmark({double size = 26, Color color = AppColors.white}) {
    return GoogleFonts.poppins(
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: 6,
      color: color,
    );
  }
}
