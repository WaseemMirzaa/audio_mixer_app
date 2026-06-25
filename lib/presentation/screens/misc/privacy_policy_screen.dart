import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_branding.dart';
import '../../widgets/sa_glass.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Privacy Policy',
        onBack: () => context.pop(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          _Section(
            glass: glass,
            icon: Icons.shield_outlined,
            title: 'Your privacy matters',
            body:
                '${AppBranding.appName} is committed to protecting your personal '
                'information. This policy explains what data we collect, how we use '
                'it, and the choices you have.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.data_usage_rounded,
            title: 'Data we collect',
            body:
                'We collect your email address and display name when you create an '
                'account. Audio files you upload are stored locally on your device '
                'and are not transmitted to our servers unless you opt into cloud '
                'backup. Usage analytics (crash reports, feature events) may be '
                'collected in anonymised form to improve the app.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.lock_outline_rounded,
            title: 'How we use your data',
            body:
                'Your account information is used solely to authenticate you and '
                'personalise your experience. We do not sell, rent, or share your '
                'personal data with third parties for marketing purposes.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.storage_rounded,
            title: 'Data retention',
            body:
                'Your data is retained for as long as your account is active. You '
                'may delete your account at any time from Profile → Account → '
                'Delete account, which permanently removes all associated data '
                'from our systems.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.cookie_outlined,
            title: 'Third-party services',
            body:
                '${AppBranding.appName} uses Firebase for authentication and '
                'optional cloud sync, and RevenueCat for subscription management. '
                'These services have their own privacy policies which we encourage '
                'you to review.',
          ),
          const SizedBox(height: 12),
          _Section(
            glass: glass,
            icon: Icons.mail_outline_rounded,
            title: 'Contact us',
            body:
                'If you have questions about this policy or wish to exercise your '
                'data rights, please contact us at support@${AppBranding.appName.toLowerCase().replaceAll(' ', '')}.app.',
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
