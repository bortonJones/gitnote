class SyncFileMeta {
  const SyncFileMeta({
    required this.path,
    required this.sha,
    required this.localFilePath,
    required this.updatedAt,
    this.size,
  });

  final String path;
  final String sha;
  final String localFilePath;
  final DateTime updatedAt;
  final int? size;

  bool get isDownloaded => localFilePath.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'sha': sha,
      'localFilePath': localFilePath,
      'updatedAt': updatedAt.toIso8601String(),
      'size': size,
    };
  }

  factory SyncFileMeta.fromJson(Map<String, dynamic> json) {
    return SyncFileMeta(
      path: json['path'] as String? ?? '',
      sha: json['sha'] as String? ?? '',
      localFilePath: json['localFilePath'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      size: json['size'] as int?,
    );
  }
}
