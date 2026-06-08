import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../widgets/app_layout.dart';
import '../../widgets/app_surface_card.dart';
import '../../widgets/primary_button.dart';

class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(internetAvailableProvider).valueOrNull ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleBg =
        isDark ? AppTheme.darkBorder.withValues(alpha: 0.65) : const Color(0xFFF0F0F0);
    final circleIcon = isDark ? AppTheme.darkTextPrimary : const Color(0xFF8F8F8F);
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: AppContent(
        child: Center(
          child: AppSurfaceCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: circleBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      size: 68,
                      color: circleIcon,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'You are offline',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Some features may be limited.\nYour changes will sync when\nyou’re back online.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.fgSecondary(context),
                        ),
                  ),
                  const SizedBox(height: 26),
                  PrimaryButton(
                    label: online ? 'CONTINUE' : 'RETRY',
                    onPressed: () => context.go('/splash'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
