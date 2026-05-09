import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:webview_flutter/webview_flutter.dart';

class MermaidBlockSyntax extends md.BlockSyntax {
  static final RegExp _fencePattern = RegExp(
    r'^([ ]{0,3})(?<marker>`{3,}|~{3,})[ \t]*mermaid[^\n`~]*$',
    caseSensitive: false,
  );

  @override
  RegExp get pattern => _fencePattern;

  @override
  md.Node parse(md.BlockParser parser) {
    final match = pattern.firstMatch(parser.current.content)!;
    final marker = match.namedGroup('marker')!;
    final indent = match[1]!.length;
    final lines = <String>[];

    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      if (_isClosingFence(line, marker, indent)) {
        parser.advance();
        break;
      }
      lines.add(_removeIndentation(line, indent));
      parser.advance();
    }

    return md.Element.text('mermaid', lines.join('\n').trimRight());
  }

  bool _isClosingFence(String line, String openingMarker, int indent) {
    final escapedMarker = RegExp.escape(openingMarker[0]);
    final closingPattern = RegExp(
      '^ {0,$indent}$escapedMarker{${openingMarker.length},}[ \t]*\$',
    );
    return closingPattern.hasMatch(line);
  }

  String _removeIndentation(String content, int length) {
    final text = content.replaceFirst(RegExp('^\\s{0,$length}'), '');
    return content.substring(content.length - text.length);
  }
}

class MermaidElementBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return MermaidDiagram(source: element.textContent);
  }
}

class MermaidDiagram extends StatefulWidget {
  const MermaidDiagram({
    super.key,
    required this.source,
  });

  final String source;

  @override
  State<MermaidDiagram> createState() => _MermaidDiagramState();
}

class _MermaidDiagramState extends State<MermaidDiagram> {
  late final WebViewController _controller;
  double _height = 220;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'MermaidHost',
        onMessageReceived: _handleWebMessage,
      )
      ..loadHtmlString(_buildHtml(widget.source));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          height: _error == null ? _height : null,
          width: double.infinity,
          child: _error == null ? _buildWebView() : _buildError(theme),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x00FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_outlined, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Mermaid 渲染失败',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          SelectableText(
            widget.source,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  void _handleWebMessage(JavaScriptMessage message) {
    if (!mounted) {
      return;
    }

    final decoded = jsonDecode(message.message) as Map<String, dynamic>;
    final type = decoded['type'] as String?;
    if (type == 'ready') {
      setState(() => _isLoading = false);
      return;
    }
    if (type == 'height') {
      final nextHeight = (decoded['height'] as num).toDouble().clamp(160, 1200);
      setState(() {
        _height = nextHeight.toDouble();
        _isLoading = false;
      });
      return;
    }
    if (type == 'error') {
      setState(() {
        _error = decoded['message']?.toString() ?? 'Unknown Mermaid error';
        _isLoading = false;
      });
    }
  }

  String _buildHtml(String source) {
    final encodedSource = jsonEncode(source);
    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      background: transparent;
      color: #1f2933;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      overflow: hidden;
    }
    #wrap {
      box-sizing: border-box;
      padding: 14px;
      width: 100%;
      min-height: 120px;
    }
    #diagram {
      display: flex;
      justify-content: center;
      min-width: max-content;
    }
    svg {
      max-width: 100%;
      height: auto;
    }
    .error {
      color: #b42318;
      white-space: pre-wrap;
      font: 13px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    }
  </style>
  <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
</head>
<body>
  <div id="wrap">
    <div id="diagram"></div>
  </div>
  <script>
    const source = $encodedSource;
    const host = window.MermaidHost;

    function post(payload) {
      host.postMessage(JSON.stringify(payload));
    }

    function updateHeight() {
      const wrap = document.getElementById('wrap');
      const rect = wrap.getBoundingClientRect();
      post({ type: 'height', height: Math.ceil(rect.height) + 2 });
    }

    async function renderDiagram() {
      try {
        mermaid.initialize({
          startOnLoad: false,
          securityLevel: 'strict',
          theme: 'default',
          flowchart: { useMaxWidth: true },
          sequence: { useMaxWidth: true }
        });
        const element = document.getElementById('diagram');
        element.textContent = source;
        await mermaid.run({ nodes: [element] });
        requestAnimationFrame(() => {
          updateHeight();
          post({ type: 'ready' });
        });
      } catch (error) {
        post({ type: 'error', message: String(error && error.message ? error.message : error) });
      }
    }

    if (window.mermaid) {
      renderDiagram();
    } else {
      post({ type: 'error', message: 'Mermaid.js 加载失败，请检查网络。' });
    }
  </script>
</body>
</html>
''';
  }
}
