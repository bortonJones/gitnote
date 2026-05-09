enum RepoNodeType { file, directory }

class RepoNode {
  RepoNode({
    required this.path,
    required this.name,
    required this.type,
    this.sha,
    List<RepoNode>? children,
  }) : children = children ?? <RepoNode>[];

  factory RepoNode.file({
    required String path,
    required String name,
    String? sha,
  }) {
    return RepoNode(
      path: path,
      name: name,
      type: RepoNodeType.file,
      sha: sha,
    );
  }

  factory RepoNode.directory({
    required String path,
    required String name,
    List<RepoNode>? children,
  }) {
    return RepoNode(
      path: path,
      name: name,
      type: RepoNodeType.directory,
      children: children,
    );
  }

  final String path;
  final String name;
  final RepoNodeType type;
  final String? sha;
  final List<RepoNode> children;
}
