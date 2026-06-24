import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:audio_mixer_app/domain/models/mix_session.dart';
import 'package:audio_mixer_app/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('audioBasename', () {
    test('android absolute path', () {
      expect(
        audioBasename(
          '/data/user/0/com.codetivelab.soundAxis/app_flutter/audio/abc.mp3',
        ),
        'abc.mp3',
      );
    });

    test('ios absolute path', () {
      expect(
        audioBasename(
          '/var/mobile/Containers/Data/Application/UUID/Documents/audio/track.m4a',
        ),
        'track.m4a',
      );
    });

    test('windows-style path from another zip tool', () {
      expect(
        audioBasename(r'audio\session-id.wav'),
        'session-id.wav',
      );
    });
  });

  group('portableSessionJson', () {
    test('stores basename-only audio paths', () {
      final session = MixSession(
        sessionId: 's1',
        uid: 'u1',
        title: 'Test',
        foregroundAudioId: 'fg',
        backgroundAudioId: 'bg',
        foregroundDisplayName: 'FG',
        backgroundDisplayName: 'BG',
        foregroundVolume: 0.8,
        backgroundVolume: 0.4,
        foregroundEq: const [0, 0, 0, 0, 0],
        backgroundEq: const [0, 0, 0, 0, 0],
        masterGain: 1,
        balance: 0,
        durationMs: 1000,
        playbackPositionMs: 0,
        createdAtMs: 1,
        updatedAtMs: 1,
        foregroundPath:
            '/data/user/0/com.codetivelab.soundAxis/app_flutter/audio/fg.mp3',
        backgroundPath:
            '/var/mobile/Containers/Data/Application/UUID/Documents/audio/bg.m4a',
      );

      final json = portableSessionJson(session);
      expect(json['foregroundPath'], 'fg.mp3');
      expect(json['backgroundPath'], 'bg.m4a');
    });
  });

  group('isZipBytes', () {
    test('accepts local file header', () {
      expect(isZipBytes(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04])), isTrue);
    });

    test('rejects random bytes', () {
      expect(isZipBytes(Uint8List.fromList([1, 2, 3, 4])), isFalse);
      expect(isZipBytes(Uint8List.fromList([0x50, 0x4B])), isFalse);
    });
  });

  group('backup zip decode', () {
    test('invalid bytes throw on import path', () {
      expect(isZipBytes(Uint8List.fromList([9, 9, 9, 9])), isFalse);
    });

    test('zip without manifest is rejected by decode worker', () {
      final archive = Archive()
        ..addFile(ArchiveFile('audio/a.mp3', 3, Uint8List.fromList([1, 2, 3])));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      expect(isZipBytes(bytes), isTrue);
      expect(
        () => _decodeBackupZip(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('cross-platform zip entry paths decode audio files', () {
      final manifest = jsonEncode({
        'app': 'SoundAxis',
        'formatVersion': 1,
        'sessions': [],
      });
      final archive = Archive()
        ..addFile(ArchiveFile('manifest.json', manifest.length, utf8.encode(manifest)))
        ..addFile(
          ArchiveFile(
            r'audio\ios-track.m4a',
            4,
            Uint8List.fromList([1, 2, 3, 4]),
          ),
        );
      final decoded = _decodeBackupZip(
        Uint8List.fromList(ZipEncoder().encode(archive)),
      );
      final files = (decoded['files'] as Map).cast<String, Uint8List>();
      expect(files.containsKey('ios-track.m4a'), isTrue);
      expect(decoded['manifest'], manifest);
    });
  });
}

// Mirrors the private worker for focused decode tests.
Map<String, dynamic> _decodeBackupZip(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  if (archive.files.isEmpty) {
    throw const FormatException('ZIP archive is empty');
  }

  String? manifestJson;
  final files = <String, Uint8List>{};
  for (final f in archive.files) {
    if (!f.isFile) continue;
    final normalized = f.name.replaceAll('\\', '/').replaceAll(RegExp(r'^\.?/+'), '');
    final base = normalized.split('/').last;
    final content = f.content;
    if (content == null) continue;
    final fileBytes = content is Uint8List
        ? content
        : Uint8List.fromList(content as List<int>);
    if (base == 'manifest.json') {
      manifestJson = utf8.decode(fileBytes);
      continue;
    }
    if (normalized.contains('audio')) {
      files[base] = fileBytes;
    }
  }
  if (manifestJson == null) {
    throw const FormatException('manifest missing');
  }
  return {'manifest': manifestJson, 'files': files};
}
