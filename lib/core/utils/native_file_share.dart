import 'dart:io';

import 'package:flutter/services.dart';

class NativeFileShare {
  const NativeFileShare._();

  static const _channel = MethodChannel('gitnote/native_share');

  static Future<bool> shareFile({
    required String path,
    required String title,
    String? mimeType,
  }) async {
    if (!Platform.isAndroid) {
      return false;
    }

    final result = await _channel.invokeMethod<bool>(
      'shareFile',
      {
        'path': path,
        'title': title,
        'mimeType': mimeType ?? '*/*',
      },
    );
    return result ?? false;
  }

  static Future<String?> saveFileToPublicDownloads({
    required String sourcePath,
    required String repoKey,
    required String repoPath,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) {
      return null;
    }

    return _channel.invokeMethod<String>(
      'saveFileToPublicDownloads',
      {
        'sourcePath': sourcePath,
        'repoKey': repoKey,
        'repoPath': repoPath,
        'mimeType': mimeType,
      },
    );
  }
}
