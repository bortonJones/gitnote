import 'sync_file_meta.dart';

class SyncIndex {
  const SyncIndex({
    required this.repoKey,
    required this.lastSyncTime,
    required this.branch,
    required this.files,
  });

  final String repoKey;
  final DateTime? lastSyncTime;
  final String branch;
  final List<SyncFileMeta> files;

  Map<String, dynamic> toJson() {
    return {
      'repoKey': repoKey,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'branch': branch,
      'files': files.map((file) => file.toJson()).toList(),
    };
  }

  factory SyncIndex.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['files'] as List<dynamic>? ?? const [];
    return SyncIndex(
      repoKey: json['repoKey'] as String? ?? '',
      lastSyncTime: DateTime.tryParse(json['lastSyncTime'] as String? ?? ''),
      branch: json['branch'] as String? ?? '',
      files: rawFiles
          .whereType<Map<String, dynamic>>()
          .map(SyncFileMeta.fromJson)
          .toList(),
    );
  }
}
