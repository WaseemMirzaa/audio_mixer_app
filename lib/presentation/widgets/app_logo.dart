import 'package:flutter/material.dart';

import '../../core/constants/app_branding.dart';
import '../../core/theme/app_theme.dart';

/// App mark + optional wordmark (splash, auth, about).
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.logoSize = 88,
    this.showWordmark = false,
    this.wordmarkColor,
    this.accentWordmarkColor,
    this.tagline,
    this.taglineColor,
  });

  final double logoSize;
  final bool showWordmark;
  final Color? wordmarkColor;
  final Color? accentWordmarkColor;
  final String? tagline;
  final Color? taglineColor;

  @override
  Widget build(BuildContext context) {
    final fg = wordmarkColor ?? AppTheme.fgPrimary(context);
    final accent = accentWordmarkColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppTheme.accentHover
            : AppTheme.accentDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          AppBranding.logoAsset,
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.menu_book_rounded,
            size: logoSize * 0.6,
            color: fg,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 12),
          DefaultTextStyle(
            style: (Theme.of(context).textTheme.titleLarge ??
                    const TextStyle(fontSize: 22))
                .copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: -0.3,
            ),
            child: _AppNameWordmark(accentColor: accent),
          ),
        ],
        if (tagline != null) ...[
          const SizedBox(height: 8),
          Text(
            tagline!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: taglineColor ?? AppTheme.fgSecondary(context),
                  height: 1.35,
                ),
          ),
        ],
      ],
    );
  }
}

class _AppNameWordmark extends StatelessWidget {
  const _AppNameWordmark({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final parts = AppBranding.appName.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) {
      return Text(AppBranding.appName);
    }
    final lead = '${parts.sublist(0, parts.length - 1).join(' ')} ';
    final tail = parts.last;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(lead),
        Text(
          tail,
          style: TextStyle(color: accentColor, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

/// Brand lockup for auth screens on glazed backdrops.
class AppAuthLogo extends StatelessWidget {
  const AppAuthLogo({
    super.key,
    this.logoSize = 88,
    this.showWordmark = false,
  });

  final double logoSize;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return AppBrandLogo(
      logoSize: logoSize,
      showWordmark: showWordmark,
      wordmarkColor: Colors.white,
      accentWordmarkColor: Colors.white,
    );
  }
}
