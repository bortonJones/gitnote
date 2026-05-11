import 'package:flutter_test/flutter_test.dart';
import 'package:gitnote/core/utils/markdown_utils.dart';
import 'package:gitnote/core/utils/path_utils.dart';
import 'package:gitnote/core/utils/tree_builder.dart';
import 'package:gitnote/features/markdown_reader/mermaid_markdown.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  group('PathUtils', () {
    test('normalizeRootPath trims and removes duplicated separators', () {
      expect(PathUtils.normalizeRootPath('/docs//notes/'), 'docs/notes');
    });

    test('normalizeRootPath treats slash as repository root', () {
      expect(PathUtils.normalizeRootPath('/'), '');
    });

    test('isInsideRoot supports exact and descendant paths', () {
      expect(PathUtils.isInsideRoot('docs/readme.md', 'docs'), isTrue);
      expect(PathUtils.isInsideRoot('docs/sub/a.md', 'docs'), isTrue);
      expect(PathUtils.isInsideRoot('guide/a.md', 'docs'), isFalse);
    });

    test('hasHiddenPathSegment detects dot files and directories', () {
      expect(PathUtils.hasHiddenPathSegment('.codex'), isTrue);
      expect(PathUtils.hasHiddenPathSegment('.vscode/settings.json'), isTrue);
      expect(PathUtils.hasHiddenPathSegment('docs/.assets/demo.png'), isTrue);
      expect(PathUtils.hasHiddenPathSegment('docs/readme.md'), isFalse);
    });
  });

  test('TreeBuilder resolves relative image path', () {
    expect(
      TreeBuilder.resolveImagePath(
        documentPath: 'docs/guide/start.md',
        imagePath: '../images/demo.png',
      ),
      'docs/images/demo.png',
    );
  });

  group('MarkdownUtils', () {
    test('expands single line breaks in plain note paragraphs', () {
      const input = '今天决定要继续减肥\n'
          'gpt给的减肥建议，结合我的实际情况\n'
          '[[减脂执行手册（当前版本 v1.0）]]\n'
          '很棒';

      expect(
        MarkdownUtils.expandSoftLineBreaks(input),
        '今天决定要继续减肥  \n'
        'gpt给的减肥建议，结合我的实际情况  \n'
        '[[减脂执行手册（当前版本 v1.0）]]  \n'
        '很棒',
      );
    });

    test('keeps front matter and headings unchanged', () {
      const input = '---\n'
          'tags: 日记\n'
          '---\n'
          '# 四月\n'
          '## 2026年4月13日 星期一\n'
          '\n'
          '今天决定要继续减肥\n'
          '很棒';

      expect(
        MarkdownUtils.expandSoftLineBreaks(input),
        '---\n'
        'tags: 日记\n'
        '---\n'
        '# 四月\n'
        '## 2026年4月13日 星期一\n'
        '\n'
        '今天决定要继续减肥  \n'
        '很棒',
      );
    });

    test('keeps lists and fenced code blocks unchanged', () {
      const input = '- 第一项\n'
          '- 第二项\n'
          '\n'
          '```dart\n'
          'print("hello");\n'
          'print("world");\n'
          '```';

      expect(MarkdownUtils.expandSoftLineBreaks(input), input);
    });
  });

  test('MermaidBlockSyntax parses mermaid fenced code blocks', () {
    final document = md.Document(
      blockSyntaxes: [MermaidBlockSyntax()],
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );

    final nodes = document.parse('```mermaid\nflowchart TD\nA-->B\n```');

    expect(nodes, hasLength(1));
    final node = nodes.single as md.Element;
    expect(node.tag, 'mermaid');
    expect(node.textContent, 'flowchart TD\nA-->B');
  });
}
