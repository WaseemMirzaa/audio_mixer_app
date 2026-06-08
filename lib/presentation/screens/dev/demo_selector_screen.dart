import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/mock/mock_auth_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/primary_button.dart';

class DemoSelectorScreen extends ConsumerWidget {
  const DemoSelectorScreen({super.key});

  Future<void> _apply(WidgetRef ref, String persona) async {
    final auth = ref.read(authRepositoryProvider);
    if (auth is MockAuthRepository) {
      await auth.applyDemoPersona(persona);
    }
    await ref.read(subscriptionRepositoryProvider).refreshEntitlements();
    ref.invalidate(authStateProvider);
    ref.invalidate(subscriptionStreamProvider);
    ref.invalidate(sessionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Demo persona')),
      body: AppContent(
        child: ListView(
          children: [
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pick a persona for instant QA states (mock backend).',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Guest user',
                    onPressed: () async {
                      await _apply(ref, 'guest');
                      if (!context.mounted) return;
                      context.go('/home');
                    },
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Demo user (free)',
                    outlined: true,
                    onPressed: () async {
                      await _apply(ref, 'demo');
                      if (!context.mounted) return;
                      context.go('/home');
                    },
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Pro user',
                    outlined: true,
                    onPressed: () async {
                      await _apply(ref, 'pro');
                      if (!context.mounted) return;
                      context.go('/home');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
