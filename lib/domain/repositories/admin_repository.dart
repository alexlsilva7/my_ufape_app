import '../../core/models.dart';

abstract interface class AdminRepository {
  Future<JsonMap> configuration();
  Future<void> validateSession();
}
