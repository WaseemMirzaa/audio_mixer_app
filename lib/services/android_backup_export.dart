import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Saves backups into Android's public Downloads folder via MediaStore.
class AndroidBackupExport {
  static const _channel =
      MethodChannel('com.codetivelab.soundAxis/backup_export');

  static Future<AndroidBackupSaveResult?> saveToPublicDownloads({
    required String sourcePath,
    required String displayName,
  }) async {
    if (!Platform.isAndroid) return null;

    final storage = await Permission.storage.status;
    if (!storage.isGranted) {
      final requested = await Permission.storage.request();
      if (!requested.isGranted) return null;
    }

    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'saveToPublicDownloads',
      {
        'sourcePath': sourcePath,
        'displayName': displayName,
      },
    );
    if (result == null || result['success'] != true) return null;

    return AndroidBackupSaveResult(
      displayName: result['displayName'] as String? ?? displayName,
      location: result['location'] as String? ?? 'Downloads',
      path: result['path'] as String?,
      contentUri: result['contentUri'] as String?,
    );
  }
}

class AndroidBackupSaveResult {
  const AndroidBackupSaveResult({
    required this.displayName,
    required this.location,
    this.path,
    this.contentUri,
  });

  final String displayName;
  final String location;
  final String? path;
  final String? contentUri;
}
