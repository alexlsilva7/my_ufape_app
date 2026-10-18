import '../../../domain/repositories/auth_repository.dart';

/// Local administration edits only this device; it grants no remote authority.
class LocalAuthRepository implements AuthRepository {
  @override
  bool get configured => true;
  @override
  Future<void> signIn(String email, String password) async {
    throw UnsupportedError('O modo local não utiliza login.');
  }

  @override
  Future<String?> token() async => null;
  @override
  Future<void> signOut() async {}
  @override
  void clear() {}
  @override
  void dispose() {}
}
