import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/local/prefs_keys.dart';
import '../../../data/repositories/mock/mock_session_repository.dart';
import '../../../data/repositories/mock/mock_subscription_repository.dart';
import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/primary_button.dart';

class DevToolsScreen extends ConsumerStatefulWidget {
  const DevToolsScreen({super.key});

  @override
  ConsumerState<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends ConsumerState<DevToolsScreen> {
  late bool _syncFail;
  late bool _purchaseFail;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsProvider);
    _syncFail = prefs.getBool(PrefsKeys.simulateSyncFail) ?? false;
    _purchaseFail = prefs.getBool('mock_purchase_fail') ?? false;
  }

  Future<void> _setSyncFail(bool v) async {
    await ref.read(prefsProvider).setBool(PrefsKeys.simulateSyncFail, v);
    ref.invalidate(simulateSyncFailProvider);
    setState(() => _syncFail = v);
  }

  Future<void> _setPurchaseFail(bool v) async {
    await ref.read(prefsProvider).setBool('mock_purchase_fail', v);
    setState(() => _purchaseFail = v);
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dev tools')),
      body: AppContent(
        child: ListView(
          children: [
            AppSurfaceCard(
              child: Text(
                'Debug controls for mock mode behavior.',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 12),
            AppSurfaceCard(
              child: Column(
                children: [
                  if (sub is! MockSubscriptionRepository)
                    const Text(
                      'Dev simulation toggles are available in mock mode.',
                    )
                  else ...[
                    SwitchListTile(
                      title: const Text('Simulate sync failure on save'),
                      value: _syncFail,
                      onChanged: _setSyncFail,
                    ),
                    SwitchListTile(
                      title: const Text('Simulate purchase failure'),
                      value: _purchaseFail,
                      onChanged: _setPurchaseFail,
                    ),
                    const Divider(height: 32),
                    ListTile(
                      title: const Text('Clear sessions'),
                      trailing: const Icon(Icons.delete_sweep_outlined),
                      onTap: () async {
                        final repo = ref.read(sessionRepositoryProvider);
                        if (repo is MockSessionRepository) {
                          await repo.clearAll();
                          ref.invalidate(sessionsProvider);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Reset Pro flag'),
                      onTap: () async {
                        await sub.resetProFlag();
                        ref.invalidate(subscriptionStreamProvider);
                      },
                    ),
                    ListTile(
                      title: const Text('Preview splash screen'),
                      subtitle: const Text('Debug — auto-nav disabled'),
                      trailing: const Icon(Icons.open_in_new_rounded),
                      onTap: () => context.push('/splash?debug=1'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Close',
              outlined: true,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
