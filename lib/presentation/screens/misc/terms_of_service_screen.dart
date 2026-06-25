import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_branding.dart';
import '../../widgets/sa_glass.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Terms of Service',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Section(
            glass: glass,
            icon: Icons.gavel_rounded,
            title: 'Acceptance of terms',
            body:
                'By downloading or using ${AppBranding.appName} you agree to be '
                'bound by these Terms of Service. If you do not agree, please '
                'uninstall the app and discontinue use.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.apps_rounded,
            title: 'Use of the app',
            body:
                '${AppBranding.appName} is licensed to you for personal, '
                'non-commercial use. You may not reverse-engineer, redistribute, '
                'or resell the app or its components. You are responsible for '
                'ensuring that any audio files you upload comply with applicable '
                'copyright laws.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.audio_file_rounded,
            title: 'User content',
            body:
                'You retain ownership of all audio content you upload. By using '
                'the app you confirm that you have the rights to use and mix the '
                'audio files you provide. We are not liable for any copyright '
                'infringement arising from user-uploaded content.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.credit_card_rounded,
            title: 'Subscriptions & billing',
            body:
                'Premium plans are billed through the Apple App Store or Google '
                'Play. Prices and renewal terms are displayed at the time of '
                'purchase. Subscriptions auto-renew unless cancelled at least '
                '24 hours before the end of the current period.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.warning_amber_rounded,
            title: 'Disclaimer of warranties',
            body:
                '${AppBranding.appName} is provided "as is" without warranties '
                'of any kind. We do not guarantee uninterrupted or error-free '
                'operation and are not liable for any loss of data or damages '
                'arising from use of the app.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.update_rounded,
            title: 'Changes to these terms',
            body:
                'We may update these Terms of Service at any time. Continued use '
                'of the app after changes constitutes acceptance of the revised '
                'terms. We will notify users of significant changes via the app '
                'or email.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.mail_outline_rounded,
            title: 'Contact',
            body:
                'For questions about these terms, contact us at '
                'legal@${AppBranding.appName.toLowerCase().replaceAll(' ', '')}.app.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.glass,
    required this.icon,
    required this.title,
    required this.body,
  });

  final SaGlass glass;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glass.card(radius: 18),
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: glass.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    color: glass.textMuted,
                    fontSize: 13.5,
                    height: 1.5,
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
