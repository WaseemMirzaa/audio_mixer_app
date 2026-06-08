import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_surface_card.dart';
import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/primary_button.dart';

class DeleteAccountScreen extends ConsumerWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: AppContent(
        child: ListView(
          children: [
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FaIcon(FontAwesomeIcons.trashCan, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Cloud audiobook sessions, background profile metadata, and profile data will be deleted. '
                    'Subscriptions are billed via the store — cancel separately if needed.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            PrimaryButton(
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
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
