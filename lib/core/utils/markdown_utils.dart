import '../../data/models/repo_config.dart';
import 'tree_builder.dart';

class MarkdownUtils {
  const MarkdownUtils._();

  static String prepareForDisplay({
    required String markdown,
    required RepoConfig config,
    required String documentPath,
  }) {
    final rewritten = rewriteRelativeImages(
      markdown: markdown,
      config: config,
      documentPath: documentPath,
    );
    return expandSoftLineBreaks(rewritten);
  }

  static String rewriteRelativeImages({
    required String markdown,
    required RepoConfig config,
    required String documentPath,
  }) {
    final imagePattern = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
    return markdown.replaceAllMapped(imagePattern, (match) {
      final alt = match.group(1) ?? '';
      final rawPath = (match.group(2) ?? '').trim();
      if (_isAbsoluteUrl(rawPath) || rawPath.startsWith('data:')) {
        return match.group(0) ?? '';
      }

      final cleanPath = rawPath.split(' ').first;
      final resolvedPath = TreeBuilder.resolveImagePath(
        documentPath: documentPath,
        imagePath: cleanPath,
      );
      final imageUrl =
          'https://raw.githubusercontent.com/${config.owner}/${config.repo}/${config.branch}/$resolvedPath';
      return '![$alt]($imageUrl)';
    });
  }

  static bool _isAbsoluteUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }

  static String expandSoftLineBreaks(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n');
    final lines = normalized.split('\n');
    final output = <String>[];

    var inFrontMatter = false;
    var inCodeFence = false;

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final trimmed = line.trim();
      final isFirstLine = index == 0;

      if (_isFenceLine(trimmed)) {
        inCodeFence = !inCodeFence;
        output.add(line);
        continue;
      }

      if (!inCodeFence && _isFrontMatterBoundary(trimmed, isFirstLine, inFrontMatter)) {
        inFrontMatter = !inFrontMatter;
        output.add(line);
        continue;
      }

      if (inCodeFence || inFrontMatter) {
        output.add(line);
        continue;
      }

      if (_shouldKeepPlainLine(line, index: index, lines: lines)) {
        output.add(line);
        continue;
      }

      output.add('$line  ');
    }

    return output.join('\n');
  }

  static bool _isFenceLine(String trimmed) {
    return trimmed.startsWith('```') || trimmed.startsWith('~~~');
  }

  static bool _isFrontMatterBoundary(
    String trimmed,
    bool isFirstLine,
    bool inFrontMatter,
  ) {
    if (trimmed != '---') {
      return false;
    }
    return isFirstLine || inFrontMatter;
  }

  static bool _shouldKeepPlainLine(
    String line, {
    required int index,
    required List<String> lines,
  }) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return true;
    }

    if (_isBlockStructuredLine(trimmed)) {
      return true;
    }

    if (index == lines.length - 1) {
      return true;
    }

    final nextTrimmed = lines[index + 1].trim();
    if (nextTrimmed.isEmpty || _isBlockStructuredLine(nextTrimmed)) {
      return true;
    }

    return false;
  }

  static bool _isBlockStructuredLine(String trimmed) {
    if (trimmed.isEmpty) {
      return true;
    }

    if (trimmed.startsWith('#') ||
        trimmed.startsWith('>') ||
        trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        trimmed.startsWith('+ ') ||
        trimmed.startsWith('|')) {
      return true;
    }

    if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
      return true;
    }

    if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
      return true;
    }

    return false;
  }
}
