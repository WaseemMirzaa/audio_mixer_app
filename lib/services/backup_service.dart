import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/models/mix_session.dart';
import '../domain/repositories/session_repository.dart';

/// Exports every saved session — with its complete audio files and all mix
/// settings — into a single portable `.zip`, and restores it on any device.
///
/// Layout of the archive:
/// ```
/// manifest.json          // { formatVersion, exportedAtMs, sessions: [toJson()] }
/// audio/<filename>       // the raw audio file referenced by each session
/// ```
/// On import the audio files are copied into this device's documents/audio
/// folder and each session's foreground/background paths are rewritten to the
/// new local paths, so playback works exactly as on the source device.
class BackupService {
  static const _manifestName = 'manifest.json';
  static const _audioDir = 'audio';
  static const _formatVersion = 1;

  /// Builds the backup archive and writes it to a temp file, returning it for
  /// the caller to share/save. Throws [BackupEmpty] when there is nothing to
  /// export. Returns the file path and the session count via [BackupExportResult].
  Future<BackupExportResult> exportToFile(SessionRepository repo) async {
    final sessions = await repo.listSessions();
    if (sessions.isEmpty) throw const BackupEmpty();

    // Collect each referenced audio file once (filenames are UUIDs → unique).
    final files = <String, Uint8List>{};
    int audioMissing = 0;
    for (final s in sessions) {
      for (final path in [s.foregroundPath, s.backgroundPath]) {
        if (path == null || path.isEmpty) continue;
        final name = p.basename(path);
        if (files.containsKey(name)) continue;
        final f = File(path);
        if (!await f.exists()) {
          audioMissing++;
          continue;
        }
        files[name] = await f.readAsBytes();
      }
    }

    final manifestJson = jsonEncode({
      'app': 'SoundAxis',
      'formatVersion': _formatVersion,
      'exportedAtMs': DateTime.now().millisecondsSinceEpoch,
      'sessionCount': sessions.length,
      'sessions': sessions.map((e) => e.toJson()).toList(),
    });

    // Zip compression runs off the UI isolate to keep the app responsive.
    final zipBytes = await compute(_encodeBackupZip, <String, dynamic>{
      'manifest': manifestJson,
      'files': files,
    });

    final dir = await getTemporaryDirectory();
    final fileName = 'soundaxis_backup_${_stamp()}.zip';
    final out = File(p.join(dir.path, fileName));
    await out.writeAsBytes(zipBytes, flush: true);

    return BackupExportResult(
      file: out,
      sessionCount: sessions.length,
      audioFileCount: files.length,
      audioMissingCount: audioMissing,
    );
  }

  /// Restores sessions + audio files from [zipFile].
  /// Returns a [BackupImportResult] with counts of imported and skipped sessions.
  /// Throws [BackupInvalid] if the archive has no manifest.
  Future<BackupImportResult> importFromFile(
    File zipFile,
    SessionRepository repo, {
    String? uid,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await zipFile.readAsBytes();
    } catch (e) {
      throw BackupInvalid('Could not read backup file: $e');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = await compute(_decodeBackupZip, bytes);
    } catch (e) {
      throw BackupInvalid('Archive is corrupt or unreadable: $e');
    }

    final manifestJson = decoded['manifest'] as String?;
    if (manifestJson == null) {
      throw const BackupInvalid('manifest.json not found in archive');
    }

    final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    } catch (e) {
      throw const BackupInvalid('manifest.json is not valid JSON');
    }

    final rawSessions = (manifest['sessions'] as List?) ?? const [];
    if (rawSessions.isEmpty) return const BackupImportResult(imported: 0, skipped: 0);

    // Copy audio files into this device's documents/audio folder.
    final docs = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docs.path, _audioDir));
    if (!await audioDir.exists()) await audioDir.create(recursive: true);

    final files = (decoded['files'] as Map).cast<String, Uint8List>();
    for (final entry in files.entries) {
      final dest = File(p.join(audioDir.path, entry.key));
      // Don't overwrite existing audio files — they're UUID-named so a match
      // means the exact same file is already present.
      if (!await dest.exists()) {
        await dest.writeAsBytes(entry.value, flush: true);
      }
    }

    // Re-point each session at the local audio files and save it.
    String? relocate(String? old) => (old == null || old.isEmpty)
        ? old
        : p.join(audioDir.path, p.basename(old));

    // Load existing session IDs so we can skip duplicates.
    final existing = await repo.listSessions();
    final existingIds = {for (final s in existing) s.sessionId};

    int imported = 0;
    int skipped = 0;
    for (final raw in rawSessions) {
      final s = MixSession.fromJson(raw as Map<String, dynamic>);
      if (existingIds.contains(s.sessionId)) {
        skipped++;
        continue;
      }
      await repo.upsertSession(s.copyWith(
        foregroundPath: relocate(s.foregroundPath),
        backgroundPath: relocate(s.backgroundPath),
        uid: uid ?? s.uid,
        syncStatus: 'local',
      ));
      imported++;
    }

    return BackupImportResult(imported: imported, skipped: skipped);
  }

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }
}

// ── Result types ──────────────────────────────────────────────────────────────

class BackupExportResult {
  const BackupExportResult({
    required this.file,
    required this.sessionCount,
    required this.audioFileCount,
    required this.audioMissingCount,
  });

  final File file;
  final int sessionCount;
  final int audioFileCount;
  final int audioMissingCount;
}

class BackupImportResult {
  const BackupImportResult({
    required this.imported,
    required this.skipped,
  });

  final int imported;
  final int skipped;
}

// ── compute() workers (top-level so they can run in a background isolate) ──────

/// args: { 'manifest': String, 'files': Map<String, Uint8List> } → zip bytes.
Uint8List _encodeBackupZip(Map<String, dynamic> args) {
  final manifestJson = args['manifest'] as String;
  final files = (args['files'] as Map).cast<String, Uint8List>();

  final archive = Archive();
  files.forEach((name, bytes) {
    archive.addFile(ArchiveFile('audio/$name', bytes.length, bytes));
  });
  final mb = utf8.encode(manifestJson);
  archive.addFile(ArchiveFile('manifest.json', mb.length, mb));

  final out = ZipEncoder().encode(archive);
  return Uint8List.fromList(out);
}

/// zip bytes → { 'manifest': String?, 'files': Map<String, Uint8List> }.
Map<String, dynamic> _decodeBackupZip(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  String? manifestJson;
  final files = <String, Uint8List>{};
  for (final f in archive.files) {
    if (f.name.endsWith('/')) continue; // skip directory entries
    final base = p.basename(f.name);
    if (base == 'manifest.json') {
      manifestJson = utf8.decode(f.content as List<int>);
    } else if (p.split(f.name).contains('audio')) {
      files[base] = Uint8List.fromList(f.content as List<int>);
    }
  }
  return {'manifest': manifestJson, 'files': files};
}

// ── Exceptions ────────────────────────────────────────────────────────────────

/// Thrown by [BackupService.exportToFile] when there are no sessions to export.
class BackupEmpty implements Exception {
  const BackupEmpty();
  @override
  String toString() => 'No sessions to export.';
}

/// Thrown by [BackupService.importFromFile] when the archive is not a valid
/// SoundAxis backup.
class BackupInvalid implements Exception {
  const BackupInvalid(this.message);
  final String message;
  @override
  String toString() => 'Invalid backup: $message';
}
