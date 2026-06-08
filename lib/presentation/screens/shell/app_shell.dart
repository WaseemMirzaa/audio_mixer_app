import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Dark-mode nav active glyph — blue, matching the SoundAxis dark mockup.
  static const accent = Color(0xFF2E9BFF);
  static const navBgDark = Color(0xFF030810);
  static const navTopBorderDark = Color(0xFF12203C);
  // Light (SoundAxis teal) nav — frosted translucent deep teal, cyan active glyph.
  static const navBgLight = Color(0x8C042832); // rgba(4,40,50,.55)
  static const navTopBorderLight = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const lightActive = Color(0xFF83EAF1); // cyan
  static const lightBg = AppTheme.bg;
  static const lightInactive = Color(0xFF6F9CA6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive =
        isDark ? Colors.white.withValues(alpha: 0.38) : lightInactive;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: shell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? navBgDark : navBgLight,
              border: Border(
                top: BorderSide(
                  color: isDark ? navTopBorderDark : navTopBorderLight,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Row(
                  children: [
                _NavItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  selected: shell.currentIndex == 0,
                  inactiveColor: inactive,
                  onTap: () => shell.goBranch(0, initialLocation: true),
                ),
                _NavItem(
                  label: 'Sessions',
                  icon: Icons.history_rounded,
                  selectedIcon: Icons.history_rounded,
                  selected: shell.currentIndex == 1,
                  inactiveColor: inactive,
                  onTap: () => shell.goBranch(1, initialLocation: true),
                ),
                _NavItem(
                  label: 'Profile',
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  selected: shell.currentIndex == 2,
                  inactiveColor: inactive,
                  onTap: () => shell.goBranch(2, initialLocation: true),
                ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.inactiveColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? (isDark ? AppShell.accent : AppShell.lightActive)
        : inactiveColor;
    final glyph = selected ? selectedIcon : icon;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isDark
                          ? [
                              BoxShadow(
                                color: AppShell.accent.withValues(alpha: 0.35),
                                blurRadius: 14,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(glyph, size: 24, color: color),
                  )
                else
                  Icon(glyph, size: 22, color: color),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
