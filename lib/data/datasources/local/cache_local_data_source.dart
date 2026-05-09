import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/storage_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../models/repo_config.dart';
import '../../models/sync_file_meta.dart';
import '../../models/sync_index.dart';

class CacheLocalDataSource {
  Future<Directory> getRepoRootDir(RepoConfig config) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final repoDir = Directory(
        p.join(
          appDir.path,
          StorageConstants.appFolderName,
          config.repoKey,
        ),
      );
      await repoDir.create(recursive: true);
      return repoDir;
    } on FileSystemException catch (error) {
      throw LocalStorageException('创建本地缓存目录失败: ${error.message}');
    }
  }

  Future<Directory> getFilesDir(RepoConfig config) async {
    final repoDir = await getRepoRootDir(config);
    final filesDir =
        Directory(p.join(repoDir.path, StorageConstants.filesFolderName));
    await filesDir.create(recursive: true);
    return filesDir;
  }

  Future<SyncIndex?> readIndex(RepoConfig config) async {
    try {
      final repoDir = await getRepoRootDir(config);
      final indexFile = File(
        p.join(repoDir.path, StorageConstants.indexFileName),
      );
      if (!await indexFile.exists()) {
        return null;
      }
      final raw = await indexFile.readAsString();
      return SyncIndex.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FileSystemException catch (error) {
      throw LocalStorageException('读取本地索引失败: ${error.message}');
    } on FormatException {
      throw const LocalStorageException('本地索引格式损坏，无法读取。');
    }
  }

  Future<void> writeIndex(SyncIndex index, RepoConfig config) async {
    try {
      final repoDir = await getRepoRootDir(config);
      final indexFile = File(
        p.join(repoDir.path, StorageConstants.indexFileName),
      );
      await indexFile.writeAsString(jsonEncode(index.toJson()));
    } on FileSystemException catch (error) {
      throw LocalStorageException('写入本地索引失败: ${error.message}');
    }
  }

  Future<String?> readMarkdownFile(RepoConfig config, String repoPath) async {
    try {
      final file = await _resolveMarkdownFile(config, repoPath);
      if (!await file.exists()) {
        return null;
      }
      return file.readAsString();
    } on FileSystemException catch (error) {
      throw LocalStorageException('读取 Markdown 缓存失败: ${error.message}');
    }
  }

  Future<String> writeMarkdownFile({
    required RepoConfig config,
    required String repoPath,
    required String content,
  }) async {
    try {
      final file = await _resolveMarkdownFile(config, repoPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return file.path;
    } on FileSystemException catch (error) {
      throw LocalStorageException('写入 Markdown 缓存失败: ${error.message}');
    }
  }

  Future<void> deleteMarkdownFile(RepoConfig config, String repoPath) async {
    try {
      final file = await _resolveMarkdownFile(config, repoPath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException catch (error) {
      throw LocalStorageException('删除 Markdown 缓存失败: ${error.message}');
    }
  }

  Future<void> clearRepoCache(RepoConfig config) async {
    try {
      final repoDir = await getRepoRootDir(config);
      if (await repoDir.exists()) {
        await repoDir.delete(recursive: true);
      }
    } on FileSystemException catch (error) {
      throw LocalStorageException('清空本地缓存失败: ${error.message}');
    }
  }

  Future<File> _resolveMarkdownFile(RepoConfig config, String repoPath) async {
    final filesDir = await getFilesDir(config);
    final segments =
        repoPath.split('/').where((segment) => segment.isNotEmpty).toList();
    return File(p.joinAll([filesDir.path, ...segments]));
  }

  SyncIndex buildIndex({
    required RepoConfig config,
    required List<SyncFileMeta> files,
    required DateTime syncedAt,
  }) {
    return SyncIndex(
      repoKey: config.repoKey,
      lastSyncTime: syncedAt,
      branch: config.branch,
      files: files,
    );
  }
}
