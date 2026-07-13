import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/domain/repositories/auth_repository.dart';
import 'package:posternung/features/auth/domain/usecases/sign_in_with_email_password.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignInWithEmailPassword usecase;

  setUp(() {
    repository = MockAuthRepository();
    usecase = SignInWithEmailPassword(repository);
  });

  const email = 'user@example.com';
  const password = 'hunter2';
  const user = AuthUser(uid: 'uid-1', email: email);

  test('calls repository.signInWithEmailAndPassword with the given args '
      'and returns the resulting user', () async {
    when(
      () => repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).thenAnswer((_) async => user);

    final result = await usecase(email: email, password: password);

    expect(result, user);
    verify(
      () => repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).called(1);
  });

  test('propagates AuthException thrown by the repository', () async {
    when(
      () => repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).thenThrow(const AuthException(code: 'wrong-password', message: 'nope'));

    expect(
      () => usecase(email: email, password: password),
      throwsA(isA<AuthException>()),
    );
  });
}
