class FlatRepoFile {
  const FlatRepoFile({
    required this.path,
    required this.sha,
    required this.type,
    this.size,
  });

  final String path;
  final String sha;
  final String type;
  final int? size;

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'sha': sha,
      'type': type,
      'size': size,
    };
  }

  factory FlatRepoFile.fromJson(Map<String, dynamic> json) {
    return FlatRepoFile(
      path: json['path'] as String? ?? '',
      sha: json['sha'] as String? ?? '',
      type: json['type'] as String? ?? '',
      size: json['size'] as int?,
    );
  }
}
