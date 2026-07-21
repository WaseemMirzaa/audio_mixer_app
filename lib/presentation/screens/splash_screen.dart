import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_meta.dart';
import '../../data/local/prefs_keys.dart';
import '../providers/providers.dart';
import '../widgets/app_logo.dart';
import '../widgets/sa_glass.dart';
import '../../services/incoming_shared_audio.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.debugPreview});

  /// When true, skips auto-navigation (opened from Profile / Dev tools).
  final bool? debugPreview;

  bool get isDebugPreview => debugPreview ?? false;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isDebugPreview) return;
      _run();
    });
  }

  Future<void> _run() async {
    try {
      await ref.read(bootstrapProvider.future);
    } catch (e) {
      // A bootstrap failure (e.g. RevenueCat / Firebase timeout) must not
      // block navigation. Log and continue with degraded state.
      debugPrint('[Splash] bootstrap error (continuing): $e');
    }

    if (!mounted) return;

    final prefs = ref.read(prefsProvider);

    String? destination;
    try {
      final user = await ref.read(authRepositoryProvider).currentUser();
      if (!mounted) return;
      final onboardingDone = prefs.getBool(PrefsKeys.onboardingDone) ?? false;
      if (!onboardingDone) {
        destination = '/onboarding';
      } else if (ref.read(pendingSharedForegroundProvider) != null) {
        // Shared audio — guests can start a session; saving still requires sign-in.
        destination = '/picker';
      } else if (user == null) {
        destination = '/get-started';
      } else {
        destination = '/home';
      }
    } catch (e) {
      debugPrint('[Splash] auth check error: $e');
      destination = '/home'; // fall back to home; auth guards will redirect
    }

    if (!mounted) return;
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SaPlayerBackground(),
            SafeArea(
              child: Column(
                children: [
                  if (widget.isDebugPreview)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Debug preview — auto-nav off',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: AppAuthLogo(logoSize: 1000),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Play Audiobooks with\nSmart Background Audio',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.35,
                                ),
                          ),
                          if (!widget.isDebugPreview) ...[
                            const SizedBox(height: 28),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(glass.accent),
                                backgroundColor: const Color(0x44FFFFFF),
                              ),
                            ),
                          ],
                          const SizedBox(height: 38),
                          Text(
                            'v${AppMeta.versionLabel}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.isDebugPreview)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: OutlinedButton(
                        onPressed: () => _run(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Text('Run splash navigation'),
                      ),
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
