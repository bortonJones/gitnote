import '../../data/models/flat_repo_file.dart';
import '../../domain/entities/repo_node.dart';
import 'path_utils.dart';

class TreeBuilder {
  const TreeBuilder._();

  static RepoNode build({
    required String rootLabel,
    required List<FlatRepoFile> files,
  }) {
    final root = RepoNode.directory(path: '', name: rootLabel, children: []);

    for (final file in files) {
      final segments =
          file.path.split('/').where((segment) => segment.isNotEmpty).toList();
      var current = root;
      var currentPath = '';

      for (var index = 0; index < segments.length; index++) {
        final segment = segments[index];
        currentPath = currentPath.isEmpty ? segment : '$currentPath/$segment';
        final isLast = index == segments.length - 1;
        final nodeType = isLast ? RepoNodeType.file : RepoNodeType.directory;

        final existingIndex = current.children.indexWhere(
          (child) => child.name == segment && child.type == nodeType,
        );

        if (existingIndex >= 0) {
          current = current.children[existingIndex];
          continue;
        }

        final node = isLast
            ? RepoNode.file(
                path: currentPath,
                name: segment,
                sha: file.sha,
              )
            : RepoNode.directory(
                path: currentPath,
                name: segment,
                children: [],
              );

        current.children.add(node);
        current = node;
      }
    }

    _sortNode(root);
    return root;
  }

  static void _sortNode(RepoNode node) {
    node.children.sort((left, right) {
      if (left.type != right.type) {
        return left.type == RepoNodeType.directory ? -1 : 1;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });

    for (final child in node.children) {
      _sortNode(child);
    }
  }

  static List<RepoNode> filterByFileName(RepoNode root, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return root.children;
    }

    final result = <RepoNode>[];
    for (final child in root.children) {
      final filtered = _filterNode(child, normalized);
      if (filtered != null) {
        result.add(filtered);
      }
    }
    return result;
  }

  static RepoNode? findNodeByPath(RepoNode root, String path) {
    if (path.isEmpty) {
      return root;
    }

    for (final child in root.children) {
      final found = _findNodeByPath(child, path);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  static RepoNode? _findNodeByPath(RepoNode node, String path) {
    if (node.path == path) {
      return node;
    }
    for (final child in node.children) {
      final found = _findNodeByPath(child, path);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  static List<RepoNode> directChildrenOfPath(RepoNode root, String path) {
    final node = findNodeByPath(root, path);
    if (node == null) {
      return const [];
    }
    if (node.type == RepoNodeType.file) {
      return const [];
    }
    return node.children;
  }

  static List<RepoNode> searchByTitle(RepoNode root, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    final results = <RepoNode>[];
    void visit(RepoNode node) {
      if (node.path.isNotEmpty && node.name.toLowerCase().contains(normalized)) {
        results.add(node);
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(root);
    return results;
  }

  static String parentDirectoryPath(String path) {
    return PathUtils.directoryName(path);
  }

  static RepoNode? _filterNode(RepoNode node, String query) {
    if (node.type == RepoNodeType.file) {
      return node.name.toLowerCase().contains(query) ? node : null;
    }

    final matches = node.children
        .map((child) => _filterNode(child, query))
        .whereType<RepoNode>()
        .toList();

    if (matches.isEmpty) {
      return null;
    }

    return RepoNode.directory(
      path: node.path,
      name: node.name,
      children: matches,
    );
  }

  static String resolveImagePath({
    required String documentPath,
    required String imagePath,
  }) {
    final docDir = PathUtils.directoryName(documentPath);
    return PathUtils.joinRepoPath(docDir, imagePath);
  }
}
