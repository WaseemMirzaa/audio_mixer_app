import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Shared helpers for importing user audio into app-private storage.
abstract final class AudioImportService {
  static const allowedExtensions = {'mp3', 'wav', 'aac', 'm4a'};
  static const maxBytes = 100 * 1024 * 1024;

  /// Normalizes an extension (with or without leading `.`).
  static String? normalizeExt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final e = raw.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
    return allowedExtensions.contains(e) ? e : null;
  }

  static String? extFromPath(String path) =>
      normalizeExt(p.extension(path).replaceFirst('.', ''));

  /// Copies [sourcePath] into `<appDocs>/audio/` with a UUID filename.
  /// Returns the destination path. Idempotent if already under that folder.
  static Future<String> copyToAppStorage({
    required String sourcePath,
    required String ext,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(docsDir.path, 'audio'));
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

    if (sourcePath.startsWith(audioDir.path)) return sourcePath;

    final dest = File(p.join(audioDir.path, '${const Uuid().v4()}.$ext'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }
}

/// Audio shared / opened into the app from another app (Files, share sheet, etc.).
class SharedAudioPayload {
  const SharedAudioPayload({
    required this.path,
    required this.displayName,
  });

  final String path;
  final String displayName;

  factory SharedAudioPayload.fromMap(Map<dynamic, dynamic> m) {
    return SharedAudioPayload(
      path: m['path'] as String,
      displayName: (m['displayName'] as String?)?.trim().isNotEmpty == true
          ? m['displayName'] as String
          : p.basename(m['path'] as String),
    );
  }
}
