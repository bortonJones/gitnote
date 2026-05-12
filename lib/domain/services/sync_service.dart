import '../../data/models/repo_config.dart';
import '../../data/models/sync_file_meta.dart';
import '../../data/models/sync_index.dart';
import '../../data/models/flat_repo_file.dart';
import '../../domain/entities/sync_result.dart';
import '../../data/repositories/github_notes_repository.dart';

class SyncService {
  SyncService(this._repository);

  final GithubNotesRepository _repository;

  Future<SyncResult> sync(RepoConfig config) async {
    final remoteFiles = await _repository.fetchRemoteFiles(config);
    return syncWithRemoteFiles(config, remoteFiles);
  }

  Future<SyncResult> syncWithRemoteFiles(
    RepoConfig config,
    List<FlatRepoFile> remoteFiles,
  ) async {
    final index = await _repository.readSyncIndex(config);
    final previousFiles = {for (final file in index?.files ?? []) file.path: file};
    final remoteFileMap = {for (final file in remoteFiles) file.path: file};

    final nextMetas = <SyncFileMeta>[];
    final failures = <String>[];
    var addedCount = 0;
    var updatedCount = 0;
    var deletedCount = 0;

    for (final remote in remoteFiles) {
      final existing = previousFiles[remote.path];
      final isChanged = existing != null && existing.sha != remote.sha;

      if (existing == null) {
        addedCount++;
      } else if (isChanged) {
        updatedCount++;
        if (existing.isDownloaded) {
          try {
            await _repository.deleteCachedMarkdown(config, remote.path);
          } catch (error) {
            failures.add('${remote.path}: $error');
          }
        }
      }

      nextMetas.add(
        SyncFileMeta(
          path: remote.path,
          sha: remote.sha,
          localFilePath: isChanged ? '' : existing?.localFilePath ?? '',
          updatedAt: isChanged
              ? DateTime.fromMillisecondsSinceEpoch(0)
              : existing?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          size: remote.size,
        ),
      );
    }

    for (final entry in previousFiles.entries) {
      if (remoteFileMap.containsKey(entry.key)) {
        continue;
      }
      await _repository.deleteCachedMarkdown(config, entry.key);
      deletedCount++;
    }

    final syncedAt = DateTime.now();
    final nextIndex = SyncIndex(
      repoKey: config.repoKey,
      lastSyncTime: syncedAt,
      branch: config.branch,
      files: nextMetas,
    );
    await _repository.writeSyncIndex(config, nextIndex);

    return SyncResult(
      addedCount: addedCount,
      updatedCount: updatedCount,
      deletedCount: deletedCount,
      failedCount: failures.length,
      completedAt: syncedAt,
      failures: failures,
    );
  }
}
