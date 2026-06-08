import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'ceramic_texture.dart';
import 'home_ceramic_card.dart';

/// Full-screen glaze for login / signup / forgot / account only.
/// Other screens use [AppCeramicPageBackdrop] image backgrounds.
class AppTexturedPageBackdrop extends StatelessWidget {
  const AppTexturedPageBackdrop({super.key});

  /// Scaffold overscroll / safe-area fill — must match [ _authBaseGradient ] top tone.
  static const Color scaffoldBackground = Color(0xFF1294AA);

  /// Brighter vertical ramp — avoids navy-black bands at screen edges.
  static const LinearGradient authBaseGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1294AA),
      Color(0xFF17A6B8),
      Color(0xFF1BB3C2),
      Color(0xFF1294AA),
      Color(0xFF0E819A),
    ],
    stops: [0.0, 0.28, 0.5, 0.72, 1.0],
  );

  /// Washes dark photo edges at top / bottom while keeping center texture.
  static const LinearGradient photoEdgeSoftener = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1BB3C2),
      Color(0x001BB3C2),
      Color(0x001BB3C2),
      Color(0xFF1BB3C2),
    ],
    stops: [0.0, 0.2, 0.8, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: authBaseGradient),
            ),
          ),
          const Positioned.fill(
            child: CeramicFilmGrain(
              photoOpacity: 0.4,
              softenVerticalEdges: true,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: photoEdgeSoftener),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card-sized glaze matching [AppTexturedPageBackdrop] (login / signup).
class AppAuthGlazedCard extends StatelessWidget {
  const AppAuthGlazedCard({
    super.key,
    required this.child,
    this.radius = 20,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandSampleMid.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: CeramicHeroFill(
          gradient: AppTheme.ceramicHeroRadial,
          borderRadius: r,
          photoOpacity: 0.42,
          child: child,
        ),
      ),
    );
  }
}

/// Flat page backdrop — light/dark branded image backgrounds.
class AppCeramicPageBackdrop extends StatelessWidget {
  const AppCeramicPageBackdrop({super.key});

  static Color pageBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkBg
          : AppTheme.bg;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = isDark
        ? AppTheme.darkPageBackgroundAsset
        : AppTheme.lightPageBackgroundAsset;

    return Image.asset(
      asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => ColoredBox(color: pageBackground(context)),
    );
  }
}

/// Login, signup, forgot password, and My Account — shared softened glaze backdrop.
class AppGlazedAuthScaffold extends StatelessWidget {
  const AppGlazedAuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCeramicScaffold(
      texturedBackdrop: true,
      automaticallyImplyLeading: false,
      body: SafeArea(child: child),
    );
  }
}

/// Scaffold with ceramic page backdrop and themed app bar.
class AppCeramicScaffold extends StatelessWidget {
  const AppCeramicScaffold({
    super.key,
    this.title,
    this.appBar,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.automaticallyImplyLeading = true,
    this.texturedBackdrop = false,
    required this.body,
  });

  final String? title;
  final PreferredSizeWidget? appBar;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool automaticallyImplyLeading;
  /// When true, full-screen glaze behind [body]; when false, global page image shows through.
  final bool texturedBackdrop;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = AppTheme.fgPrimary(context);

    PreferredSizeWidget? bar = appBar;
    if (bar == null && title != null) {
      bar = AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: centerTitle,
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        title: Text(
          title!,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: fg,
              ),
        ),
        actions: actions,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: texturedBackdrop
          ? SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent)
          : (isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark),
      child: Scaffold(
        backgroundColor: texturedBackdrop
            ? AppTexturedPageBackdrop.scaffoldBackground
            : Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: bar,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (texturedBackdrop) const AppTexturedPageBackdrop(),
            body,
          ],
        ),
      ),
    );
  }
}

/// Section heading on the page background (outside ceramic cards).
class AppCeramicPageHeading extends StatelessWidget {
  const AppCeramicPageHeading({
    super.key,
    required this.title,
    this.subtitle,
    /// White copy for use on glazed brand ramps (login / signup).
    this.lightOnCeramic = false,
  });

  final String title;
  final String? subtitle;
  final bool lightOnCeramic;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        lightOnCeramic ? Colors.white : AppTheme.fgPrimary(context);
    final subColor =
        lightOnCeramic ? Colors.white70 : AppTheme.fgMuted(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: subColor,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bold white tappable labels on glazed auth pages.
abstract final class AuthGlazeLinkStyle {
  static const TextStyle standard = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 14,
  );

  static const TextStyle compact = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w700,
    fontSize: 13,
  );
}

/// White inset field for use inside glazed cards.
class AppCeramicInsetField extends StatelessWidget {
  const AppCeramicInsetField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.showVisibilityIcon = false,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool showVisibilityIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: SessionCeramicPanel.mutedStyle),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.9)),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.brandSampleMid, width: 1.2),
            ),
            suffixIcon: showVisibilityIcon
                ? Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: AppTheme.textMuted,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Menu row for ceramic panels (profile, settings).
class AppCeramicMenuTile extends StatelessWidget {
  const AppCeramicMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: Colors.white.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: SessionCeramicPanel.bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: SessionCeramicPanel.mutedStyle),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.55),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

Widget appCeramicDivider() => Divider(
      height: 1,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.14),
    );
