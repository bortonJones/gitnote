class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ConfigNotFoundException extends AppException {
  const ConfigNotFoundException() : super('尚未配置 GitHub 仓库。');
}

class RepoTooLargeException extends AppException {
  const RepoTooLargeException()
      : super('当前仓库目录树过大，首版暂不支持该仓库。');
}

class NetworkRequestException extends AppException {
  const NetworkRequestException(super.message);
}

class LocalStorageException extends AppException {
  const LocalStorageException(super.message);
}
