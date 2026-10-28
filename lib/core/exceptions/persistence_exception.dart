class PersistenceException extends StateError {
  PersistenceException(super.message, {this.key, this.cause});

  final String? key;
  final Object? cause;

  @override
  String toString() => message;
}
