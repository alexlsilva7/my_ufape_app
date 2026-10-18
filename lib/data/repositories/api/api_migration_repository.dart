import '../../../core/models.dart';
import '../../../domain/repositories/migration_repository.dart';
import 'api_repository.dart';

class ApiMigrationRepository extends ApiRepository
    implements MigrationRepository {
  ApiMigrationRepository(super.api, {super.token});
  static const _base = '/api/admin/migrations';
  @override
  Future<JsonMap> inventory() => object('$_base/inventory');
  @override
  Future<JsonMap> validate(JsonMap selection) =>
      object('$_base/validate', method: 'POST', body: selection);
  @override
  Future<JsonMap> start(JsonMap selection) =>
      object('$_base/runs', method: 'POST', body: selection);
  @override
  Future<void> importCourse(String runId, String courseId) async {
    await request(
      '$_base/runs/${segment(runId)}/courses/${segment(courseId)}',
      method: 'POST',
    );
  }

  @override
  Future<JsonMap> get(String runId) => object('$_base/runs/${segment(runId)}');
  @override
  Future<JsonMap> list() => object('$_base/runs');
  @override
  Future<JsonMap> report(String runId) =>
      object('$_base/runs/${segment(runId)}/report');
}
