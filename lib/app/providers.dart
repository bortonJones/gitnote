import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/markdown_utils.dart';
import '../data/datasources/local/cache_local_data_source.dart';
import '../data/datasources/local/settings_local_data_source.dart';
import '../data/datasources/remote/github_remote_data_source.dart';
import '../data/models/repo_config.dart';
import '../data/models/sync_file_meta.dart';
import '../data/models/sync_index.dart';
import '../data/repositories/github_notes_repository.dart';
import '../domain/entities/repo_node.dart';
import '../domain/entities/sync_result.dart';
import '../domain/services/config_setup_service.dart';
import '../domain/services/sync_service.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main scope.');
});

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
    ),
  );
});

final settingsLocalDataSourceProvider = Provider<SettingsLocalDataSource>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsLocalDataSource(prefs);
});

final cacheLocalDataSourceProvider = Provider<CacheLocalDataSource>((ref) {
  return CacheLocalDataSource();
});

final gitHubRemoteDataSourceProvider = Provider<GitHubRemoteDataSource>((ref) {
  return GitHubRemoteDataSource(ref.watch(dioProvider));
});

final notesRepositoryProvider = Provider<GithubNotesRepository>((ref) {
  return GithubNotesRepositoryImpl(
    settingsLocalDataSource: ref.watch(settingsLocalDataSourceProvider),
    cacheLocalDataSource: ref.watch(cacheLocalDataSourceProvider),
    remoteDataSource: ref.watch(gitHubRemoteDataSourceProvider),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(notesRepositoryProvider));
});

final configSetupServiceProvider = Provider<ConfigSetupService>((ref) {
  return ConfigSetupService(
    repository: ref.watch(notesRepositoryProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

class RepoConfigController extends AsyncNotifier<RepoConfig?> {
  @override
  Future<RepoConfig?> build() async {
    return ref.read(notesRepositoryProvider).loadConfig();
  }

  Future<void> save(RepoConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final normalized = config.normalized();
      await ref.read(notesRepositoryProvider).saveConfig(normalized);
      return normalized;
    });
  }
}

final repoConfigControllerProvider =
    AsyncNotifierProvider<RepoConfigController, RepoConfig?>(
  RepoConfigController.new,
);

class SyncController extends AsyncNotifier<SyncResult?> {
  @override
  Future<SyncResult?> build() async {
    return null;
  }

  Future<SyncResult> syncNow() async {
    final config = await ref.read(repoConfigControllerProvider.future);
    if (config == null) {
      throw const ConfigNotFoundException();
    }

    state = const AsyncLoading();
    final result = await ref.read(syncServiceProvider).sync(config);
    state = AsyncData(result);
    ref.invalidate(notesTreeProvider);
    ref.invalidate(syncIndexProvider);
    ref.invalidate(syncFileMetaMapProvider);
    ref.invalidate(lastSyncLabelProvider);
    return result;
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncResult?>(SyncController.new);

final syncIndexProvider = FutureProvider<SyncIndex?>((ref) async {
  ref.watch(syncControllerProvider);
  final config = await ref.watch(repoConfigControllerProvider.future);
  if (config == null) {
    return null;
  }
  return ref.watch(notesRepositoryProvider).readSyncIndex(config);
});

final syncFileMetaMapProvider =
    FutureProvider<Map<String, SyncFileMeta>>((ref) async {
  final index = await ref.watch(syncIndexProvider.future);
  if (index == null) {
    return const {};
  }
  return {for (final file in index.files) file.path: file};
});

final notesTreeProvider = FutureProvider<RepoNode?>((ref) async {
  ref.watch(syncControllerProvider);
  final config = await ref.watch(repoConfigControllerProvider.future);
  if (config == null) {
    return null;
  }
  return ref.watch(notesRepositoryProvider).getCachedTree(config);
});

final markdownReloadTickProvider =
    StateProvider.family<int, String>((ref, path) => 0);

final markdownContentProvider =
    FutureProvider.family<String, String>((ref, path) async {
  final config = await ref.watch(repoConfigControllerProvider.future);
  if (config == null) {
    throw const ConfigNotFoundException();
  }

  final repo = ref.watch(notesRepositoryProvider);
  final tick = ref.watch(markdownReloadTickProvider(path));
  final forceRefresh = tick > 0;

  if (!forceRefresh) {
    final cached = await repo.readCachedMarkdown(config, path);
    if (cached != null) {
      return MarkdownUtils.prepareForDisplay(
        markdown: cached,
        config: config,
        documentPath: path,
      );
    }
  }

  final content = await repo.fetchRemoteMarkdownContent(config, path);
  final localFilePath = await repo.writeCachedMarkdown(config, path, content);
  final metaMap = await ref.read(syncFileMetaMapProvider.future);
  final existingMeta = metaMap[path];
  if (existingMeta != null) {
    await repo.upsertSyncFileMeta(
      config,
      SyncFileMeta(
        path: existingMeta.path,
        sha: existingMeta.sha,
        localFilePath: localFilePath,
        updatedAt: DateTime.now(),
      ),
    );
    ref.invalidate(syncIndexProvider);
    ref.invalidate(syncFileMetaMapProvider);
    ref.invalidate(notesTreeProvider);
    ref.invalidate(lastSyncLabelProvider);
  }
  if (forceRefresh) {
    ref.read(markdownReloadTickProvider(path).notifier).state = 0;
  }
  return MarkdownUtils.prepareForDisplay(
    markdown: content,
    config: config,
    documentPath: path,
  );
});

final lastSyncLabelProvider = FutureProvider<String?>((ref) async {
  final index = await ref.watch(syncIndexProvider.future);
  final time = index?.lastSyncTime;
  if (time == null) {
    return null;
  }
  return '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')} '
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
});
