import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_cancelled_exception.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/domain/repositories/auth_repository.dart';
import 'package:posternung/features/auth/domain/usecases/sign_in_with_google.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignInWithGoogle usecase;

  setUp(() {
    repository = MockAuthRepository();
    usecase = SignInWithGoogle(repository);
  });

  const user = AuthUser(uid: 'uid-1', email: 'user@example.com');

  test(
    'calls repository.signInWithGoogle and returns the resulting user',
    () async {
      when(() => repository.signInWithGoogle()).thenAnswer((_) async => user);

      final result = await usecase();

      expect(result, user);
      verify(() => repository.signInWithGoogle()).called(1);
    },
  );

  test('propagates AuthException thrown by the repository', () async {
    when(
      () => repository.signInWithGoogle(),
    ).thenThrow(const AuthException(code: 'network', message: 'no network'));

    expect(() => usecase(), throwsA(isA<AuthException>()));
  });

  test('propagates AuthCancelledException thrown by the repository', () async {
    when(
      () => repository.signInWithGoogle(),
    ).thenThrow(const AuthCancelledException());

    expect(() => usecase(), throwsA(isA<AuthCancelledException>()));
  });
}
