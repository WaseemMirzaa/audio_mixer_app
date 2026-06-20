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
  /// export.
  Future<File> exportToFile(SessionRepository repo) async {
    final sessions = await repo.listSessions();
    if (sessions.isEmpty) throw const BackupEmpty();

    // Collect each referenced audio file once (filenames are UUIDs → unique).
    final files = <String, Uint8List>{};
    for (final s in sessions) {
      for (final path in [s.foregroundPath, s.backgroundPath]) {
        if (path == null || path.isEmpty) continue;
        final name = p.basename(path);
        if (files.containsKey(name)) continue;
        final f = File(path);
        if (!await f.exists()) continue;
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
    final out = File(p.join(dir.path, 'soundaxis_backup_${_stamp()}.zip'));
    await out.writeAsBytes(zipBytes, flush: true);
    return out;
  }

  /// Restores sessions + audio files from [zipFile]. Returns the number of
  /// sessions imported. Throws [BackupInvalid] if the archive has no manifest.
  Future<int> importFromFile(
    File zipFile,
    SessionRepository repo, {
    String? uid,
  }) async {
    final bytes = await zipFile.readAsBytes();
    final decoded = await compute(_decodeBackupZip, bytes);

    final manifestJson = decoded['manifest'] as String?;
    if (manifestJson == null) {
      throw const BackupInvalid('manifest.json not found');
    }
    final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
    final rawSessions = (manifest['sessions'] as List?) ?? const [];
    if (rawSessions.isEmpty) return 0;

    // Copy audio files into this device's documents/audio folder.
    final docs = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docs.path, _audioDir));
    if (!await audioDir.exists()) await audioDir.create(recursive: true);

    final files = (decoded['files'] as Map).cast<String, Uint8List>();
    for (final entry in files.entries) {
      final dest = File(p.join(audioDir.path, entry.key));
      await dest.writeAsBytes(entry.value, flush: true);
    }

    // Re-point each session at the local audio files and save it.
    String? relocate(String? old) => (old == null || old.isEmpty)
        ? old
        : p.join(audioDir.path, p.basename(old));

    var count = 0;
    for (final raw in rawSessions) {
      final s = MixSession.fromJson(raw as Map<String, dynamic>);
      await repo.upsertSession(s.copyWith(
        foregroundPath: relocate(s.foregroundPath),
        backgroundPath: relocate(s.backgroundPath),
        uid: uid ?? s.uid,
        syncStatus: 'local',
      ));
      count++;
    }
    return count;
  }

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }
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
