enum SupportedFileType {
  markdown,
  text,
  image,
  pdf,
  unsupported,
}

class FileTypeUtils {
  const FileTypeUtils._();

  static const progressThresholdBytes = 1024 * 1024;

  static SupportedFileType typeOf(String path) {
    final extension = _extensionOf(path);
    if (const {'.md', '.markdown'}.contains(extension)) {
      return SupportedFileType.markdown;
    }
    if (const {
      '.txt',
      '.log',
      '.json',
      '.yaml',
      '.yml',
      '.csv',
      '.xml',
    }.contains(extension)) {
      return SupportedFileType.text;
    }
    if (const {
      '.png',
      '.jpg',
      '.jpeg',
      '.gif',
      '.webp',
      '.bmp',
    }.contains(extension)) {
      return SupportedFileType.image;
    }
    if (extension == '.pdf') {
      return SupportedFileType.pdf;
    }
    return SupportedFileType.unsupported;
  }

  static bool canPreview(String path) {
    final type = typeOf(path);
    return type == SupportedFileType.markdown ||
        type == SupportedFileType.text ||
        type == SupportedFileType.image;
  }

  static bool shouldShowProgress(int? size) {
    return (size ?? 0) >= progressThresholdBytes;
  }

  static String formatBytes(int? bytes) {
    if (bytes == null || bytes < 0) {
      return '未知大小';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(gb >= 100 ? 0 : 1)} GB';
  }

  static String displayType(SupportedFileType type) {
    switch (type) {
      case SupportedFileType.markdown:
        return 'Markdown';
      case SupportedFileType.text:
        return '文本文件';
      case SupportedFileType.image:
        return '图片文件';
      case SupportedFileType.pdf:
        return 'PDF 文件';
      case SupportedFileType.unsupported:
        return '不支持预览的文件';
    }
  }

  static String _extensionOf(String path) {
    final fileName = path.split('/').last.toLowerCase();
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex < 0) {
      return '';
    }
    return fileName.substring(dotIndex);
  }
}
