import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/domain/repositories/auth_repository.dart';
import 'package:posternung/features/auth/domain/usecases/sign_up_with_email_password.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignUpWithEmailPassword usecase;

  setUp(() {
    repository = MockAuthRepository();
    usecase = SignUpWithEmailPassword(repository);
  });

  const email = 'new@example.com';
  const password = 'hunter2';
  const user = AuthUser(uid: 'uid-2', email: email);

  test('calls repository.signUpWithEmailAndPassword with the given args '
      'and returns the resulting user', () async {
    when(
      () => repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).thenAnswer((_) async => user);

    final result = await usecase(email: email, password: password);

    expect(result, user);
    verify(
      () => repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).called(1);
  });

  test('propagates AuthException thrown by the repository', () async {
    when(
      () => repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
      ),
    ).thenThrow(
      const AuthException(code: 'email-already-in-use', message: 'taken'),
    );

    expect(
      () => usecase(email: email, password: password),
      throwsA(isA<AuthException>()),
    );
  });
}
