import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import 'package:audio_mixer_app/presentation/widgets/ceramic_texture.dart';

/// Filled / outlined button backgrounds (see [AppTheme.light] / [AppTheme.dark]).
Widget _ceramicFilledButtonBackground(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final r = BorderRadius.circular(AppTheme.radiusMd);
  if (states.contains(WidgetState.disabled)) {
    return ClipRRect(
      borderRadius: r,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: child,
      ),
    );
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
          ? constraints.maxHeight
          : 52.0;
      final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
          ? constraints.maxWidth
          : math.max(constraints.minWidth, 64.0);
      return SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: r,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppTheme.brandLinearTlBr),
              ),
              const Positioned.fill(
                child: CeramicFilmGrain(photoOpacity: 0.48),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: r,
                  ),
                ),
              ),
              if (child != null) child,
            ],
          ),
        ),
      );
    },
  );
}

Widget _ceramicOutlinedButtonBackground(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) {
  final r = BorderRadius.circular(AppTheme.radiusMd);
  if (states.contains(WidgetState.disabled)) {
    return ClipRRect(
      borderRadius: r,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.9,
            ),
        child: child,
      ),
    );
  }
  return LayoutBuilder(
    builder: (context, constraints) {
      final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
          ? constraints.maxHeight
          : 52.0;
      final w = constraints.maxWidth.isFinite && constraints.maxWidth > 0
          ? constraints.maxWidth
          : math.max(constraints.minWidth, 64.0);
      return SizedBox(
        width: w,
        height: h,
        child: ClipRRect(
          borderRadius: r,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(gradient: AppTheme.ceramicHeroRadial),
              ),
              const Positioned.fill(
                child: CeramicFilmGrain(photoOpacity: 0.34),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.58),
                      width: 1.35,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: r,
                  ),
                ),
              ),
              if (child != null) child,
            ],
          ),
        ),
      );
    },
  );
}

abstract final class AppTheme {
  // Teal / turquoise ceramic-inspired palette (client reference).
  /// Light-mode page background — overscroll / fallback (#008B94).
  static const Color bg = Color(0xFF008B94);

  static const String lightPageBackgroundAsset =
      'assets/branding/light_background.png';
  static const String darkPageBackgroundAsset =
      'assets/branding/dark_mode_bg.png';

  /// Light-mode teal glaze gradient (legacy fallback).
  static const LinearGradient lightBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF008B94),
      Color(0xFF007A85),
      Color(0xFF006068),
      Color(0xFF004D56),
    ],
    stops: [0.0, 0.35, 0.68, 1.0],
  );
  static const Color surface = Color(0xFFFFFFFF);
  /// Primary brand — mid peacock teal.
  static const Color accent = Color(0xFF007B8A);
  /// Highlights, links on dark — bright aquamarine cyan.
  static const Color accentHover = Color(0xFF00B4D8);
  /// Deep navy-teal — pressed states, dark accents.
  static const Color accentDark = Color(0xFF004D56);
  /// Soft glaze tint for chips, nav indicator, fills.
  static const Color accentSoft = Color(0xFFC8EBF0);
  /// Sea-glass green (secondary hue in the ceramic mix).
  static const Color accentJade = Color(0xFF0F9488);
  static const Color accentJadeSoft = Color(0xFFCCFBF1);
  /// Pool / sky blue (tertiary hue).
  static const Color accentSky = Color(0xFF0EA5E9);
  static const Color accentSkySoft = Color(0xFFE0F2FE);

  /// Ceramic-inspired handcrafted tonal ramp.
  /// Designed to mimic glazed Moroccan/Spanish ceramic depth.
  static const List<Color> ceramicGradient = [
    Color(0xFF032B38),
    Color(0xFF053847),
    Color(0xFF064354),
    Color(0xFF075267),
    Color(0xFF08607A),
    Color(0xFF0A6D89),
    Color(0xFF0B7894),
    Color(0xFF0C809C),
    Color(0xFF0A7A96),
    Color(0xFF086A87),
    Color(0xFF075A73),
    Color(0xFF054B61),
    Color(0xFF043F53),
    Color(0xFF033748),
    Color(0xFF044258),
    Color(0xFF06556D),
    Color(0xFF0A6C86),
    Color(0xFF0E819A),
    Color(0xFF1294AA),
    Color(0xFF17A6B8),
    Color(0xFF1BB3C2),
    Color(0xFF20BAC7),
    Color(0xFF1DAFBD),
    Color(0xFF169DAF),
    Color(0xFF118A9F),
    Color(0xFF0C758C),
    Color(0xFF085E74),
    Color(0xFF05495D),
    Color(0xFF043B4D),
    Color(0xFF054257),
    Color(0xFF07566E),
    Color(0xFF0A6E89),
    Color(0xFF1085A1),
    Color(0xFF179BB4),
    Color(0xFF1CB0C3),
    Color(0xFF21C2D0),
    Color(0xFF24CBD6),
    Color(0xFF1FBFD0),
    Color(0xFF18A8BC),
    Color(0xFF1290A6),
    Color(0xFF0D788F),
    Color(0xFF096176),
    Color(0xFF064B5E),
    Color(0xFF043949),
    Color(0xFF032C39),
    Color(0xFF043847),
    Color(0xFF064C60),
    Color(0xFF0A6680),
    Color(0xFF1087A3),
    Color(0xFF16A7BF),
  ];

  static const List<double> _ceramicGradientStops = [
    0.0, 0.02, 0.04, 0.06, 0.08, 0.10, 0.12, 0.14, 0.16, 0.18,
    0.20, 0.22, 0.24, 0.26, 0.28, 0.30, 0.32, 0.34, 0.36, 0.38,
    0.40, 0.42, 0.44, 0.46, 0.48, 0.50, 0.52, 0.54, 0.56, 0.58,
    0.60, 0.62, 0.64, 0.66, 0.68, 0.70, 0.72, 0.74, 0.76, 0.78,
    0.80, 0.82, 0.84, 0.86, 0.88, 0.90, 0.92, 0.94, 0.97, 1.0,
  ];

  static const LinearGradient brandLinearTlBr = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: ceramicGradient,
    stops: _ceramicGradientStops,
  );

  /// Hero / card radial: turquoise bloom → mid glaze → deep navy pocket.
  static const RadialGradient ceramicHeroRadial = RadialGradient(
    center: Alignment(-0.38, -0.48),
    radius: 1.22,
    colors: [
      Color(0xFF24CBD6),
      Color(0xFF0A6C86),
      Color(0xFF032B38),
    ],
    stops: [0.0, 0.48, 1.0],
  );

  /// Same stops as [ceramicGradient]; kept for call sites that iterate samples.
  static const List<Color> brandGradient = ceramicGradient;

  /// Mid ramp sample for sliders, spinners, and single-color paints.
  static Color get brandSampleMid =>
      ceramicGradient[ceramicGradient.length ~/ 2];

  static Widget brandGradientIcon(IconData icon, {double size = 24}) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => brandLinearTlBr.createShader(bounds),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  /// Yellow → orange ramp for mixer waveforms, EQ bars, and seek tracks.
  static const List<Color> mixerLineGradient = [
    Color(0xFFFFD54F),
    Color(0xFFFF9800),
  ];

  static const LinearGradient mixerLinearLr = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: mixerLineGradient,
    stops: [0.0, 1.0],
  );

  static Color mixerLineColorAt(double t) {
    return Color.lerp(
      mixerLineGradient[0],
      mixerLineGradient[1],
      t.clamp(0.0, 1.0),
    )!;
  }

  static Widget mixerGradientIcon(IconData icon, {double size = 24}) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (Rect bounds) => mixerLinearLr.createShader(bounds),
      child: Icon(icon, size: size, color: Colors.white),
    );
  }

  static const Color danger = Color(0xFFFF4D4F);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textMuted = Color(0xFF8F8F8F);
  static const Color textSecondary = Color(0xFF5F5F5F);
  static const Color border = Color(0xFFC8E3F0);
  static const Color darkBg = Color(0xFF0A2226);
  static const Color darkSurface = Color(0xFF143A40);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFFFFFFF);
  static const Color darkTextMuted = Color(0xFFFFFFFF);
  static const Color darkBorder = Color(0xFF2A555C);

  /// Primary on-screen text for the current brightness (light/dark).
  static Color fgPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextPrimary
          : textPrimary;

  /// Secondary lines (metadata, subtitles).
  static Color fgSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextSecondary
          : textSecondary;

  /// Hints and de-emphasized copy.
  static Color fgMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkTextMuted
          : textMuted;

  static List<BoxShadow> get cardShadow => const [
    BoxShadow(color: Color(0x0F000000), offset: Offset(0, 4), blurRadius: 20),
  ];

  static const double radiusLg = 20;
  static const double radiusMd = 14;

  static ThemeData light() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: surface,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: baseScheme.copyWith(
        primary: accent,
        onPrimary: Colors.white,
        primaryContainer: accentSoft,
        onPrimaryContainer: accentDark,
        secondary: accentJade,
        onSecondary: Colors.white,
        secondaryContainer: accentJadeSoft,
        onSecondaryContainer: const Color(0xFF064E3B),
        tertiary: accentSky,
        onTertiary: Colors.white,
        tertiaryContainer: accentSkySoft,
        onTertiaryContainer: const Color(0xFF0C4A6E),
        surfaceContainerLowest: bg,
        surfaceContainerLow: bg,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        base.textTheme,
      ).apply(bodyColor: textPrimary, displayColor: textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        foregroundColor: textPrimary,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shadowColor: const Color(0x0F000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandSampleMid, width: 1.2),
        ),
        labelStyle: const TextStyle(
          color: textMuted,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        iconColor: textMuted,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: accent.withValues(alpha: 0.2),
        side: const BorderSide(color: Color(0x00FFFFFF)),
        labelStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: bg,
        indicatorColor: accentSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
            color: selected ? accentJade : textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentJade);
          }
          return const IconThemeData(color: textMuted);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentJade,
        inactiveTrackColor: border,
        thumbColor: brandSampleMid,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brandSampleMid,
        linearTrackColor: border,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentDark;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.32);
          }
          return border;
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: textMuted,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.22);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.12);
            }
            return Colors.transparent;
          }),
          backgroundBuilder: _ceramicFilledButtonBackground,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: textMuted,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: BorderSide.none,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ).copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.18);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return Colors.transparent;
          }),
          backgroundBuilder: _ceramicOutlinedButtonBackground,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );
  }

  static ThemeData dark() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: darkSurface,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: baseScheme.copyWith(
        primary: accentSoft,
        onPrimary: accentDark,
        primaryContainer: accentDark,
        onPrimaryContainer: accentSoft,
        secondary: accentJade,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFF134E4A),
        onSecondaryContainer: accentJadeSoft,
        tertiary: accentSky,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFF075985),
        onTertiaryContainer: accentSkySoft,
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextPrimary,
        onBackground: darkTextPrimary,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        base.textTheme,
      ).apply(bodyColor: darkTextPrimary, displayColor: darkTextPrimary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        foregroundColor: darkTextPrimary,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkTextPrimary,
          letterSpacing: -0.1,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brandSampleMid, width: 1.2),
        ),
        labelStyle: const TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(color: darkTextPrimary),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        iconColor: darkTextPrimary,
        textColor: darkTextPrimary,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: accent.withValues(alpha: 0.24),
        side: const BorderSide(color: darkBorder),
        labelStyle: const TextStyle(
          color: darkTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: darkSurface,
        indicatorColor: accent.withValues(alpha: 0.28),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12.5,
            color: darkTextPrimary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentHover);
          }
          return const IconThemeData(color: darkTextPrimary);
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentSky,
        inactiveTrackColor: darkBorder,
        thumbColor: brandSampleMid,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: brandSampleMid,
        linearTrackColor: darkBorder,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return darkTextPrimary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.45);
          }
          return darkBorder;
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkTextPrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: darkTextPrimary.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ).copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.22);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.12);
            }
            return Colors.transparent;
          }),
          backgroundBuilder: _ceramicFilledButtonBackground,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: darkTextPrimary.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: BorderSide.none,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ).copyWith(
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return Colors.white.withValues(alpha: 0.18);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return Colors.white.withValues(alpha: 0.1);
            }
            return Colors.transparent;
          }),
          backgroundBuilder: _ceramicOutlinedButtonBackground,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkSurface,
        contentTextStyle: const TextStyle(color: darkTextPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      scaffoldBackgroundColor: Colors.transparent,
    );
  }
}
