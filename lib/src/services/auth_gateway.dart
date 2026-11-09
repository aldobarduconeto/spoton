/// Authentication operations used by the login UI, injectable in widget tests.
abstract interface class AuthGateway {
  bool get isAvailable;
  bool get supportsGoogle;
  Future<void> signIn(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signInGoogle();
}
