abstract interface class LocalStorageRepository {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}
