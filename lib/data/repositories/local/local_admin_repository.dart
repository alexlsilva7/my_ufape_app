import '../../../core/models.dart';
import '../../../domain/repositories/admin_repository.dart';

class LocalAdminRepository implements AdminRepository {
  @override
  Future<JsonMap> configuration() async => {
    'authRequired': false,
    'authConfigured': true,
    'dataSource': 'local',
    'supportsExtraction': false,
    'supportsMigration': false,
  };
  @override
  Future<void> validateSession() async {}
}
