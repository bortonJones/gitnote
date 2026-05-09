class SyncResult {
  const SyncResult({
    required this.addedCount,
    required this.updatedCount,
    required this.deletedCount,
    required this.failedCount,
    required this.completedAt,
    this.failures = const [],
  });

  final int addedCount;
  final int updatedCount;
  final int deletedCount;
  final int failedCount;
  final DateTime completedAt;
  final List<String> failures;
}
