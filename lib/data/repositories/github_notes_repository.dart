import '../../core/utils/tree_builder.dart';
import '../../data/models/flat_repo_file.dart';
import '../../data/models/repo_config.dart';
import '../../data/models/sync_file_meta.dart';
import '../../data/models/sync_index.dart';
import '../../domain/entities/repo_node.dart';
import '../datasources/local/cache_local_data_source.dart';
import '../datasources/local/settings_local_data_source.dart';
import '../datasources/remote/github_remote_data_source.dart';

abstract class GithubNotesRepository {
  Future<RepoConfig?> loadConfig();
  Future<void> saveConfig(RepoConfig config);
  Future<void> testConnection(RepoConfig config);
  Future<List<FlatRepoFile>> fetchRemoteFiles(RepoConfig config);
  Future<String> fetchRemoteMarkdownContent(RepoConfig config, String path);
  Future<List<int>> fetchRemoteFileBytes(
    RepoConfig config,
    String path, {
    void Function(int received, int total)? onReceiveProgress,
  });
  Future<SyncIndex?> readSyncIndex(RepoConfig config);
  Future<void> writeSyncIndex(RepoConfig config, SyncIndex index);
  Future<String?> readCachedMarkdown(RepoConfig config, String path);
  Future<List<int>?> readCachedFileBytes(RepoConfig config, String path);
  Future<String> writeCachedMarkdown(
    RepoConfig config,
    String path,
    String content,
  );
  Future<String> writeCachedFileBytes(
    RepoConfig config,
    String path,
    List<int> bytes,
  );
  Future<void> deleteCachedMarkdown(RepoConfig config, String path);
  Future<String> saveCachedFileToDownloads(RepoConfig config, String path);
  Future<void> clearRepoCache(RepoConfig config);
  Future<Map<String, SyncFileMeta>> readSyncFileMetaMap(RepoConfig config);
  Future<void> upsertSyncFileMeta(RepoConfig config, SyncFileMeta meta);
  Future<RepoNode?> getCachedTree(RepoConfig config);
}

class GithubNotesRepositoryImpl implements GithubNotesRepository {
  GithubNotesRepositoryImpl({
    required SettingsLocalDataSource settingsLocalDataSource,
    required CacheLocalDataSource cacheLocalDataSource,
    required GitHubRemoteDataSource remoteDataSource,
  })  : _settingsLocalDataSource = settingsLocalDataSource,
        _cacheLocalDataSource = cacheLocalDataSource,
        _remoteDataSource = remoteDataSource;

  final SettingsLocalDataSource _settingsLocalDataSource;
  final CacheLocalDataSource _cacheLocalDataSource;
  final GitHubRemoteDataSource _remoteDataSource;

  @override
  Future<List<FlatRepoFile>> fetchRemoteFiles(RepoConfig config) {
    return _remoteDataSource.fetchFiles(config);
  }

  @override
  Future<String> fetchRemoteMarkdownContent(RepoConfig config, String path) {
    return _remoteDataSource.fetchMarkdownContent(config, path);
  }

  @override
  Future<List<int>> fetchRemoteFileBytes(
    RepoConfig config,
    String path, {
    void Function(int received, int total)? onReceiveProgress,
  }) {
    return _remoteDataSource.fetchFileBytes(
      config,
      path,
      onReceiveProgress: onReceiveProgress,
    );
  }

  @override
  Future<RepoNode?> getCachedTree(RepoConfig config) async {
    final index = await readSyncIndex(config);
    if (index == null || index.files.isEmpty) {
      return null;
    }

    final files = index.files
        .map(
          (file) => FlatRepoFile(
            path: file.path,
            sha: file.sha,
            type: 'blob',
            size: file.size,
          ),
        )
        .toList();
    return TreeBuilder.build(rootLabel: config.repo, files: files);
  }

  @override
  Future<RepoConfig?> loadConfig() {
    return _settingsLocalDataSource.loadConfig();
  }

  @override
  Future<String?> readCachedMarkdown(RepoConfig config, String path) {
    return _cacheLocalDataSource.readMarkdownFile(config, path);
  }

  @override
  Future<List<int>?> readCachedFileBytes(RepoConfig config, String path) {
    return _cacheLocalDataSource.readFileBytes(config, path);
  }

  @override
  Future<SyncIndex?> readSyncIndex(RepoConfig config) {
    return _cacheLocalDataSource.readIndex(config);
  }

  @override
  Future<void> saveConfig(RepoConfig config) {
    return _settingsLocalDataSource.saveConfig(config.normalized());
  }

  @override
  Future<void> testConnection(RepoConfig config) {
    return _remoteDataSource.testConnection(config.normalized());
  }

  @override
  Future<void> writeSyncIndex(RepoConfig config, SyncIndex index) {
    return _cacheLocalDataSource.writeIndex(index, config);
  }

  @override
  Future<String> writeCachedMarkdown(
    RepoConfig config,
    String path,
    String content,
  ) {
    return _cacheLocalDataSource.writeMarkdownFile(
      config: config,
      repoPath: path,
      content: content,
    );
  }

  @override
  Future<String> writeCachedFileBytes(
    RepoConfig config,
    String path,
    List<int> bytes,
  ) {
    return _cacheLocalDataSource.writeFileBytes(
      config: config,
      repoPath: path,
      bytes: bytes,
    );
  }

  @override
  Future<void> deleteCachedMarkdown(RepoConfig config, String path) {
    return _cacheLocalDataSource.deleteMarkdownFile(config, path);
  }

  @override
  Future<String> saveCachedFileToDownloads(RepoConfig config, String path) {
    return _cacheLocalDataSource.saveCachedFileToDownloads(
      config: config,
      repoPath: path,
    );
  }

  @override
  Future<void> clearRepoCache(RepoConfig config) {
    return _cacheLocalDataSource.clearRepoCache(config);
  }

  @override
  Future<Map<String, SyncFileMeta>> readSyncFileMetaMap(RepoConfig config) async {
    final index = await readSyncIndex(config);
    if (index == null) {
      return const {};
    }
    return {for (final file in index.files) file.path: file};
  }

  @override
  Future<void> upsertSyncFileMeta(RepoConfig config, SyncFileMeta meta) async {
    final index = await readSyncIndex(config);
    if (index == null) {
      return;
    }

    final previous = index.files.where((file) => file.path == meta.path);
    final existing = previous.isEmpty ? null : previous.first;
    final nextMeta = SyncFileMeta(
      path: meta.path,
      sha: meta.sha,
      localFilePath: meta.localFilePath,
      updatedAt: meta.updatedAt,
      size: meta.size ?? existing?.size,
    );

    final nextFiles = index.files
        .where((file) => file.path != meta.path)
        .toList()
      ..add(nextMeta);
    nextFiles.sort((left, right) => left.path.compareTo(right.path));

    await writeSyncIndex(
      config,
      SyncIndex(
        repoKey: index.repoKey,
        lastSyncTime: index.lastSyncTime,
        branch: index.branch,
        files: nextFiles,
      ),
    );
  }
}
