import 'package:flutter/material.dart';

/// Keyframes brand palette.
///
/// Primary: deep dark-blue family.
/// Secondary/accent: golden amber family.
/// Neutral: white & soft greys carry the majority of surfaces.
class AppColors {
  AppColors._();

  // ---- Dark blue family ----
  static const Color navy = Color(0xFF0B1F4D); // deepest
  static const Color navy700 = Color(0xFF112A66);
  static const Color navy600 = Color(0xFF14306E);
  static const Color navy500 = Color(0xFF1C3F8F);
  static const Color navy300 = Color(0xFF4661B0);

  // ---- Golden amber family ----
  static const Color amber = Color(0xFFF5A623); // brand gold
  static const Color amberBright = Color(0xFFFFC23C);
  static const Color amberDeep = Color(0xFFE08A00);

  // ---- Neutrals ----
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF6F8FC);
  static const Color cloud = Color(0xFFEDF1F8);
  static const Color slate = Color(0xFF8A93A6);
  static const Color ink = Color(0xFF0E1428);

  // ---- Semantic ----
  static const Color success = Color(0xFF1FBF75);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color info = Color(0xFF3B82F6);

  // ---- Gradients ----
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navy600, navy500],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amberBright, amber, amberDeep],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navy700, navy500],
  );

  static const RadialGradient splashGlow = RadialGradient(
    center: Alignment.center,
    radius: 0.9,
    colors: [navy600, navy, Color(0xFF050D24)],
    stops: [0.0, 0.6, 1.0],
  );

  // Glass overlays
  static Color glassLight = white.withOpacity(0.10);
  static Color glassBorder = white.withOpacity(0.18);
}
