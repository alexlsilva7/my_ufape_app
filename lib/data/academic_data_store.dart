import '../core/models.dart';

/// Rows retain the same JSON documents in local storage and Supabase.
abstract interface class AcademicDataStore {
  Future<List<JsonMap>> select(
    String table, {
    Map<String, String> filters = const {},
  });
  Future<void> upsert(String table, JsonMap row);
  Future<void> delete(String table, Map<String, String> filters);
}
