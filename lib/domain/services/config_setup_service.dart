import '../../data/models/flat_repo_file.dart';
import '../../data/models/repo_config.dart';
import '../../data/repositories/github_notes_repository.dart';
import '../entities/sync_result.dart';
import 'sync_service.dart';

enum ConfigSetupStep {
  testConnection,
  checkRepoChanged,
  clearLocalCache,
  downloadDirectoryTree,
  completeTreeSync,
}

enum ConfigSetupStepStatus { undo, pending, done, failed }

class ConfigSetupStepUpdate {
  const ConfigSetupStepUpdate({
    required this.step,
    required this.status,
    this.message,
  });

  final ConfigSetupStep step;
  final ConfigSetupStepStatus status;
  final String? message;
}

class ConfigSetupResult {
  const ConfigSetupResult({
    required this.config,
    required this.syncResult,
    required this.repoChanged,
  });

  final RepoConfig config;
  final SyncResult syncResult;
  final bool repoChanged;
}

class ConfigSetupService {
  const ConfigSetupService({
    required GithubNotesRepository repository,
    required SyncService syncService,
  })  : _repository = repository,
        _syncService = syncService;

  final GithubNotesRepository _repository;
  final SyncService _syncService;

  Future<ConfigSetupResult> applyConfig({
    required RepoConfig newConfig,
    required RepoConfig? currentConfig,
    required Future<void> Function(ConfigSetupStepUpdate update) onStepUpdate,
  }) async {
    await _runStep(
      ConfigSetupStep.testConnection,
      onStepUpdate,
      () => _repository.testConnection(newConfig),
    );

    var repoChanged = false;
    await _runStep(
      ConfigSetupStep.checkRepoChanged,
      onStepUpdate,
      () async {
        repoChanged = _isRepoChanged(currentConfig, newConfig);
      },
    );

    await _runStep(
      ConfigSetupStep.clearLocalCache,
      onStepUpdate,
      () async {
        if (repoChanged && currentConfig != null) {
          await _repository.clearRepoCache(currentConfig);
        }
      },
    );

    late List<FlatRepoFile> remoteFiles;
    await _runStep(
      ConfigSetupStep.downloadDirectoryTree,
      onStepUpdate,
      () async {
        remoteFiles = await _repository.fetchRemoteMarkdownFiles(newConfig);
      },
    );

    late SyncResult syncResult;
    await _runStep(
      ConfigSetupStep.completeTreeSync,
      onStepUpdate,
      () async {
        syncResult = await _syncService.syncWithRemoteFiles(
          newConfig,
          remoteFiles,
        );
      },
    );

    return ConfigSetupResult(
      config: newConfig,
      syncResult: syncResult,
      repoChanged: repoChanged,
    );
  }

  bool _isRepoChanged(RepoConfig? currentConfig, RepoConfig newConfig) {
    if (currentConfig == null) {
      return false;
    }
    return currentConfig.owner != newConfig.owner ||
        currentConfig.repo != newConfig.repo ||
        currentConfig.branch != newConfig.branch ||
        currentConfig.rootPath != newConfig.rootPath;
  }

  Future<void> _runStep(
    ConfigSetupStep step,
    Future<void> Function(ConfigSetupStepUpdate update) onStepUpdate,
    Future<void> Function() action,
  ) async {
    await onStepUpdate(
      ConfigSetupStepUpdate(
        step: step,
        status: ConfigSetupStepStatus.pending,
      ),
    );

    try {
      await action();
      await onStepUpdate(
        ConfigSetupStepUpdate(
          step: step,
          status: ConfigSetupStepStatus.done,
        ),
      );
    } catch (error) {
      await onStepUpdate(
        ConfigSetupStepUpdate(
          step: step,
          status: ConfigSetupStepStatus.failed,
          message: error.toString(),
        ),
      );
      rethrow;
    }
  }
}
