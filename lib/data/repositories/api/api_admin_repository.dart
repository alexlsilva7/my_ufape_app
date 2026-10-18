import '../../../core/models.dart';
import '../../../domain/repositories/admin_repository.dart';
import 'api_repository.dart';

class ApiAdminRepository extends ApiRepository implements AdminRepository {
  ApiAdminRepository(super.api, {super.token});
  @override
  Future<JsonMap> configuration() => object('/api/admin/config');
  @override
  Future<void> validateSession() async {
    await request('/api/admin/session');
  }
}
