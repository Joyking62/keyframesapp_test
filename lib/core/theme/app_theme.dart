import 'package:flutter/material.dart';

import 'k_colors.dart';
import 'k_space.dart';
import 'k_text_styles.dart';

/// Builds the global Keyframes [ThemeData].
///
/// The theme is **light-first** with a navy/amber color scheme over an
/// off-white scaffold. It wires together the brand tokens defined elsewhere in
/// `core/theme`:
/// - [KColors] for the navy/amber/white palette and status colors,
/// - [KTextStyles] for the Poppins/Inter type scale, and
/// - [KSpace] for corner-radius and elevation tokens.
///
/// Interactive components are configured for a **minimum 48x48 logical-pixel**
/// touch target (via [VisualDensity], [MaterialTapTargetSize], and explicit
/// minimum button sizes) to satisfy the design's accessibility target.
ThemeData buildKeyframesTheme() {
  // Navy primary + amber secondary over light surfaces.
  const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: KColors.navy800,
    onPrimary: KColors.white,
    primaryContainer: KColors.navy600,
    onPrimaryContainer: KColors.white,
    secondary: KColors.amber500,
    onSecondary: KColors.navy900,
    secondaryContainer: KColors.amber300,
    onSecondaryContainer: KColors.navy900,
    tertiary: KColors.amber400,
    onTertiary: KColors.navy900,
    error: KColors.danger,
    onError: KColors.white,
    surface: KColors.white,
    onSurface: KColors.slate700,
    surfaceContainerHighest: KColors.offWhite,
    onSurfaceVariant: KColors.slate500,
    outline: KColors.slate200,
    outlineVariant: KColors.slate200,
    shadow: KColors.navy900,
    scrim: KColors.navy900,
    inverseSurface: KColors.navy900,
    onInverseSurface: KColors.white,
    inversePrimary: KColors.amber400,
  );

  final TextTheme textTheme = KTextStyles.textTheme;

  // Pill-shaped corner radius reused across buttons and chips.
  final OutlinedBorder pillShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(KSpace.rPill),
  );
  final RoundedRectangleBorder mdShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(KSpace.rMd),
  );
  final RoundedRectangleBorder lgShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(KSpace.rLg),
  );

  // Enforce a 48x48 minimum hit area for tappable controls.
  const Size minTarget = Size(KSpace.minTouchTarget, KSpace.minTouchTarget);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: KColors.offWhite,
    canvasColor: KColors.offWhite,
    primaryColor: KColors.navy800,
    textTheme: textTheme,

    // Global accessibility: comfortable density + 48x48 tap targets.
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,

    dividerTheme: const DividerThemeData(
      color: KColors.slate200,
      thickness: 1,
      space: KSpace.lg,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: KColors.navy800,
      foregroundColor: KColors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: KTextStyles.headingMd.copyWith(color: KColors.white),
      toolbarTextStyle: KTextStyles.bodyMd.copyWith(color: KColors.white),
      iconTheme: const IconThemeData(color: KColors.white),
      actionsIconTheme: const IconThemeData(color: KColors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KColors.navy800,
        foregroundColor: KColors.white,
        disabledBackgroundColor: KColors.slate200,
        disabledForegroundColor: KColors.slate500,
        elevation: 0,
        minimumSize: minTarget,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.xl,
          vertical: KSpace.md,
        ),
        shape: pillShape,
        textStyle: KTextStyles.label,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KColors.amber500,
        foregroundColor: KColors.navy900,
        disabledBackgroundColor: KColors.slate200,
        disabledForegroundColor: KColors.slate500,
        minimumSize: minTarget,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.xl,
          vertical: KSpace.md,
        ),
        shape: pillShape,
        textStyle: KTextStyles.label,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KColors.navy800,
        side: const BorderSide(color: KColors.navy400),
        minimumSize: minTarget,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.xl,
          vertical: KSpace.md,
        ),
        shape: pillShape,
        textStyle: KTextStyles.label,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KColors.navy800,
        minimumSize: minTarget,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.lg,
          vertical: KSpace.sm,
        ),
        shape: pillShape,
        textStyle: KTextStyles.label,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: KColors.navy800,
        minimumSize: minTarget,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KSpace.lg,
        vertical: KSpace.md,
      ),
      hintStyle: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
      labelStyle: KTextStyles.bodyMd.copyWith(color: KColors.slate500),
      floatingLabelStyle: KTextStyles.label.copyWith(color: KColors.navy800),
      helperStyle: KTextStyles.caption,
      errorStyle: KTextStyles.caption.copyWith(color: KColors.danger),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KSpace.rMd),
        borderSide: const BorderSide(color: KColors.slate200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KSpace.rMd),
        borderSide: const BorderSide(color: KColors.navy600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KSpace.rMd),
        borderSide: const BorderSide(color: KColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KSpace.rMd),
        borderSide: const BorderSide(color: KColors.danger, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KSpace.rMd),
        borderSide: const BorderSide(color: KColors.slate200),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: KColors.white,
      selectedColor: KColors.navy800,
      secondarySelectedColor: KColors.amber500,
      disabledColor: KColors.slate200,
      labelStyle: KTextStyles.label,
      secondaryLabelStyle: KTextStyles.label.copyWith(color: KColors.white),
      side: const BorderSide(color: KColors.slate200),
      shape: pillShape,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpace.md,
        vertical: KSpace.sm,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: KSpace.xs),
    ),

    cardTheme: CardTheme(
      color: KColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(KSpace.sm),
      shadowColor: KColors.navy900,
      shape: lgShape,
      clipBehavior: Clip.antiAlias,
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: KColors.white,
      selectedItemColor: KColors.navy800,
      unselectedItemColor: KColors.slate500,
      selectedLabelStyle: KTextStyles.caption,
      unselectedLabelStyle: KTextStyles.caption,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dialogTheme: DialogTheme(
      backgroundColor: KColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KSpace.rXl),
      ),
      titleTextStyle: KTextStyles.headingMd,
      contentTextStyle: KTextStyles.bodyMd,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: KColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KSpace.rXl),
        ),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: KColors.navy900,
      contentTextStyle: KTextStyles.bodyMd.copyWith(color: KColors.white),
      actionTextColor: KColors.amber400,
      behavior: SnackBarBehavior.floating,
      shape: mdShape,
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KColors.amber500,
      linearTrackColor: KColors.slate200,
      circularTrackColor: KColors.slate200,
    ),

    iconTheme: const IconThemeData(color: KColors.navy400),
  );
}
