import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/models/app_user.dart';
import '../../../services/backup_service.dart';
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
    final sub = ref.watch(subscriptionStreamProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
    final df = DateFormat.yMMMd();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SaGlassBackground(isDark: glass.isDark),
          SafeArea(
            child: Column(
              children: [
                _ProfileHeader(glass: glass),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      const SizedBox(height: 20),
                      _ProfileUserCard(
                  glass: glass,
                  user: auth,
                  isPro: sub?.isPro == true,
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  glass: glass,
                  themeMode: themeMode,
                  subscriptionSubtitle: sub?.expiryMs != null
                      ? 'Expires ${df.format(DateTime.fromMillisecondsSinceEpoch(sub!.expiryMs!))}'
                      : 'Free tier',
                  onAccount: () => context.push('/account'),
                  onSubscription: () => context.push('/paywall'),
                  onAbout: () => context.push('/about'),
                  onExportBackup: () => _exportBackup(context, ref),
                  onImportBackup: () => _importBackup(context, ref),
                  onReplayOnboarding: () =>
                      context.push('/onboarding?replay=1'),
                  onThemeChanged: (dark) {
                    ref.read(themeModeProvider.notifier).state =
                        dark ? ThemeMode.dark : ThemeMode.light;
                  },
                ),
                const SizedBox(height: 16),
                      SaSecondaryButton(
                        label: 'Log Out',
                        icon: Icons.logout_rounded,
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

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(sessionRepositoryProvider);
    final nav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BusyDialog('Preparing backup…'),
    );
    File file;
    try {
      file = await BackupService().exportToFile(repo);
    } on BackupEmpty {
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('No saved sessions to export yet.')),
      );
      return;
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
      return;
    }
    nav.pop();
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      subject: 'SoundAxis backup',
      text: 'SoundAxis sessions backup',
    );
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(sessionRepositoryProvider);
    final uid = ref.read(authStateProvider).valueOrNull?.uid;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not read the selected file.')),
      );
      return;
    }
    if (!context.mounted) return;

    final nav = Navigator.of(context, rootNavigator: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BusyDialog('Importing backup…'),
    );
    try {
      final n = await BackupService().importFromFile(File(path), repo, uid: uid);
      ref.invalidate(sessionsProvider);
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Imported $n session${n == 1 ? '' : 's'}.')),
      );
    } on BackupInvalid catch (e) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Import failed: ${e.message}')),
      );
    } catch (e) {
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }
}

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

class _ProfileUserCard extends StatelessWidget {
  const _ProfileUserCard({
    required this.glass,
    required this.user,
    required this.isPro,
  });

  final SaGlass glass;
  final AppUser? user;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glass.card(radius: 20),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          UserAvatar(user: user, radius: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'John Doe',
                  style: TextStyle(
                    color: glass.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? 'demo@app.com',
                  style: TextStyle(color: glass.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (isPro) ...[
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.glass,
    required this.themeMode,
    required this.subscriptionSubtitle,
    required this.onAccount,
    required this.onSubscription,
    required this.onAbout,
    required this.onExportBackup,
    required this.onImportBackup,
    required this.onReplayOnboarding,
    required this.onThemeChanged,
  });

  final SaGlass glass;
  final ThemeMode themeMode;
  final String subscriptionSubtitle;
  final VoidCallback onAccount;
  final VoidCallback onSubscription;
  final VoidCallback onAbout;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
  final VoidCallback onReplayOnboarding;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final darkOn = themeMode == ThemeMode.dark;

    return Container(
      decoration: glass.card(radius: 20),
      child: Column(
        children: [
          _MenuTile(
            glass: glass,
            icon: Icons.person_outline_rounded,
            title: 'Account',
            onTap: onAccount,
          ),
          _divider(glass),
          _ThemeToggleTile(
            glass: glass,
            darkOn: darkOn,
            onChanged: onThemeChanged,
          ),
          _divider(glass),
          _MenuTile(
            glass: glass,
            icon: Icons.credit_card_outlined,
            title: 'Subscription',
            subtitle: subscriptionSubtitle,
            onTap: onSubscription,
          ),
          _divider(glass),
          _MenuTile(
            glass: glass,
            icon: Icons.info_outline_rounded,
            title: 'About App',
            onTap: onAbout,
          ),
          _divider(glass),
          _MenuTile(
            glass: glass,
            icon: Icons.upload_rounded,
            title: 'Export backup',
            subtitle: 'Save mixed sessions and audio to a backup file',
            onTap: onExportBackup,
          ),
          _divider(glass),
          _MenuTile(
            glass: glass,
            icon: Icons.download_rounded,
            title: 'Import backup',
            subtitle: 'Restore mixed sessions from a backup file',
            onTap: onImportBackup,
          ),
          _divider(glass),
          _MenuTile(
            glass: glass,
            icon: Icons.auto_stories_outlined,
            title: 'Replay onboarding',
            subtitle: 'Walk through the intro slides again',
            onTap: onReplayOnboarding,
          ),
        ],
      ),
    );
  }

  Widget _divider(SaGlass glass) => Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: glass.divider,
      );
}

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

/// Small modal shown while a backup is being created or restored.
class _BusyDialog extends StatelessWidget {
  const _BusyDialog(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6),
            ),
            const SizedBox(width: 18),
            Flexible(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
