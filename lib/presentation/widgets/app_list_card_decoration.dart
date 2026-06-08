import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared list-card palette — light ocean teal gradient, dark glass teal.
abstract final class AppListCardStyle {
  static const Color lightContainer = Color(0xFF0A3D4D);
  static const Color lightIconBg = Color(0xFF1A5F72);

  static const LinearGradient lightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lightContainer, lightIconBg],
    stops: [0.0, 1.0],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0E3A52),
      Color(0xFF0A2E45),
      Color(0xFF08263A),
    ],
    stops: [0.0, 0.52, 1.0],
  );

  static const Color darkGlow = Color(0xFF0A2E45);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static LinearGradient gradient(BuildContext context) =>
      isDark(context) ? darkGradient : lightGradient;

  static Color glowTone(BuildContext context) =>
      isDark(context) ? darkGlow : lightContainer;

  static Color pageFill(BuildContext context) =>
      isDark(context) ? const Color(0xFF000B18) : AppTheme.bg;
}

/// List tiles that blend into the page — gradient fill + soft spread glow.
abstract final class AppListCardDecoration {
  static BoxDecoration merge({
    required BuildContext context,
    Color? pageFill,
    double radius = 16,
  }) {
    final glow = AppListCardStyle.glowTone(context);
    final page = pageFill ?? AppListCardStyle.pageFill(context);

    return BoxDecoration(
      gradient: AppListCardStyle.gradient(context),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: glow.withValues(alpha: 0.4),
          blurRadius: 36,
          spreadRadius: 10,
        ),
        BoxShadow(
          color: page.withValues(alpha: 0.4),
          blurRadius: 28,
          spreadRadius: -4,
        ),
      ],
    );
  }
}
