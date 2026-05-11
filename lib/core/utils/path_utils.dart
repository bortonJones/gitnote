import 'package:path/path.dart' as p;

class PathUtils {
  const PathUtils._();

  static String normalizeRootPath(String? value) {
    final trimmed = (value ?? '').trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) {
      return '';
    }

    final segments = trimmed
        .split('/')
        .where((segment) => segment.isNotEmpty && segment != '.')
        .toList();
    return segments.join('/');
  }

  static bool isMarkdownFile(String path) {
    return path.toLowerCase().endsWith('.md');
  }

  static bool hasHiddenPathSegment(String path) {
    final normalized = path.replaceAll('\\', '/');
    return normalized
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .any((segment) => segment.startsWith('.'));
  }

  static bool isInsideRoot(String path, String rootPath) {
    if (rootPath.isEmpty) {
      return true;
    }
    return path == rootPath || path.startsWith('$rootPath/');
  }

  static String fileName(String path) {
    return p.basename(path);
  }

  static String directoryName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final lastSlash = normalized.lastIndexOf('/');
    if (lastSlash < 0) {
      return '';
    }
    return normalized.substring(0, lastSlash);
  }

  static String joinRepoPath(String baseDir, String target) {
    final baseSegments =
        baseDir.split('/').where((segment) => segment.isNotEmpty).toList();
    final targetSegments =
        target.split('/').where((segment) => segment.isNotEmpty).toList();
    final result = <String>[...baseSegments];

    for (final segment in targetSegments) {
      if (segment == '.') {
        continue;
      }
      if (segment == '..') {
        if (result.isNotEmpty) {
          result.removeLast();
        }
        continue;
      }
      result.add(segment);
    }

    return result.join('/');
  }

  static String safeRepoKey(String owner, String repo, String branch) {
    return '${owner}_${repo}_$branch'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }
}
