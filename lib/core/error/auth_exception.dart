/// Domain-level exception for auth failures. Data-layer repositories catch
/// SDK-specific exceptions (e.g. `FirebaseAuthException`) and rethrow this
/// instead, so nothing above the repository boundary depends on Firebase.
class AuthException implements Exception {
  const AuthException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}
