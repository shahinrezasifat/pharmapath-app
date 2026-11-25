import 'dart:ui';

import 'package:flutter/material.dart';

/// Central design system for PharmaPath.
///
/// A focused blue design system shared by the app's light and dark themes.
abstract final class AppTheme {
  static const Color seed = Color(0xFF2563EB);
  static const String fontFamily = 'Anek Bangla';

  static const Color lightBackground = Color(0xFFF4F8FF);
  static const Color darkBackground = Color(0xFF080F1D);

  static const double radius = 20;
  static const double smallRadius = 14;

  /// Soft blur used by glassmorphic surfaces (e.g. redesigned header).
  static final ImageFilter blurFilter = ImageFilter.blur(
    sigmaX: 12,
    sigmaY: 12,
  );

  static ThemeData get light => _base(_lightScheme, Brightness.light);
  static ThemeData get dark => _base(_darkScheme, Brightness.dark);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Blue gradient used by prominent summary panels.
  static LinearGradient heroGradient(BuildContext context) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark(context)
        ? const [Color(0xFF1E3A8A), Color(0xFF10213F)]
        : const [Color(0xFF2563EB), Color(0xFF60A5FA)],
  );

  static ColorScheme get _lightScheme {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return base.copyWith(
      primary: const Color(0xFF2563EB),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDBEAFE),
      onPrimaryContainer: const Color(0xFF172554),
      secondary: const Color(0xFF1D4ED8),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFBFDBFE),
      onSecondaryContainer: const Color(0xFF1E3A8A),
      tertiary: const Color(0xFF60A5FA),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFEFF6FF),
      onTertiaryContainer: const Color(0xFF1E40AF),
      error: const Color(0xFF1D4ED8),
      onError: Colors.white,
      errorContainer: const Color(0xFFDBEAFE),
      onErrorContainer: const Color(0xFF1E3A8A),
      surface: lightBackground,
      onSurface: const Color(0xFF101B2D),
      onSurfaceVariant: const Color(0xFF52627A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFEFF4FC),
      surfaceContainerHigh: const Color(0xFFE5EDF9),
      surfaceContainerHighest: const Color(0xFFD8E4F4),
      outline: const Color(0xFF63748D),
      outlineVariant: const Color(0xFFD0DCEC),
      shadow: const Color(0x14000000),
      scrim: const Color(0x99000000),
      inverseSurface: const Color(0xFF172338),
      onInverseSurface: const Color(0xFFEAF2FF),
      inversePrimary: const Color(0xFF93C5FD),
    );
  }

  static ColorScheme get _darkScheme {
    final base = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      primary: const Color(0xFF60A5FA),
      onPrimary: const Color(0xFF07162D),
      primaryContainer: const Color(0xFF1E3A8A),
      onPrimaryContainer: const Color(0xFFDBEAFE),
      secondary: const Color(0xFF93C5FD),
      onSecondary: const Color(0xFF10213F),
      secondaryContainer: const Color(0xFF1E40AF),
      onSecondaryContainer: const Color(0xFFDBEAFE),
      tertiary: const Color(0xFFBFDBFE),
      onTertiary: const Color(0xFF10213F),
      tertiaryContainer: const Color(0xFF1B3157),
      onTertiaryContainer: const Color(0xFFDBEAFE),
      error: const Color(0xFF93C5FD),
      onError: const Color(0xFF07162D),
      errorContainer: const Color(0xFF1E3A8A),
      onErrorContainer: const Color(0xFFDBEAFE),
      surface: darkBackground,
      onSurface: const Color(0xFFE7EFFB),
      onSurfaceVariant: const Color(0xFFAFBED3),
      surfaceContainerLowest: const Color(0xFF050A13),
      surfaceContainerLow: const Color(0xFF0D1728),
      surfaceContainer: const Color(0xFF111E32),
      surfaceContainerHigh: const Color(0xFF17263D),
      surfaceContainerHighest: const Color(0xFF20324D),
      outline: const Color(0xFF9AAEC8),
      outlineVariant: const Color(0xFF344966),
      shadow: const Color(0x00000000),
      scrim: const Color(0xCC000000),
      inverseSurface: const Color(0xFFE7EFFB),
      onInverseSurface: const Color(0xFF101B2D),
      inversePrimary: const Color(0xFF2563EB),
    );
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final baseText = Typography.material2021(platform: TargetPlatform.android)
        .black;
    final textTheme = baseText
        .apply(fontFamily: fontFamily)
        .copyWith(
          displaySmall: baseText.displaySmall?.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          headlineMedium: baseText.headlineMedium?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          headlineSmall: baseText.headlineSmall?.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          titleLarge: baseText.titleLarge?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: baseText.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          titleSmall: baseText.titleSmall?.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseText.bodyLarge?.copyWith(
            fontSize: 14.5,
            height: 1.45,
          ),
          bodyMedium: baseText.bodyMedium?.copyWith(
            fontSize: 13,
            height: 1.4,
          ),
          bodySmall: baseText.bodySmall?.copyWith(
            fontSize: 11.5,
            height: 1.35,
          ),
          labelLarge: baseText.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelMedium: baseText.labelMedium?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: baseText.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        )
        .apply(
          fontFamily: fontFamily,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    final roundedShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(smallRadius),
    );

    return ThemeData(
      useMaterial3: true,
      visualDensity: const VisualDensity(horizontal: -0.5, vertical: -0.5),
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          elevation: 0,
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          shape: roundedShape,
        ).copyWith(animationDuration: const Duration(milliseconds: 180)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
          shape: roundedShape,
        ).copyWith(animationDuration: const Duration(milliseconds: 180)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ).copyWith(animationDuration: const Duration(milliseconds: 180)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(smallRadius),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 70,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLow,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallRadius),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: fontFamily,
          color: scheme.onInverseSurface,
          fontSize: 12,
        ),
      ),
    );
  }
}
