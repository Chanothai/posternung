import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

class SignInWithApple {
  SignInWithApple(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call() => _repository.signInWithApple();
}
