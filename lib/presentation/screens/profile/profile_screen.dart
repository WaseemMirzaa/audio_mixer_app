import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/app_user.dart';
import '../../providers/providers.dart';
import '../../widgets/sa_glass.dart';
import '../../widgets/user_avatar.dart';
import '../subscription/paywall_plan_glyphs.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = SaGlass.of(context);
    final auth = ref.watch(authStateProvider).valueOrNull;
    final isGuest = auth?.isGuest == true;
    final sub = ref.watch(subscriptionStreamProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final df = DateFormat.yMMMd();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SaPlayerBackground(),
          SafeArea(
            child: Column(
              children: [
                _ProfileHeader(glass: glass),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      const SizedBox(height: 20),

                      // ── User card ────────────────────────────────────────
                      _ProfileUserCard(
                        glass: glass,
                        user: auth,
                        isGuest: isGuest,
                        isPro: sub?.isPro == true,
                      ),
                      const SizedBox(height: 12),

                      // ── Guest sign-in banner ──────────────────────────────
                      if (isGuest) ...[
                        _GuestSignInBanner(glass: glass),
                        const SizedBox(height: 16),
                      ],

                      // ── Settings ──────────────────────────────────────────
                      _SettingsCard(
                        glass: glass,
                        isGuest: isGuest,
                        themeMode: themeMode,
                        subscriptionSubtitle: sub?.expiryMs != null
                            ? 'Expires ${df.format(DateTime.fromMillisecondsSinceEpoch(sub!.expiryMs!))}'
                            : 'Free tier',
                        onAccount: () => context.push('/account'),
                        onSubscription: () => context.push('/paywall'),
                        onAbout: () => context.push('/about'),
                        onPrivacy: () => context.push('/privacy'),
                        onTerms: () => context.push('/terms'),
                        onExportBackup: () => context.push('/backup'),
                        onImportBackup: () => context.push('/backup'),
                        onReplayOnboarding: () =>
                            context.push('/onboarding?replay=1'),
                        onThemeChanged: (dark) {
                          ref.read(themeModeProvider.notifier).setThemeMode(
                                dark ? ThemeMode.dark : ThemeMode.light,
                              );
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Guest CTA button ──────────────────────────────────
                      if (isGuest) ...[
                        SaPrimaryButton(
                          label: 'Sign In / Create Account',
                          onPressed: () => context.go('/login'),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // ── Log out / Exit guest ──────────────────────────────
                      SaSecondaryButton(
                        label:
                            isGuest ? 'Exit Guest Mode' : 'Log Out',
                        icon: isGuest
                            ? Icons.exit_to_app_rounded
                            : Icons.logout_rounded,
                        onPressed: () async {
                          await ref.read(authRepositoryProvider).signOut();
                          ref.invalidate(sessionsProvider);
                          if (!context.mounted) return;
                          context.go('/login');
                        },
                      ),
                    ],
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

// ── Header ────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.glass});

  final SaGlass glass;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Profile',
        style: TextStyle(
          color: glass.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── User card ─────────────────────────────────────────────────────────────────

class _ProfileUserCard extends StatelessWidget {
  const _ProfileUserCard({
    required this.glass,
    required this.user,
    required this.isGuest,
    required this.isPro,
  });

  final SaGlass glass;
  final AppUser? user;
  final bool isGuest;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glass.card(radius: 20),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          isGuest
              ? Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: glass.catGradients[2],
                    ),
                    borderRadius: BorderRadius.circular(34),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                )
              : UserAvatar(user: user, radius: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGuest ? 'Guest' : (user?.displayName ?? 'John Doe'),
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? 'Browsing as guest'
                      : (user?.email ?? 'demo@app.com'),
                  style: TextStyle(color: glass.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isGuest && isPro) ...[
            const PaywallProGlyph(width: 30),
            const SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF8E8),
                    Color(0xFFF5D88A),
                    Color(0xFFE8B84A),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    color: Color(0xFF1A3D45),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Guest sign-in banner ──────────────────────────────────────────────────────

class _GuestSignInBanner extends StatelessWidget {
  const _GuestSignInBanner({required this.glass});

  final SaGlass glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glass.hero(radius: 16),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: glass.catGradients[0],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: glass.catGradients[0].last.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock your sessions',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Sign in to save mixes, build history, and sync across devices.',
                  style: TextStyle(
                    color: glass.textMuted,
                    fontSize: 12,
                    height: 1.4,
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

// ── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.glass,
    required this.isGuest,
    required this.themeMode,
    required this.subscriptionSubtitle,
    required this.onAccount,
    required this.onSubscription,
    required this.onAbout,
    required this.onPrivacy,
    required this.onTerms,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onReplayOnboarding,
    required this.onThemeChanged,
  });

  final SaGlass glass;
  final bool isGuest;
  final ThemeMode themeMode;
  final String subscriptionSubtitle;
  final VoidCallback onAccount;
  final VoidCallback onSubscription;
  final VoidCallback onAbout;
  final VoidCallback onPrivacy;
  final VoidCallback onTerms;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final VoidCallback onReplayOnboarding;
  final ValueChanged<bool> onThemeChanged;

  Widget _divider() => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: glass.divider,
      );

  @override
  Widget build(BuildContext context) {
    final darkOn = themeMode == ThemeMode.dark;

    return Container(
      decoration: glass.card(radius: 20),
      child: Column(
        children: [
          // Account — signed-in users only
          if (!isGuest) ...[
            _MenuTile(
              glass: glass,
              icon: Icons.person_outline_rounded,
              title: 'Account',
              onTap: onAccount,
            ),
            _divider(),
          ],

          // Theme — always visible
          _ThemeToggleTile(
            glass: glass,
            darkOn: darkOn,
            onChanged: onThemeChanged,
          ),

          // Subscription — signed-in users only
          if (!isGuest) ...[
            _divider(),
            _MenuTile(
              glass: glass,
              icon: Icons.credit_card_outlined,
              title: 'Subscription',
              subtitle: subscriptionSubtitle,
              onTap: onSubscription,
            ),
          ],

          // Always visible
          _divider(),
          _MenuTile(
            glass: glass,
            icon: Icons.info_outline_rounded,
            title: 'About App',
            onTap: onAbout,
          ),
          _divider(),
          _MenuTile(
            glass: glass,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: onPrivacy,
          ),
          _divider(),
          _MenuTile(
            glass: glass,
            icon: Icons.gavel_rounded,
            title: 'Terms of Service',
            onTap: onTerms,
          ),

          // Backup & onboarding — signed-in users only
          if (!isGuest) ...[
            _divider(),
            _MenuTile(
              glass: glass,
              icon: Icons.upload_rounded,
              title: 'Export backup',
              subtitle: 'Save mixed sessions and audio to a backup file',
              onTap: onExportBackup,
            ),
            _divider(),
            _MenuTile(
              glass: glass,
              icon: Icons.download_rounded,
              title: 'Import backup',
              subtitle: 'Restore mixed sessions from a backup file',
              onTap: onImportBackup,
            ),
            _divider(),
            _MenuTile(
              glass: glass,
              icon: Icons.auto_stories_outlined,
              title: 'Replay onboarding',
              subtitle: 'Walk through the intro slides again',
              onTap: onReplayOnboarding,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared tile widgets ───────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.glass,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final SaGlass glass;
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: glass.textMeta,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: glass.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleTile extends StatelessWidget {
  const _ThemeToggleTile({
    required this.glass,
    required this.darkOn,
    required this.onChanged,
  });

  final SaGlass glass;
  final bool darkOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          Icon(Icons.dark_mode_outlined, color: glass.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Dark & Light Mode',
              style: TextStyle(
                color: glass.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(
            value: darkOn,
            activeTrackColor: glass.accent.withValues(alpha: 0.55),
            activeThumbColor: Colors.white,
            inactiveThumbColor: Colors.white.withValues(alpha: 0.85),
            inactiveTrackColor: glass.divider,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
