enum RepoNodeType { file, directory }

class RepoNode {
  RepoNode({
    required this.path,
    required this.name,
    required this.type,
    this.sha,
    this.size,
    List<RepoNode>? children,
  }) : children = children ?? <RepoNode>[];

  factory RepoNode.file({
    required String path,
    required String name,
    String? sha,
    int? size,
  }) {
    return RepoNode(
      path: path,
      name: name,
      type: RepoNodeType.file,
      sha: sha,
      size: size,
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
  final int? size;
  final List<RepoNode> children;
}
