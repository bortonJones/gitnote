import '../../core/utils/path_utils.dart';

class RepoConfig {
  const RepoConfig({
    required this.owner,
    required this.repo,
    required this.branch,
    required this.token,
    required this.rootPath,
  });

  final String owner;
  final String repo;
  final String branch;
  final String token;
  final String rootPath;

  String get repoKey => PathUtils.safeRepoKey(owner, repo, branch);

  bool get hasToken => token.trim().isNotEmpty;

  RepoConfig normalized() {
    return RepoConfig(
      owner: owner.trim(),
      repo: repo.trim(),
      branch: branch.trim(),
      token: token.trim(),
      rootPath: PathUtils.normalizeRootPath(rootPath),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'owner': owner,
      'repo': repo,
      'branch': branch,
      'token': token,
      'rootPath': rootPath,
    };
  }

  factory RepoConfig.fromJson(Map<String, dynamic> json) {
    return RepoConfig(
      owner: json['owner'] as String? ?? '',
      repo: json['repo'] as String? ?? '',
      branch: json['branch'] as String? ?? 'main',
      token: json['token'] as String? ?? '',
      rootPath: json['rootPath'] as String? ?? '',
    );
  }
}
