import 'package:flutter_test/flutter_test.dart';
import 'package:gitnote/data/models/flat_repo_file.dart';
import 'package:gitnote/data/models/repo_config.dart';
import 'package:gitnote/data/models/sync_file_meta.dart';
import 'package:gitnote/data/models/sync_index.dart';
import 'package:gitnote/data/repositories/github_notes_repository.dart';
import 'package:gitnote/domain/entities/repo_node.dart';
import 'package:gitnote/domain/services/sync_service.dart';

void main() {
  group('SyncService', () {
    test('syncs tree metadata without downloading file contents', () async {
      final repository = _FakeGithubNotesRepository();
      final service = SyncService(repository);

      repository.index = SyncIndex(
        repoKey: _config.repoKey,
        lastSyncTime: DateTime(2026),
        branch: _config.branch,
        files: [
          SyncFileMeta(
            path: 'docs/readme.md',
            sha: 'old-sha',
            localFilePath: '/cache/docs/readme.md',
            updatedAt: DateTime(2026, 1, 1),
            size: 10,
          ),
        ],
      );

      final result = await service.syncWithRemoteFiles(_config, const [
        FlatRepoFile(
          path: 'docs/readme.md',
          sha: 'new-sha',
          type: 'blob',
          size: 20,
        ),
        FlatRepoFile(
          path: 'docs/new.txt',
          sha: 'new-file-sha',
          type: 'blob',
          size: 30,
        ),
      ]);

      expect(result.addedCount, 1);
      expect(result.updatedCount, 1);
      expect(result.failedCount, 0);
      expect(repository.fetchBytesCalls, isEmpty);
      expect(repository.writeBytesCalls, isEmpty);
      expect(repository.deletedPaths, ['docs/readme.md']);

      final metas = {
        for (final file in repository.writtenIndex!.files) file.path: file,
      };
      expect(metas['docs/readme.md']!.sha, 'new-sha');
      expect(metas['docs/readme.md']!.localFilePath, isEmpty);
      expect(metas['docs/readme.md']!.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(0));
      expect(metas['docs/readme.md']!.size, 20);
      expect(metas['docs/new.txt']!.localFilePath, isEmpty);
    });

    test('keeps cached file when remote sha is unchanged', () async {
      final repository = _FakeGithubNotesRepository();
      final service = SyncService(repository);
      final cachedAt = DateTime(2026, 1, 1);

      repository.index = SyncIndex(
        repoKey: _config.repoKey,
        lastSyncTime: DateTime(2026),
        branch: _config.branch,
        files: [
          SyncFileMeta(
            path: 'docs/readme.md',
            sha: 'same-sha',
            localFilePath: '/cache/docs/readme.md',
            updatedAt: cachedAt,
            size: 10,
          ),
        ],
      );

      final result = await service.syncWithRemoteFiles(_config, const [
        FlatRepoFile(
          path: 'docs/readme.md',
          sha: 'same-sha',
          type: 'blob',
          size: 10,
        ),
      ]);

      expect(result.updatedCount, 0);
      expect(repository.deletedPaths, isEmpty);
      final meta = repository.writtenIndex!.files.single;
      expect(meta.localFilePath, '/cache/docs/readme.md');
      expect(meta.updatedAt, cachedAt);
    });
  });
}

const _config = RepoConfig(
  owner: 'owner',
  repo: 'repo',
  branch: 'main',
  token: '',
  rootPath: '',
);

class _FakeGithubNotesRepository implements GithubNotesRepository {
  SyncIndex? index;
  SyncIndex? writtenIndex;
  final deletedPaths = <String>[];
  final fetchBytesCalls = <String>[];
  final writeBytesCalls = <String>[];

  @override
  Future<SyncIndex?> readSyncIndex(RepoConfig config) async => index;

  @override
  Future<void> writeSyncIndex(RepoConfig config, SyncIndex index) async {
    writtenIndex = index;
  }

  @override
  Future<void> deleteCachedMarkdown(RepoConfig config, String path) async {
    deletedPaths.add(path);
  }

  @override
  Future<List<int>> fetchRemoteFileBytes(
    RepoConfig config,
    String path, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    fetchBytesCalls.add(path);
    return const [];
  }

  @override
  Future<String> writeCachedFileBytes(
    RepoConfig config,
    String path,
    List<int> bytes,
  ) async {
    writeBytesCalls.add(path);
    return '/cache/$path';
  }

  @override
  Future<void> clearRepoCache(RepoConfig config) {
    throw UnimplementedError();
  }

  @override
  Future<List<FlatRepoFile>> fetchRemoteFiles(RepoConfig config) {
    throw UnimplementedError();
  }

  @override
  Future<String> fetchRemoteMarkdownContent(RepoConfig config, String path) {
    throw UnimplementedError();
  }

  @override
  Future<RepoNode?> getCachedTree(RepoConfig config) {
    throw UnimplementedError();
  }

  @override
  Future<RepoConfig?> loadConfig() {
    throw UnimplementedError();
  }

  @override
  Future<List<int>?> readCachedFileBytes(RepoConfig config, String path) {
    throw UnimplementedError();
  }

  @override
  Future<String?> readCachedMarkdown(RepoConfig config, String path) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, SyncFileMeta>> readSyncFileMetaMap(RepoConfig config) {
    throw UnimplementedError();
  }

  @override
  Future<String> saveCachedFileToDownloads(RepoConfig config, String path) {
    throw UnimplementedError();
  }

  @override
  Future<void> saveConfig(RepoConfig config) {
    throw UnimplementedError();
  }

  @override
  Future<void> testConnection(RepoConfig config) {
    throw UnimplementedError();
  }

  @override
  Future<void> upsertSyncFileMeta(RepoConfig config, SyncFileMeta meta) {
    throw UnimplementedError();
  }

  @override
  Future<String> writeCachedMarkdown(
    RepoConfig config,
    String path,
    String content,
  ) {
    throw UnimplementedError();
  }
}
