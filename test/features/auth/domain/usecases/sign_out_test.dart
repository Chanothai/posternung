import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/domain/repositories/auth_repository.dart';
import 'package:posternung/features/auth/domain/usecases/sign_out.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late SignOut usecase;

  setUp(() {
    repository = MockAuthRepository();
    usecase = SignOut(repository);
  });

  test('calls repository.signOut', () async {
    when(() => repository.signOut()).thenAnswer((_) async {});

    await usecase();

    verify(() => repository.signOut()).called(1);
  });

  test('propagates AuthException thrown by the repository', () async {
    when(
      () => repository.signOut(),
    ).thenThrow(const AuthException(code: 'unknown', message: 'nope'));

    expect(() => usecase(), throwsA(isA<AuthException>()));
  });
}
