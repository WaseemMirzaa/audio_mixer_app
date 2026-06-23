import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../widgets/sa_glass.dart';

class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = SaGlass.of(context);
    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Delete account',
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FaIcon(FontAwesomeIcons.trashCan, size: 40, color: glass.accent),
                const SizedBox(height: 14),
                Text(
                  'This is permanent',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cloud audiobook sessions, background profile metadata, and profile data will be deleted. '
                  'Subscriptions are billed via the store — cancel separately if needed.',
                  style: TextStyle(color: glass.textMuted, fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SaPrimaryButton(
            label: 'Permanently delete',
            onPressed: () async {
              await ref.read(authRepositoryProvider).deleteAccount();
              ref.invalidate(sessionsProvider);
              ref.invalidate(presetsProvider);
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
          const SizedBox(height: 10),
          SaSecondaryButton(
            label: 'Cancel',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
