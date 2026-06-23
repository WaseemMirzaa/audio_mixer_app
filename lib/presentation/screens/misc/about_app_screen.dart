import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_branding.dart';
import '../../../core/constants/app_meta.dart';
import '../../widgets/sa_glass.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      splashBackground: true,
      header: SaBackHeader(
        title: 'About App',
        onBack: () => context.pop(),
      ),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            decoration: glass.card(radius: 20),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Image.asset(
                      AppBranding.logoAsset,
                      width: 560,
                      height: 560,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Version ${AppMeta.versionLabel.split('+').first}',
                  style: TextStyle(
                    color: glass.textMeta,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'A multilingual audiobook + audio blending application where users '
                  'can upload and combine audio in any language, with a calming and '
                  'creative experience focused on mindfulness, meditation, and '
                  'universal accessibility.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: glass.textMuted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: glass.card(radius: 18),
            child: Column(
              children: [
                _LinkTile(
                  glass: glass,
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => context.push('/privacy'),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: glass.divider),
                _LinkTile(
                  glass: glass,
                  icon: Icons.gavel_rounded,
                  label: 'Terms of Service',
                  onTap: () => context.push('/terms'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.glass,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final SaGlass glass;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Icon(icon, color: glass.accent, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: glass.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: glass.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
