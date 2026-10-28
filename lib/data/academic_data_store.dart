import '../core/models.dart';

/// Rows retain the same JSON documents in local storage and Supabase.
abstract interface class AcademicDataStore {
  Future<List<JsonMap>> select(
    String table, {
    Map<String, String> filters = const {},
    List<String>? columns,
  });
  Future<void> upsert(String table, JsonMap row);
  Future<void> delete(String table, Map<String, String> filters);
  Future<void> writeCourse(String courseId, List<AcademicMutation> changes);
}

/// Optional metadata-only listing. Bundled course metadata can be read without
/// materializing every academic document on the device.
abstract interface class AcademicCourseMetadataStore {
  Future<List<JsonMap>> listCourseMetadata();
}

class AcademicMutation {
  const AcademicMutation.upsert(
    this.table,
    JsonMap data, {
    this.requireExisting = false,
  }) : row = data,
       filters = const {};
  const AcademicMutation.delete(this.table, this.filters)
    : row = null,
      requireExisting = false;
  final String table;
  final JsonMap? row;
  final Map<String, String> filters;
  final bool requireExisting;
  JsonMap toJson() => {
    'table': table,
    'action': row == null ? 'delete' : 'upsert',
    if (row != null) 'row': row else 'filters': filters,
    if (requireExisting) 'require_existing': true,
  };
}
