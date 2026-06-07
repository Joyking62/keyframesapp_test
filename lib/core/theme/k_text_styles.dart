import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

import 'k_colors.dart';

/// Centralized typography tokens for the Keyframes brand.
///
/// The type scale is taken verbatim from the design's "Typography Scale"
/// table. Headings and brand text use **Poppins**; body and general UI text
/// use **Inter**. Both families are resolved at runtime via `google_fonts`.
///
/// Each token specifies font family, size, weight, and a unit-less line
/// height (`height`), matching the `Size / Weight / Height` column from the
/// design. The default text color is [KColors.slate700] (primary text on
/// light surfaces); callers may override the color via `copyWith` where a
/// different surface demands it (e.g. on-navy text).
abstract final class KTextStyles {
  /// Splash tagline, hero titles — Poppins 34 / w700 / 1.15.
  static TextStyle get displayLg => GoogleFonts.poppins(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: KColors.slate700,
      );

  /// Screen titles — Poppins 26 / w600 / 1.2.
  static TextStyle get headingLg => GoogleFonts.poppins(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: KColors.slate700,
      );

  /// Section headers, dialog titles — Poppins 20 / w600 / 1.25.
  static TextStyle get headingMd => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: KColors.slate700,
      );

  /// Card titles, service names — Poppins 17 / w600 / 1.3.
  static TextStyle get titleMd => GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: KColors.slate700,
      );

  /// Primary body text — Inter 16 / w400 / 1.5.
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: KColors.slate700,
      );

  /// Secondary text, descriptions — Inter 14 / w400 / 1.5.
  static TextStyle get bodyMd => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: KColors.slate700,
      );

  /// Buttons, chips, tabs — Inter 13 / w500 / 1.3.
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: KColors.slate700,
      );

  /// Timestamps, helper text — Inter 12 / w400 / 1.4.
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: KColors.slate500,
      );

  /// Assembles a Material [TextTheme] from the Keyframes type scale.
  ///
  /// The scale is mapped onto Material 3 text-theme slots so that framework
  /// widgets (e.g. [AppBar], [ListTile]) pick up the brand typography by
  /// default:
  /// - display/headline large -> [displayLg]
  /// - headline medium        -> [headingLg]
  /// - title large            -> [headingMd]
  /// - title medium           -> [titleMd]
  /// - body large             -> [bodyLg]
  /// - body medium            -> [bodyMd]
  /// - label large            -> [label]
  /// - body/label small       -> [caption]
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLg,
        displayMedium: headingLg,
        displaySmall: headingMd,
        headlineLarge: displayLg,
        headlineMedium: headingLg,
        headlineSmall: headingMd,
        titleLarge: headingMd,
        titleMedium: titleMd,
        titleSmall: titleMd,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: caption,
        labelLarge: label,
        labelMedium: label,
        labelSmall: caption,
      );
}
