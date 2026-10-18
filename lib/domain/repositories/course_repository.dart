import '../../core/models.dart';

abstract interface class CourseRepository {
  Future<JsonMap> list();
  Future<JsonMap> get(
    String id, {
    String? semester,
    bool strict = false,
    bool academicOnly = false,
  });
  Future<void> save(JsonMap course);
  Future<void> updateMetadata(String id, JsonMap metadata);
  Future<void> updateVisibility(String id, JsonMap visibility);
  Future<void> delete(String id);
}
