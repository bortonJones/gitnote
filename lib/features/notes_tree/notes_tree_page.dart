import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/tree_builder.dart';
import '../../data/models/sync_file_meta.dart';
import '../../domain/entities/repo_node.dart';
import '../../domain/entities/sync_result.dart';
import '../markdown_reader/markdown_reader_page.dart';
import '../settings/settings_page.dart';

class NotesTreePage extends ConsumerStatefulWidget {
  const NotesTreePage({super.key});

  @override
  ConsumerState<NotesTreePage> createState() => _NotesTreePageState();
}

class _NotesTreePageState extends ConsumerState<NotesTreePage> {
  final _searchController = TextEditingController();

  String _currentPath = '';
  bool _isSearchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(repoConfigControllerProvider).valueOrNull;
    final treeValue = ref.watch(notesTreeProvider);
    final lastSyncLabel = ref.watch(lastSyncLabelProvider).valueOrNull;
    final syncState = ref.watch(syncControllerProvider);
    final syncMetaMap = ref.watch(syncFileMetaMapProvider).valueOrNull ?? const {};
    final isSyncing = syncState.isLoading;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handleBackNavigation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(config == null ? 'Markdown 目录' : '${config.repo} 笔记'),
          actions: [
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearchOpen = !_isSearchOpen;
                  if (!_isSearchOpen) {
                    _searchController.clear();
                  }
                });
              },
              icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton.icon(
                onPressed: isSyncing
                    ? null
                    : () => _runSync(
                          context: context,
                          ref: ref,
                        ),
                icon: isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(isSyncing ? '同步中' : '同步'),
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsPage(),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            if (isSyncing) {
              return;
            }
            await _runSync(context: context, ref: ref);
          },
          child: treeValue.when(
            data: (root) {
              if (root == null) {
                return const Center(
                  child: Text('暂无目录数据，请先到设置页保存配置。'),
                );
              }

              final currentNode =
                  TreeBuilder.findNodeByPath(root, _currentPath) ?? root;
              final children = currentNode.type == RepoNodeType.directory
                  ? currentNode.children
                  : const <RepoNode>[];
              final searchResults = TreeBuilder.searchByTitle(
                root,
                _searchController.text,
              );

              return Stack(
                children: [
                  ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _BreadcrumbBar(
                        currentPath: _currentPath,
                        onTapSegment: (path) {
                          setState(() {
                            _currentPath = path;
                          });
                        },
                      ),
                      if (lastSyncLabel != null) ...[
                        const SizedBox(height: 8),
                        Text('最近同步: $lastSyncLabel'),
                      ],
                      const SizedBox(height: 12),
                      if (children.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Center(
                            child: Text('当前目录下没有内容。'),
                          ),
                        )
                      else
                        ...children.map(
                          (node) => _RepoNodeTile(
                            node: node,
                            syncMetaMap: syncMetaMap,
                            onOpenDirectory: (path) {
                              setState(() {
                                _currentPath = path;
                              });
                            },
                            onOpenFile: (path, title) {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => MarkdownReaderPage(
                                    repoPath: path,
                                    title: title,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                  if (_isSearchOpen)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 8,
                      child: Card(
                        elevation: 8,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 420),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    hintText: '搜索文件夹或文件标题',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (_) {
                                    setState(() {});
                                  },
                                ),
                                const SizedBox(height: 12),
                                Flexible(
                                  child: searchResults.isEmpty
                                      ? const Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 24,
                                            ),
                                            child: Text('没有匹配结果'),
                                          ),
                                        )
                                      : ListView.separated(
                                          shrinkWrap: true,
                                          itemCount: searchResults.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final node = searchResults[index];
                                            final targetPath =
                                                node.type ==
                                                        RepoNodeType.directory
                                                    ? node.path
                                                    : TreeBuilder
                                                        .parentDirectoryPath(
                                                        node.path,
                                                      );
                                            return ListTile(
                                              dense: true,
                                              leading: Icon(
                                                node.type ==
                                                        RepoNodeType.directory
                                                    ? Icons.folder_outlined
                                                    : Icons
                                                        .description_outlined,
                                              ),
                                              title: Text(node.name),
                                              subtitle: Text(
                                                targetPath.isEmpty
                                                    ? 'home'
                                                    : 'home / ${targetPath.replaceAll('/', ' / ')}',
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  _currentPath = targetPath;
                                                  _isSearchOpen = false;
                                                  _searchController.clear();
                                                });
                                              },
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('加载目录失败: $error')),
          ),
        ),
      ),
    );
  }

  Future<void> _handleBackNavigation() async {
    if (_isSearchOpen) {
      setState(() {
        _isSearchOpen = false;
        _searchController.clear();
      });
      return;
    }

    if (_currentPath.isNotEmpty) {
      setState(() {
        _currentPath = _parentPathOf(_currentPath);
      });
      return;
    }

    final shouldExit = await _showExitConfirmDialog();
    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  String _parentPathOf(String path) {
    final segments =
        path.split('/').where((segment) => segment.isNotEmpty).toList();
    if (segments.isEmpty) {
      return '';
    }
    segments.removeLast();
    return segments.join('/');
  }

  Future<bool> _showExitConfirmDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认退出'),
          content: const Text('是否退出应用？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('退出'),
            ),
          ],
        );
      },
    );
    return shouldExit ?? false;
  }

  Future<void> _runSync({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    try {
      final result = await ref.read(syncControllerProvider.notifier).syncNow();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_syncSummary(result))),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('同步失败: $error')),
        );
      }
    }
  }

  String _syncSummary(SyncResult result) {
    return '同步完成：新增 ${result.addedCount}，更新 ${result.updatedCount}，删除 ${result.deletedCount}，失败 ${result.failedCount}';
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.currentPath,
    required this.onTapSegment,
  });

  final String currentPath;
  final ValueChanged<String> onTapSegment;

  @override
  Widget build(BuildContext context) {
    final segments =
        currentPath.split('/').where((segment) => segment.isNotEmpty).toList();
    final items = <_BreadcrumbItem>[
      const _BreadcrumbItem(label: 'home', path: ''),
    ];

    var rollingPath = '';
    for (final segment in segments) {
      rollingPath = rollingPath.isEmpty ? segment : '$rollingPath/$segment';
      items.add(_BreadcrumbItem(label: segment, path: rollingPath));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '/',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            TextButton(
              onPressed: () => onTapSegment(items[index].path),
              style: TextButton.styleFrom(
                foregroundColor: index == items.length - 1
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.primary,
                textStyle: TextStyle(
                  fontWeight:
                      index == items.length - 1 ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              child: Text(items[index].label),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreadcrumbItem {
  const _BreadcrumbItem({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}

class _RepoNodeTile extends StatelessWidget {
  const _RepoNodeTile({
    required this.node,
    required this.syncMetaMap,
    required this.onOpenDirectory,
    required this.onOpenFile,
  });

  final RepoNode node;
  final Map<String, SyncFileMeta> syncMetaMap;
  final ValueChanged<String> onOpenDirectory;
  final void Function(String path, String title) onOpenFile;

  @override
  Widget build(BuildContext context) {
    final stats = _RepoNodeStats.fromNode(node, syncMetaMap);

    if (node.type == RepoNodeType.file) {
      final meta = syncMetaMap[node.path];
      final isDownloaded = meta?.isDownloaded ?? false;
      final formattedTime = _formatSyncTime(meta?.updatedAt, isDownloaded);

      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Icon(
          isDownloaded ? Icons.check_circle : Icons.sync_problem,
          color: isDownloaded ? Colors.green : Theme.of(context).hintColor,
        ),
        title: Text(node.name),
        subtitle: Text(node.path),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              isDownloaded ? Icons.cloud_done : Icons.cloud_off,
              size: 18,
              color: isDownloaded ? Colors.green : Theme.of(context).hintColor,
            ),
            if (formattedTime != null) ...[
              const SizedBox(height: 4),
              Text(
                formattedTime,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        onTap: () => onOpenFile(node.path, node.name),
      );
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: const Icon(Icons.folder_outlined),
      title: Text('${node.name} [${stats.syncedCount}/${stats.totalCount}]'),
      subtitle: node.path.isEmpty ? null : Text(node.path),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => onOpenDirectory(node.path),
    );
  }

  String? _formatSyncTime(DateTime? updatedAt, bool isDownloaded) {
    if (!isDownloaded || updatedAt == null) {
      return null;
    }

    final localTime = updatedAt.toLocal();
    if (localTime.year == 1970) {
      return null;
    }

    final now = DateTime.now();
    final isToday = localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;
    if (isToday) {
      return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    }

    final year = (localTime.year % 100).toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');
    final day = localTime.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }
}

class _RepoNodeStats {
  const _RepoNodeStats({
    required this.syncedCount,
    required this.totalCount,
  });

  final int syncedCount;
  final int totalCount;

  factory _RepoNodeStats.fromNode(
    RepoNode node,
    Map<String, SyncFileMeta> syncMetaMap,
  ) {
    if (node.type == RepoNodeType.file) {
      final isDownloaded = syncMetaMap[node.path]?.isDownloaded ?? false;
      return _RepoNodeStats(
        syncedCount: isDownloaded ? 1 : 0,
        totalCount: 1,
      );
    }

    var syncedCount = 0;
    var totalCount = 0;
    for (final child in node.children) {
      final stats = _RepoNodeStats.fromNode(child, syncMetaMap);
      syncedCount += stats.syncedCount;
      totalCount += stats.totalCount;
    }

    return _RepoNodeStats(
      syncedCount: syncedCount,
      totalCount: totalCount,
    );
  }
}
