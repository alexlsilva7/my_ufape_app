import '../../../core/models.dart';
import '../../../domain/repositories/extraction_repository.dart';
import 'api_repository.dart';

class ApiExtractionRepository extends ApiRepository
    implements ExtractionRepository {
  ApiExtractionRepository(super.api, {super.token});
  @override
  Future<JsonMap> start(JsonMap input) =>
      object('/api/extraction-jobs', method: 'POST', body: input);
  @override
  Future<JsonMap> get(String token) =>
      object('/api/extraction-jobs/${segment(token)}');
  @override
  Future<JsonMap> resume(ExtractionMode mode, JsonMap input) {
    final endpoint = switch (mode) {
      ExtractionMode.tree => 'extract-curriculum-tree',
      ExtractionMode.linear => 'extract-curriculum',
      ExtractionMode.schedule => 'extract-schedule',
    };
    return object('/api/$endpoint', method: 'POST', body: input);
  }
}
