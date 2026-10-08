enum UserErrorKind {
  invalidAddress,
  connection,
  timeout,
  secureConnection,
  rejected,
  server,
  invalidResponse,
  persistence,
}

/// 可以直接展示给用户的稳定中文错误。
class UserVisibleException implements Exception {
  const UserVisibleException(this.kind, this.message, {this.cause});

  final UserErrorKind kind;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

String userMessageFor(Object? error, {String fallback = '操作失败，请重试'}) {
  return error is UserVisibleException ? error.message : fallback;
}
