import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/path_utils.dart';
import '../../models/flat_repo_file.dart';
import '../../models/repo_config.dart';

class GitHubRemoteDataSource {
  GitHubRemoteDataSource(this._dio);

  final Dio _dio;

  Future<void> testConnection(RepoConfig config) async {
    await fetchMarkdownFiles(config);
  }

  Future<List<FlatRepoFile>> fetchMarkdownFiles(RepoConfig config) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/${config.owner}/${config.repo}/git/trees/${config.branch}',
        queryParameters: const {'recursive': 1},
        options: _buildOptions(config),
      );

      final data = response.data ?? <String, dynamic>{};
      final truncated = data['truncated'] as bool? ?? false;
      if (truncated) {
        // Keep the datasource boundary ready for future "shard by directory" sync.
        throw const RepoTooLargeException();
      }

      final rootPath = PathUtils.normalizeRootPath(config.rootPath);
      final treeItems = data['tree'] as List<dynamic>? ?? const [];
      return treeItems
          .whereType<Map<String, dynamic>>()
          .map(FlatRepoFile.fromJson)
          .where((item) =>
              item.type == 'blob' &&
              PathUtils.isMarkdownFile(item.path) &&
              !item.path.startsWith('.git/') &&
              PathUtils.isInsideRoot(item.path, rootPath))
          .toList();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  Future<String> fetchMarkdownContent(RepoConfig config, String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/${config.owner}/${config.repo}/contents/$path',
        queryParameters: {'ref': config.branch},
        options: _buildOptions(config),
      );

      final data = response.data ?? <String, dynamic>{};
      final encoded = data['content'] as String? ?? '';
      if (encoded.isEmpty) {
        throw const NetworkRequestException('GitHub 返回了空的 Markdown 内容。');
      }

      final normalized = encoded.replaceAll('\n', '');
      return utf8.decode(base64.decode(normalized));
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException {
      throw const NetworkRequestException('GitHub 返回的 Markdown 内容解析失败。');
    }
  }

  Options _buildOptions(RepoConfig config) {
    final headers = <String, String>{
      'Accept': 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    if (config.hasToken) {
      headers['Authorization'] = 'Bearer ${config.token}';
    }

    return Options(headers: headers);
  }

  AppException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      return const NetworkRequestException('GitHub 鉴权失败或权限不足。');
    }
    if (statusCode == 404) {
      return const NetworkRequestException('仓库、分支或文件不存在。');
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const NetworkRequestException('网络请求超时。');
    }
    return NetworkRequestException(
      error.message ?? 'GitHub 请求失败，请稍后重试。',
    );
  }
}
