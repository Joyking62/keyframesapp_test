import 'package:flutter/widgets.dart';

/// Reusable spacing, corner-radius, elevation, and touch-target tokens.
///
/// Spacing follows a 4-point base scale. Radius tokens drive consistent
/// rounding across surfaces, cards, and modals. Elevation tokens express the
/// soft navy shadows used on cards and modals from the design's
/// "Spacing, Radius & Elevation" section.
///
/// The shadow colors below are the `KColors.navy900` token (`0xFF0A1A3F`) with
/// alpha applied; they are expressed as `const` ARGB literals because
/// `Color.withOpacity` is not a compile-time constant.
abstract final class KSpace {
  // Spacing scale (4-pt base).
  /// 4.0
  static const double xs = 4.0;

  /// 8.0
  static const double sm = 8.0;

  /// 12.0
  static const double md = 12.0;

  /// 16.0
  static const double lg = 16.0;

  /// 24.0
  static const double xl = 24.0;

  /// 32.0
  static const double xxl = 32.0;

  /// 48.0
  static const double xxxl = 48.0;

  // Corner-radius tokens.
  /// 8.0
  static const double rSm = 8.0;

  /// 12.0
  static const double rMd = 12.0;

  /// 16.0
  static const double rLg = 16.0;

  /// 24.0
  static const double rXl = 24.0;

  /// 999.0 — fully rounded ("pill") shape.
  static const double rPill = 999.0;

  /// Minimum interactive touch-target size (logical pixels).
  static const double minTouchTarget = 48.0;

  /// Card elevation: soft navy shadow (navy900 @ ~8%, blur 24, y 8).
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x140A1A3F), // navy900 @ ~8% alpha (0x14 = 20/255)
      blurRadius: 24.0,
      offset: Offset(0.0, 8.0),
    ),
  ];

  /// Modal elevation: deeper navy shadow (navy900 @ ~12%, blur 40, y 16).
  static const List<BoxShadow> modalShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0A1A3F), // navy900 @ ~12% alpha (0x1F = 31/255)
      blurRadius: 40.0,
      offset: Offset(0.0, 16.0),
    ),
  ];
}
