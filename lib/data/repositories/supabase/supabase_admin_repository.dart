import '../../../core/models.dart';
import '../../../domain/repositories/admin_repository.dart';
import 'supabase_data_store.dart';

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this.store);
  final SupabaseDataStore store;
  @override
  Future<JsonMap> configuration() async => {
    'authRequired': true,
    'authConfigured': true,
    'dataSource': 'supabase',
    'supportsExtraction': false,
    'supportsMigration': false,
  };
  @override
  Future<void> validateSession() async {
    if (await store.token?.call() == null) {
      throw StateError('Entre com uma conta administrativa.');
    }
    final result = await store.request(
      'rpc/flutter_is_academic_admin',
      method: 'POST',
      body: {},
    );
    if (result != true) {
      throw StateError('Esta conta não possui permissão administrativa.');
    }
  }
}
