import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_cancelled_exception.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/domain/repositories/auth_repository.dart';
import 'package:posternung/features/auth/domain/usecases/sign_in_with_apple.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignInWithApple usecase;

  setUp(() {
    repository = MockAuthRepository();
    usecase = SignInWithApple(repository);
  });

  const user = AuthUser(uid: 'uid-1', email: 'user@example.com');

  test(
    'calls repository.signInWithApple and returns the resulting user',
    () async {
      when(() => repository.signInWithApple()).thenAnswer((_) async => user);

      final result = await usecase();

      expect(result, user);
      verify(() => repository.signInWithApple()).called(1);
    },
  );

  test('propagates AuthException thrown by the repository', () async {
    when(
      () => repository.signInWithApple(),
    ).thenThrow(const AuthException(code: 'invalid', message: 'bad token'));

    expect(() => usecase(), throwsA(isA<AuthException>()));
  });

  test('propagates AuthCancelledException thrown by the repository', () async {
    when(
      () => repository.signInWithApple(),
    ).thenThrow(const AuthCancelledException());

    expect(() => usecase(), throwsA(isA<AuthCancelledException>()));
  });
}
