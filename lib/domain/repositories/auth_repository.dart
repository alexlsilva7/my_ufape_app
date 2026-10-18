/// Authentication is independent of the provider and never persists credentials.
abstract interface class AuthRepository {
  bool get configured;
  Future<void> signIn(String email, String password);
  Future<String?> token();
  Future<void> signOut();
  void clear();
  void dispose();
}
