/// The authenticated user, as far as the rest of the app needs to know.
/// Deliberately doesn't mirror Firebase's `User` — no Flutter/Firebase
/// imports in domain code.
class AuthUser {
  const AuthUser({required this.uid, this.email});

  final String uid;
  final String? email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);
}
