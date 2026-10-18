import '../../core/models.dart';

abstract interface class MigrationRepository {
  Future<JsonMap> inventory();
  Future<JsonMap> validate(JsonMap selection);
  Future<JsonMap> start(JsonMap selection);
  Future<void> importCourse(String runId, String courseId);
  Future<JsonMap> get(String runId);
  Future<JsonMap> list();
  Future<JsonMap> report(String runId);
}
