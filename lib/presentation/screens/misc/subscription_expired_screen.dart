import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/sa_glass.dart';

class SubscriptionExpiredScreen extends StatelessWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Subscription',
        onBack: () => context.pop(),
      ),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Container(
            decoration: glass.hero(radius: 20),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(
                  FontAwesomeIcons.crown,
                  size: 42,
                  color: glass.accent,
                ),
                const SizedBox(height: 14),
                Text(
                  'Premium locked',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Pro entitlement expired. Renew to unlock unlimited '
                  'background profiles, advanced tools, and sync priority.',
                  style: TextStyle(
                    color: glass.textMuted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SaPrimaryButton(
            label: 'Renew subscription',
            onPressed: () => context.push('/paywall'),
          ),
          const SizedBox(height: 10),
          SaSecondaryButton(
            label: 'Continue free',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}
