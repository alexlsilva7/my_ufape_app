abstract interface class LocalStorageRepository {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Stores with a process cache can supply authoritative values for recovery.
abstract interface class ReloadableLocalStorageRepository
    implements LocalStorageRepository {
  Future<Map<String, String>> readPersisted();
}
