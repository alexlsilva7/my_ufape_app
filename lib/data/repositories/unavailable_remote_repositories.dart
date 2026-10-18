import '../../core/models.dart';
import '../../domain/repositories/extraction_repository.dart';
import '../../domain/repositories/migration_repository.dart';

class OfflineExtractionRepository implements ExtractionRepository {
  Never _unavailable() => throw UnsupportedError(
    'A extração por IA exige um serviço remoto. No modo local, importe o JSON em Importar e extrair.',
  );
  @override
  Future<JsonMap> start(JsonMap input) async => _unavailable();
  @override
  Future<JsonMap> get(String token) async => _unavailable();
  @override
  Future<JsonMap> resume(ExtractionMode mode, JsonMap input) async =>
      _unavailable();
}

class UnavailableMigrationRepository implements MigrationRepository {
  Never _unavailable() => throw UnsupportedError(
    'A migração de arquivos do servidor é exclusiva do modo API. Importe o JSON diretamente no modo local ou Supabase.',
  );
  @override
  Future<JsonMap> inventory() async => _unavailable();
  @override
  Future<JsonMap> validate(JsonMap selection) async => _unavailable();
  @override
  Future<JsonMap> start(JsonMap selection) async => _unavailable();
  @override
  Future<void> importCourse(String runId, String courseId) async =>
      _unavailable();
  @override
  Future<JsonMap> get(String runId) async => _unavailable();
  @override
  Future<JsonMap> list() async => _unavailable();
  @override
  Future<JsonMap> report(String runId) async => _unavailable();
}
