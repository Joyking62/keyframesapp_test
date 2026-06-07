import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyframes_app/core/theme/k_colors.dart';
import 'package:keyframes_app/core/theme/k_space.dart';
import 'package:keyframes_app/core/theme/k_text_styles.dart';

/// Unit tests for the Keyframes design-system tokens.
///
/// These lock the brand palette, spacing/radius scale, and typography scale to
/// the exact values defined in the design document so accidental drift in any
/// token is caught at test time.
///
/// Validates: Requirements 13.1, 13.2, 13.3
void main() {
  group('KColors palette (Requirement 13.1)', () {
    test('navy family tokens use the exact design hex values', () {
      expect(KColors.navy900.value, 0xFF0A1A3F);
      expect(KColors.navy800.value, 0xFF0F2455);
      expect(KColors.navy600.value, 0xFF1C3A7A);
      expect(KColors.navy400.value, 0xFF3A5BA0);
    });

    test('amber family tokens use the exact design hex values', () {
      expect(KColors.amber500.value, 0xFFF5A623);
      expect(KColors.amber400.value, 0xFFFFB940);
      expect(KColors.amber300.value, 0xFFFFD27F);
    });

    test('surface tokens use the exact design hex values', () {
      expect(KColors.white.value, 0xFFFFFFFF);
      expect(KColors.offWhite.value, 0xFFF6F8FC);
    });

    test('text & neutral tokens use the exact design hex values', () {
      expect(KColors.slate700.value, 0xFF2B3553);
      expect(KColors.slate500.value, 0xFF5B647F);
      expect(KColors.slate200.value, 0xFFE3E8F2);
    });

    test('status tokens use the exact design hex values', () {
      expect(KColors.success.value, 0xFF2DBE7E);
      expect(KColors.warning.value, 0xFFF5A623);
      expect(KColors.danger.value, 0xFFE5484D);
    });

    test('warning status reuses the amber500 brand token', () {
      expect(KColors.warning.value, KColors.amber500.value);
    });
  });

  group('KSpace spacing, radius & elevation tokens (Requirement 13.3)', () {
    test('spacing scale follows the 4-point base scale', () {
      expect(KSpace.xs, 4.0);
      expect(KSpace.sm, 8.0);
      expect(KSpace.md, 12.0);
      expect(KSpace.lg, 16.0);
      expect(KSpace.xl, 24.0);
      expect(KSpace.xxl, 32.0);
      expect(KSpace.xxxl, 48.0);
    });

    test('corner-radius tokens match the design scale', () {
      expect(KSpace.rSm, 8.0);
      expect(KSpace.rMd, 12.0);
      expect(KSpace.rLg, 16.0);
      expect(KSpace.rXl, 24.0);
      expect(KSpace.rPill, 999.0);
    });

    test('minimum touch target is 48 logical pixels (Requirement 13.4 support)',
        () {
      expect(KSpace.minTouchTarget, 48.0);
    });

    test('card elevation is a soft navy900-based shadow', () {
      expect(KSpace.cardShadow, hasLength(1));
      final BoxShadow shadow = KSpace.cardShadow.first;
      expect(shadow.color.value, 0x140A1A3F);
      expect(shadow.blurRadius, 24.0);
      expect(shadow.offset, const Offset(0.0, 8.0));
    });

    test('modal elevation is a deeper navy900-based shadow', () {
      expect(KSpace.modalShadow, hasLength(1));
      final BoxShadow shadow = KSpace.modalShadow.first;
      expect(shadow.color.value, 0x1F0A1A3F);
      expect(shadow.blurRadius, 40.0);
      expect(shadow.offset, const Offset(0.0, 16.0));
    });
  });

  group('KTextStyles typography scale (Requirement 13.2)', () {
    test('displayLg is 34 / w700 / 1.15', () {
      final TextStyle style = KTextStyles.displayLg;
      expect(style.fontSize, 34);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.height, 1.15);
      expect(style.color, KColors.slate700);
    });

    test('headingLg is 26 / w600 / 1.2', () {
      final TextStyle style = KTextStyles.headingLg;
      expect(style.fontSize, 26);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.2);
      expect(style.color, KColors.slate700);
    });

    test('headingMd is 20 / w600 / 1.25', () {
      final TextStyle style = KTextStyles.headingMd;
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.25);
      expect(style.color, KColors.slate700);
    });

    test('titleMd is 17 / w600 / 1.3', () {
      final TextStyle style = KTextStyles.titleMd;
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.3);
      expect(style.color, KColors.slate700);
    });

    test('bodyLg is 16 / w400 / 1.5', () {
      final TextStyle style = KTextStyles.bodyLg;
      expect(style.fontSize, 16);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.height, 1.5);
      expect(style.color, KColors.slate700);
    });

    test('bodyMd is 14 / w400 / 1.5', () {
      final TextStyle style = KTextStyles.bodyMd;
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.height, 1.5);
      expect(style.color, KColors.slate700);
    });

    test('label is 13 / w500 / 1.3', () {
      final TextStyle style = KTextStyles.label;
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.height, 1.3);
      expect(style.color, KColors.slate700);
    });

    test('caption is 12 / w400 / 1.4 and uses the secondary text color', () {
      final TextStyle style = KTextStyles.caption;
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.height, 1.4);
      expect(style.color, KColors.slate500);
    });

    test('headings & brand text resolve to the Poppins family', () {
      expect(KTextStyles.displayLg.fontFamily, contains('Poppins'));
      expect(KTextStyles.headingLg.fontFamily, contains('Poppins'));
      expect(KTextStyles.headingMd.fontFamily, contains('Poppins'));
      expect(KTextStyles.titleMd.fontFamily, contains('Poppins'));
    });

    test('body & UI text resolve to the Inter family', () {
      expect(KTextStyles.bodyLg.fontFamily, contains('Inter'));
      expect(KTextStyles.bodyMd.fontFamily, contains('Inter'));
      expect(KTextStyles.label.fontFamily, contains('Inter'));
      expect(KTextStyles.caption.fontFamily, contains('Inter'));
    });

    test('textTheme maps the named styles onto Material 3 slots', () {
      final TextTheme theme = KTextStyles.textTheme;
      expect(theme.displayLarge?.fontSize, 34);
      expect(theme.headlineMedium?.fontSize, 26);
      expect(theme.titleLarge?.fontSize, 20);
      expect(theme.titleMedium?.fontSize, 17);
      expect(theme.bodyLarge?.fontSize, 16);
      expect(theme.bodyMedium?.fontSize, 14);
      expect(theme.labelLarge?.fontSize, 13);
      expect(theme.bodySmall?.fontSize, 12);
    });
  });
}
