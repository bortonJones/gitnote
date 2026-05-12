import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/utils/file_type_utils.dart';
import '../../core/utils/markdown_utils.dart';
import '../../core/utils/native_file_share.dart';
import '../../data/models/repo_config.dart';
import '../../data/models/sync_file_meta.dart';
import '../../data/repositories/github_notes_repository.dart';
import 'mermaid_markdown.dart';

class MarkdownReaderPage extends ConsumerStatefulWidget {
  const MarkdownReaderPage({
    super.key,
    required this.repoPath,
    required this.title,
  });

  final String repoPath;
  final String title;

  @override
  ConsumerState<MarkdownReaderPage> createState() => _MarkdownReaderPageState();
}

class _MarkdownReaderPageState extends ConsumerState<MarkdownReaderPage> {
  List<int>? _bytes;
  String? _localFilePath;
  Object? _error;
  bool _isReceiving = false;
  int _received = 0;
  int _total = 0;

  SupportedFileType get _fileType => FileTypeUtils.typeOf(widget.repoPath);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(syncFileMetaMapProvider).valueOrNull?[widget.repoPath];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<_ReaderMenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _ReaderMenuAction.refresh:
                  _loadFile(forceRefresh: true);
                case _ReaderMenuAction.share:
                  _shareFile();
                case _ReaderMenuAction.save:
                  _saveFile();
                case _ReaderMenuAction.properties:
                  _showProperties(meta);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ReaderMenuAction.refresh,
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 12),
                    Text('重新接收'),
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
              PopupMenuItem(
                value: _ReaderMenuAction.save,
                child: Row(
                  children: [
                    Icon(Icons.save_alt),
                    SizedBox(width: 12),
                    Text('保存'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _ReaderMenuAction.properties,
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Text('属性'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(meta),
    );
  }

  Widget _buildBody(SyncFileMeta? meta) {
    if (_isReceiving) {
      return _ReceivingView(
        fileName: widget.title,
        received: _received,
        total: _total,
        showProgress: FileTypeUtils.shouldShowProgress(meta?.size),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('文件加载失败: $_error'),
        ),
      );
    }

    final bytes = _bytes;
    if (bytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_fileType) {
      case SupportedFileType.markdown:
        return _buildMarkdown(bytes);
      case SupportedFileType.text:
        return _buildText(bytes);
      case SupportedFileType.image:
        return _buildImage(bytes);
      case SupportedFileType.pdf:
      case SupportedFileType.unsupported:
        return _UnsupportedFileView(
          fileName: widget.title,
          fileType: _fileType,
          size: meta?.size,
          isReceived: _localFilePath != null,
        );
    }
  }

  Widget _buildMarkdown(List<int> bytes) {
    try {
      final content = utf8.decode(bytes);
      final config = ref.watch(repoConfigControllerProvider).valueOrNull;
      final markdown = config == null
          ? content
          : MarkdownUtils.prepareForDisplay(
              markdown: content,
              config: config,
              documentPath: widget.repoPath,
            );
      return Markdown(
        data: markdown,
        blockSyntaxes: [MermaidBlockSyntax()],
        builders: {'mermaid': MermaidElementBuilder()},
        selectable: true,
        padding: const EdgeInsets.all(16),
      );
    } on FormatException {
      return const Center(child: Text('文件不是有效的 UTF-8 Markdown。'));
    }
  }

  Widget _buildText(List<int> bytes) {
    try {
      final content = utf8.decode(bytes);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(content),
      );
    } on FormatException {
      return const Center(child: Text('文件不是有效的 UTF-8 文本。'));
    }
  }

  Widget _buildImage(List<int> bytes) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: Center(
        child: Image.memory(Uint8List.fromList(bytes)),
      ),
    );
  }

  Future<void> _loadFile({bool forceRefresh = false}) async {
    setState(() {
      _error = null;
      _isReceiving = true;
      _received = 0;
      _total = 0;
    });

    try {
      final result = await _ensureReceived(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }
      setState(() {
        _bytes = result.bytes;
        _localFilePath = result.localFilePath;
        _isReceiving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _isReceiving = false;
      });
    }
  }

  Future<_ReceivedFile> _ensureReceived({bool forceRefresh = false}) async {
    final config = await ref.read(repoConfigControllerProvider.future);
    if (config == null) {
      throw Exception('仓库配置不存在。');
    }

    final repo = ref.read(notesRepositoryProvider);
    final metaMap = await ref.read(syncFileMetaMapProvider.future);
    final meta = metaMap[widget.repoPath];

    if (!forceRefresh && meta?.isDownloaded == true) {
      final cached = await repo.readCachedFileBytes(config, widget.repoPath);
      if (cached != null) {
        return _ReceivedFile(cached, meta!.localFilePath);
      }
    }

    final bytes = await repo.fetchRemoteFileBytes(
      config,
      widget.repoPath,
      onReceiveProgress: (received, total) {
        if (!mounted || !FileTypeUtils.shouldShowProgress(meta?.size)) {
          return;
        }
        setState(() {
          _received = received;
          _total = total;
        });
      },
    );
    final localFilePath = await repo.writeCachedFileBytes(
      config,
      widget.repoPath,
      bytes,
    );
    await _updateReceivedMeta(repo, config, meta, localFilePath);
    return _ReceivedFile(bytes, localFilePath);
  }

  Future<void> _updateReceivedMeta(
    GithubNotesRepository repo,
    RepoConfig config,
    SyncFileMeta? meta,
    String localFilePath,
  ) async {
    if (meta == null) {
      return;
    }
    await repo.upsertSyncFileMeta(
      config,
      SyncFileMeta(
        path: meta.path,
        sha: meta.sha,
        localFilePath: localFilePath,
        updatedAt: DateTime.now(),
        size: meta.size,
      ),
    );
    ref.invalidate(syncIndexProvider);
    ref.invalidate(syncFileMetaMapProvider);
    ref.invalidate(notesTreeProvider);
    ref.invalidate(lastSyncLabelProvider);
  }

  Future<void> _shareFile() async {
    try {
      final result = await _ensureReceived();
      final didNativeShare = await NativeFileShare.shareFile(
        path: result.localFilePath,
        title: widget.title,
        mimeType: FileTypeUtils.mimeTypeFor(widget.repoPath),
      );
      if (didNativeShare) {
        return;
      }
      await Share.shareXFiles(
        [
          XFile(
            result.localFilePath,
            name: widget.title,
            mimeType: FileTypeUtils.mimeTypeFor(widget.repoPath),
          ),
        ],
        text: widget.title,
        subject: widget.title,
      );
    } catch (error) {
      _showSnackBar('分享失败: $error');
    }
  }

  Future<void> _saveFile() async {
    try {
      final received = await _ensureReceived();
      final config = await ref.read(repoConfigControllerProvider.future);
      if (config == null) {
        throw Exception('仓库配置不存在。');
      }
      final savedPath = await NativeFileShare.saveFileToPublicDownloads(
            sourcePath: received.localFilePath,
            repoKey: config.repoKey,
            repoPath: widget.repoPath,
            mimeType: FileTypeUtils.mimeTypeFor(widget.repoPath),
          ) ??
          await ref
              .read(notesRepositoryProvider)
              .saveCachedFileToDownloads(config, widget.repoPath);
      _showSnackBar('已保存到: $savedPath');
    } catch (error) {
      _showSnackBar('保存失败: $error');
    }
  }

  Future<void> _showProperties(SyncFileMeta? meta) async {
    if (!(meta?.isDownloaded ?? _localFilePath != null)) {
      _showSnackBar('文件尚未接收，请先接收后再查看属性。');
      return;
    }

    final typeLabel = FileTypeUtils.displayType(_fileType);
    final sizeLabel = FileTypeUtils.formatBytes(meta?.size ?? _bytes?.length);
    final receivedAt = _formatDateTime(meta?.updatedAt);
    final cachePath = meta?.localFilePath.trim().isNotEmpty == true
        ? meta!.localFilePath
        : (_localFilePath ?? '未知');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('文件属性'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PropertyRow(label: '文件名', value: widget.title),
                _PropertyRow(label: '格式', value: typeLabel),
                _PropertyRow(label: '大小', value: sizeLabel),
                _PropertyRow(label: '仓库路径', value: widget.repoPath),
                _PropertyRow(label: '缓存路径', value: cachePath),
                _PropertyRow(label: 'SHA', value: meta?.sha ?? '未知'),
                _PropertyRow(label: '同步时间', value: receivedAt ?? '未知'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String? _formatDateTime(DateTime? value) {
    if (value == null || value.year == 1970) {
      return null;
    }
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivingView extends StatelessWidget {
  const _ReceivingView({
    required this.fileName,
    required this.received,
    required this.total,
    required this.showProgress,
  });

  final String fileName;
  final int received;
  final int total;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? received / total : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showProgress)
              LinearProgressIndicator(value: progress)
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在接收 $fileName'),
            if (showProgress) ...[
              const SizedBox(height: 8),
              Text(
                '${FileTypeUtils.formatBytes(received)} / ${FileTypeUtils.formatBytes(total > 0 ? total : null)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnsupportedFileView extends StatelessWidget {
  const _UnsupportedFileView({
    required this.fileName,
    required this.fileType,
    required this.size,
    required this.isReceived,
  });

  final String fileName;
  final SupportedFileType fileType;
  final int? size;
  final bool isReceived;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              fileType == SupportedFileType.pdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              fileName,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(FileTypeUtils.displayType(fileType)),
            const SizedBox(height: 8),
            Text(FileTypeUtils.formatBytes(size)),
            const SizedBox(height: 8),
            Chip(
              avatar: Icon(
                isReceived ? Icons.check_circle : Icons.cloud_off,
                size: 18,
              ),
              label: Text(isReceived ? '已接收' : '未接收'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedFile {
  const _ReceivedFile(this.bytes, this.localFilePath);

  final List<int> bytes;
  final String localFilePath;
}

enum _ReaderMenuAction { refresh, share, save, properties }
