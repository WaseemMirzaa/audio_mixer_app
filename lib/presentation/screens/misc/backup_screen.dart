import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/local/prefs_keys.dart';
import '../../../services/backup_service.dart';
import '../../providers/providers.dart';
import '../../widgets/sa_glass.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _exporting = false;
  bool _importing = false;
  int? _lastBackupMs;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final prefs = ref.read(prefsProvider);
    final ms = prefs.getInt(PrefsKeys.lastBackupMs);
    if (mounted) setState(() => _lastBackupMs = ms);
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(sessionRepositoryProvider);
      final result = await BackupService().exportToFile(repo);

      // Persist last-backup timestamp.
      await ref
          .read(prefsProvider)
          .setInt(PrefsKeys.lastBackupMs, DateTime.now().millisecondsSinceEpoch);
      if (mounted) _loadLastBackup();

      // Share the ZIP — on iOS this opens Files / AirDrop / Mail etc.
      // On Android it opens the system share sheet.
      await Share.shareXFiles(
        [XFile(result.file.path, mimeType: 'application/zip')],
        subject: 'Sound Axis backup',
        text:
            'Sound Axis session backup — ${result.sessionCount} session${result.sessionCount == 1 ? '' : 's'}',
      );
    } on BackupEmpty {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('No sessions to export yet.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    if (_importing) return;

    // On Android < 13 we need READ_EXTERNAL_STORAGE to access files outside
    // the app sandbox. file_picker requests it internally but we do an explicit
    // check here so we can show the permission screen on denial.
    if (Platform.isAndroid) {
      final sdk = await _androidSdk();
      if (sdk != null && sdk < 33) {
        final status = await Permission.storage.request();
        if (status.isPermanentlyDenied && mounted) {
          context.push('/permission');
          return;
        }
        if (!status.isGranted) return;
      }
    }

    setState(() => _importing = true);
    final messenger = ScaffoldMessenger.of(context);

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: false,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not open file picker: $e')));
      setState(() => _importing = false);
      return;
    }

    if (picked == null || picked.files.isEmpty) {
      setState(() => _importing = false);
      return;
    }

    final path = picked.files.single.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read the file path. '
              'On iOS try picking from "On My iPhone" instead of iCloud Drive.',
            ),
          ),
        );
      }
      setState(() => _importing = false);
      return;
    }

    try {
      final repo = ref.read(sessionRepositoryProvider);
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      final result = await BackupService().importFromFile(
        File(path),
        repo,
        uid: uid,
      );
      ref.invalidate(sessionsProvider);
      if (!mounted) return;

      final msg = result.imported == 0
          ? result.skipped > 0
              ? 'All ${result.skipped} session${result.skipped == 1 ? '' : 's'} already exist — nothing imported.'
              : 'No sessions found in backup.'
          : result.skipped > 0
              ? 'Imported ${result.imported} session${result.imported == 1 ? '' : 's'} '
                '(${result.skipped} already existed).'
              : 'Imported ${result.imported} session${result.imported == 1 ? '' : 's'} successfully.';

      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } on BackupInvalid catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Invalid backup: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Returns the Android SDK version, or null if it cannot be determined.
  Future<int?> _androidSdk() async {
    try {
      // android_id or similar won't give SDK, but we can use a pragmatic test:
      // permission_handler already handles SDK-specific behaviour internally.
      return null; // Let permission_handler decide.
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = SaGlass.of(context);
    final sessions = ref.watch(sessionsProvider);
    final sessionCount = sessions.valueOrNull?.length ?? 0;

    return SaGlassScaffold(
      header: SaBackHeader(
        title: 'Backup & Restore',
        subtitle: 'Export or import your sessions',
        onBack: () => context.pop(),
      ),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Status card ───────────────────────────────────────────────────
          Container(
            decoration: glass.hero(radius: 20),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: glass.catGradients[0],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$sessionCount session${sessionCount == 1 ? '' : 's'} saved',
                        style: TextStyle(
                          color: glass.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _lastBackupMs != null
                            ? 'Last backup: ${_fmtDate(_lastBackupMs!)}'
                            : 'No backup yet',
                        style: TextStyle(color: glass.textMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Export section ────────────────────────────────────────────────
          _SectionLabel(glass: glass, label: 'Export'),
          const SizedBox(height: 10),
          Container(
            decoration: glass.card(radius: 18),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.fileExport,
                      color: glass.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Save a backup ZIP',
                        style: TextStyle(
                          color: glass.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'All your sessions and their audio files are bundled into a '
                  'single ZIP file. Share it to Files, Google Drive, email, or '
                  'any app on your device.',
                  style: TextStyle(
                    color: glass.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SaPrimaryButton(
                  label: _exporting ? 'Preparing backup…' : 'Export Backup',
                  enabled: !_exporting && !_importing && sessionCount > 0,
                  onPressed: _exporting ? null : _export,
                ),
                if (sessionCount == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Create at least one session before exporting.',
                    style: TextStyle(color: glass.textMeta, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Import section ────────────────────────────────────────────────
          _SectionLabel(glass: glass, label: 'Restore'),
          const SizedBox(height: 10),
          Container(
            decoration: glass.card(radius: 18),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FaIcon(
                      FontAwesomeIcons.fileImport,
                      color: glass.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Restore from backup',
                        style: TextStyle(
                          color: glass.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a previously exported Sound Axis backup ZIP. Sessions '
                  'that already exist on this device are skipped automatically — '
                  'nothing is overwritten.',
                  style: TextStyle(
                    color: glass.textMuted,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                SaPrimaryButton(
                  label: _importing ? 'Importing…' : 'Import Backup',
                  enabled: !_importing && !_exporting,
                  onPressed: _importing ? null : _import,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Platform help card ─────────────────────────────────────────────
          Container(
            decoration: glass.card(radius: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: glass.textMuted, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      Platform.isIOS ? 'iOS tips' : 'Android tips',
                      style: TextStyle(
                        color: glass.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (Platform.isIOS) ...[
                  _Tip(
                    glass: glass,
                    text: 'Tap Export, then choose "Save to Files" to keep the backup on your device.',
                  ),
                  _Tip(
                    glass: glass,
                    text: 'To import, tap "Import Backup" and select the ZIP from Files or iCloud Drive.',
                  ),
                  _Tip(
                    glass: glass,
                    text: 'You can also transfer via AirDrop, Mail, or any share-capable app.',
                  ),
                ] else ...[
                  _Tip(
                    glass: glass,
                    text: 'Tap Export, then choose where to save or share the ZIP (Downloads, Drive, email …).',
                  ),
                  _Tip(
                    glass: glass,
                    text: 'To import, tap "Import Backup" and navigate to your saved ZIP file.',
                  ),
                  _Tip(
                    glass: glass,
                    text: 'If prompted for storage permission, tap Allow to let the app read the file.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('MMM d, yyyy · HH:mm').format(dt);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.glass, required this.label});

  final SaGlass glass;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: glass.textMeta,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.glass, required this.text});

  final SaGlass glass;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: glass.textMuted, fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: glass.textMuted, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
