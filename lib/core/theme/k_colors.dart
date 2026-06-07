import 'package:flutter/widgets.dart';

/// Centralized color tokens for the Keyframes brand.
///
/// The palette uses **navy (dark blue)** and **golden amber** as
/// primary/secondary colors, with **white** as the dominant surface color for
/// a clean, professional, airy feel. Status colors communicate order state.
///
/// Token values are taken verbatim from the design's Color Palette table.
abstract final class KColors {
  // Navy — brand primary family.
  /// Deepest navy — splash background, headers, gradients base.
  static const Color navy900 = Color(0xFF0A1A3F);

  /// Primary brand navy — app bar, primary buttons.
  static const Color navy800 = Color(0xFF0F2455);

  /// Navy mid — gradients, selected states.
  static const Color navy600 = Color(0xFF1C3A7A);

  /// Navy accents, icons on light surfaces.
  static const Color navy400 = Color(0xFF3A5BA0);

  // Amber — brand secondary family.
  /// Primary golden amber — CTAs, highlights, logo nodes.
  static const Color amber500 = Color(0xFFF5A623);

  /// Amber light — hover/pressed, gradient top.
  static const Color amber400 = Color(0xFFFFB940);

  /// Amber tint — badges, subtle highlights.
  static const Color amber300 = Color(0xFFFFD27F);

  // Surfaces.
  /// Primary surfaces, cards, backgrounds.
  static const Color white = Color(0xFFFFFFFF);

  /// Scaffold background (soft, not pure white).
  static const Color offWhite = Color(0xFFF6F8FC);

  // Text & neutrals.
  /// Primary text on light surfaces.
  static const Color slate700 = Color(0xFF2B3553);

  /// Secondary text, captions.
  static const Color slate500 = Color(0xFF5B647F);

  /// Dividers, borders, disabled.
  static const Color slate200 = Color(0xFFE3E8F2);

  // Status.
  /// Order completed / positive status.
  static const Color success = Color(0xFF2DBE7E);

  /// Pending / in-review status (amber).
  static const Color warning = Color(0xFFF5A623);

  /// Errors, cancelled order.
  static const Color danger = Color(0xFFE5484D);
}
