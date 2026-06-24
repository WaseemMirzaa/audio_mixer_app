import 'dart:convert';
import 'dart:io';

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
  static const _audioDir = 'audio';
  static const _formatVersion = 1;
  static const _maxZipBytes = 512 * 1024 * 1024; // 512 MB

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
        final name = audioBasename(path);
        if (name.isEmpty || files.containsKey(name)) continue;
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
      // Store basename-only paths so Android ↔ iOS imports stay portable.
      'sessions': sessions.map(portableSessionJson).toList(),
    });

    // Zip compression runs off the UI isolate to keep the app responsive.
    final zipBytes = await compute(_encodeBackupZip, <String, dynamic>{
      'manifest': manifestJson,
      'files': files,
    });

    // Save to app Documents so the file persists across reboots.
    // On iOS this folder is accessible via the Files app; on Android it lives
    // in internal app storage but is shared out via the share sheet below.
    final docs = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(docs.path, 'backups'));
    if (!await backupsDir.exists()) await backupsDir.create(recursive: true);
    final fileName = 'soundaxis_backup_${_stamp()}.zip';
    final out = File(p.join(backupsDir.path, fileName));
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
    if (!await zipFile.exists()) {
      throw const BackupInvalid('Backup file was not found');
    }

    final length = await zipFile.length();
    if (length == 0) {
      throw const BackupInvalid('File is empty');
    }
    if (length > _maxZipBytes) {
      throw const BackupInvalid('Backup file is too large');
    }

    final Uint8List bytes;
    try {
      bytes = await zipFile.readAsBytes();
    } catch (e) {
      throw BackupInvalid('Could not read backup file: $e');
    }

    if (!isZipBytes(bytes)) {
      throw const BackupInvalid('File is not a valid ZIP archive');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = await compute(_decodeBackupZip, bytes);
    } catch (e) {
      throw BackupInvalid('Archive is corrupt or unreadable: $e');
    }

    final manifestJson = decoded['manifest'] as String?;
    if (manifestJson == null || manifestJson.trim().isEmpty) {
      throw const BackupInvalid('manifest.json not found in archive');
    }

    final Map<String, dynamic> manifest;
    try {
      final parsed = jsonDecode(manifestJson);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('manifest root must be an object');
      }
      manifest = parsed;
    } catch (e) {
      throw const BackupInvalid('manifest.json is not valid JSON');
    }

    _validateManifest(manifest);

    final rawSessions = manifest['sessions'];
    if (rawSessions is! List || rawSessions.isEmpty) {
      return const BackupImportResult(imported: 0, skipped: 0);
    }

    final filesRaw = decoded['files'];
    if (filesRaw is! Map) {
      throw const BackupInvalid('Archive audio entries are missing or invalid');
    }
    final files = Map<String, Uint8List>.from(filesRaw.cast<String, Uint8List>());

    // Copy audio files into this device's documents/audio folder.
    final docs = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docs.path, _audioDir));
    if (!await audioDir.exists()) await audioDir.create(recursive: true);

    for (final entry in files.entries) {
      final name = audioBasename(entry.key);
      if (name.isEmpty) continue;
      final dest = File(p.join(audioDir.path, name));
      // Don't overwrite existing audio files — they're UUID-named so a match
      // means the exact same file is already present.
      if (!await dest.exists()) {
        try {
          await dest.writeAsBytes(entry.value, flush: true);
        } catch (e) {
          throw BackupInvalid('Could not restore audio file "$name": $e');
        }
      }
    }

    String? relocate(String? old) {
      if (old == null || old.isEmpty) return old;
      final name = audioBasename(old);
      if (name.isEmpty) return old;
      return p.join(audioDir.path, name);
    }

    // Load existing session IDs so we can skip duplicates.
    final existing = await repo.listSessions();
    final existingIds = {for (final s in existing) s.sessionId};

    int imported = 0;
    int skipped = 0;
    for (final raw in rawSessions) {
      if (raw is! Map<String, dynamic>) {
        skipped++;
        continue;
      }

      MixSession s;
      try {
        s = MixSession.fromJson(raw);
      } catch (_) {
        skipped++;
        continue;
      }

      if (existingIds.contains(s.sessionId)) {
        skipped++;
        continue;
      }

      final fgPath = relocate(s.foregroundPath);
      final bgPath = relocate(s.backgroundPath);
      if (!await _audioExists(fgPath) || !await _audioExists(bgPath)) {
        skipped++;
        continue;
      }

      try {
        await repo.upsertSession(s.copyWith(
          foregroundPath: fgPath,
          backgroundPath: bgPath,
          uid: uid ?? s.uid,
          syncStatus: 'local',
        ));
        imported++;
      } catch (_) {
        skipped++;
      }
    }

    return BackupImportResult(imported: imported, skipped: skipped);
  }

  static void _validateManifest(Map<String, dynamic> manifest) {
    final app = manifest['app'];
    if (app != null && app is String && app != 'SoundAxis') {
      throw const BackupInvalid('This backup was not created by Sound Axis');
    }

    final version = manifest['formatVersion'];
    if (version != null && version is num && version > _formatVersion) {
      throw const BackupInvalid(
        'This backup requires a newer version of Sound Axis',
      );
    }

    final sessions = manifest['sessions'];
    if (sessions != null && sessions is! List) {
      throw const BackupInvalid('manifest.json has an invalid sessions list');
    }
  }

  static Future<bool> _audioExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }

  static String _stamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}';
  }
}

// ── Portable path helpers (Android ↔ iOS) ─────────────────────────────────────

/// Normalizes any stored path to the audio filename used inside the archive.
@visibleForTesting
String audioBasename(String path) {
  final normalized = path.replaceAll('\\', '/').trim();
  if (normalized.isEmpty) return '';
  final parts = normalized.split('/').where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '';
  return parts.last;
}

@visibleForTesting
Map<String, dynamic> portableSessionJson(MixSession session) {
  final json = session.toJson();
  final fg = json['foregroundPath'] as String?;
  final bg = json['backgroundPath'] as String?;
  if (fg != null && fg.isNotEmpty) {
    json['foregroundPath'] = audioBasename(fg);
  }
  if (bg != null && bg.isNotEmpty) {
    json['backgroundPath'] = audioBasename(bg);
  }
  return json;
}

@visibleForTesting
bool isZipBytes(Uint8List bytes) {
  if (bytes.length < 4) return false;
  // ZIP local file header or empty archive EOCD.
  final isLocalHeader = bytes[0] == 0x50 && bytes[1] == 0x4B;
  return isLocalHeader &&
      (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
      (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
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
  if (out.isEmpty) {
    throw const FormatException('Could not encode backup archive');
  }
  return Uint8List.fromList(out);
}

/// zip bytes → { 'manifest': String?, 'files': Map<String, Uint8List> }.
Map<String, dynamic> _decodeBackupZip(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (e) {
    throw FormatException('ZIP decode failed: $e');
  }

  if (archive.files.isEmpty) {
    throw const FormatException('ZIP archive is empty');
  }

  String? manifestJson;
  final files = <String, Uint8List>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;

    final normalized = _normalizeZipEntryPath(f.name);
    if (normalized.contains('..')) {
      throw const FormatException('ZIP contains unsafe file paths');
    }

    final base = p.basename(normalized);
    if (base.isEmpty) continue;

    final content = f.content;
    Uint8List fileBytes;
    try {
      fileBytes = Uint8List.fromList(content);
    } catch (_) {
      continue;
    }

    if (base == 'manifest.json' ||
        normalized == 'manifest.json' ||
        normalized.endsWith('/manifest.json')) {
      try {
        manifestJson = utf8.decode(fileBytes);
      } catch (_) {
        throw const FormatException('manifest.json is not valid UTF-8');
      }
      continue;
    }

    if (_isAudioEntry(normalized)) {
      files[base] = fileBytes;
    }
  }

  return {'manifest': manifestJson, 'files': files};
}

String _normalizeZipEntryPath(String raw) {
  return raw.replaceAll('\\', '/').replaceAll(RegExp(r'^\.?/+'), '');
}

bool _isAudioEntry(String normalizedPath) {
  final segments =
      normalizedPath.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return false;
  if (segments.contains('audio')) return true;
  // Accept root-level audio files for archives created by other tools.
  return segments.length == 1 && _looksLikeAudioFile(segments.last);
}

bool _looksLikeAudioFile(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.mp3') ||
      lower.endsWith('.m4a') ||
      lower.endsWith('.aac') ||
      lower.endsWith('.wav') ||
      lower.endsWith('.flac') ||
      lower.endsWith('.ogg') ||
      lower.endsWith('.opus') ||
      lower.endsWith('.caf');
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
