import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import 'mermaid_markdown.dart';

class MarkdownReaderPage extends ConsumerWidget {
  const MarkdownReaderPage({
    super.key,
    required this.repoPath,
    required this.title,
  });

  final String repoPath;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentValue = ref.watch(markdownContentProvider(repoPath));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<_ReaderMenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _ReaderMenuAction.refresh:
                  _refresh(ref);
                case _ReaderMenuAction.share:
                  _shareMarkdown(context, contentValue.valueOrNull);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ReaderMenuAction.refresh,
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 12),
                    Text('刷新'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ReaderMenuAction.share,
                child: Row(
                  children: [
                    Icon(Icons.ios_share),
                    SizedBox(width: 12),
                    Text('分享'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: contentValue.when(
        data: (content) => Markdown(
          data: content,
          blockSyntaxes: [MermaidBlockSyntax()],
          builders: {'mermaid': MermaidElementBuilder()},
          selectable: true,
          padding: const EdgeInsets.all(16),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载 Markdown 失败: $error')),
      ),
    );
  }

  void _refresh(WidgetRef ref) {
    final state = ref.read(markdownReloadTickProvider(repoPath).notifier);
    state.state++;
    ref.invalidate(markdownContentProvider(repoPath));
  }

  Future<void> _shareMarkdown(BuildContext context, String? content) async {
    if (content == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('内容尚未加载完成')),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = _safeFileName(title);
      final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(content);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/markdown', name: fileName)],
        text: title,
        subject: title,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败: $error')),
      );
    }
  }

  String _safeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized.isEmpty ? 'note' : sanitized;
  }
}

enum _ReaderMenuAction { refresh, share }
