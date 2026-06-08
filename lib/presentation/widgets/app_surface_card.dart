import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_list_card_decoration.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.onTap,
    /// Session / preset list rows — blends into page background.
    this.listTile = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool listTile;

  @override
  Widget build(BuildContext context) {
    final isDark = AppListCardStyle.isDark(context);
    final card = Container(
      decoration: listTile
          ? AppListCardDecoration.merge(
              context: context,
              radius: radius,
            )
          : BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.surface,
              borderRadius: BorderRadius.circular(radius),
            ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
