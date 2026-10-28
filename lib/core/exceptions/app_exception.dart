/// A boundary failure retains the original exception and its throw site.
class AppException implements Exception {
  const AppException(
    this.message, {
    required this.cause,
    required this.stackTrace,
  });
  final String message;
  final Object cause;
  final StackTrace stackTrace;
  @override
  String toString() => message;
}
