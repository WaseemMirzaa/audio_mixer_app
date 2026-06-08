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
        ],
      ),
    );
  }
}
