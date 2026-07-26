import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_cancelled_exception.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:posternung/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockUser extends Mock implements User {}

void main() {
  late MockAuthRemoteDataSource dataSource;
  late AuthRepositoryImpl repository;
  late MockUser user;

  const email = 'user@example.com';

  setUp(() {
    dataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(dataSource);
    user = MockUser();
    when(() => user.uid).thenReturn('uid-1');
    when(() => user.email).thenReturn(email);
  });

  group('signOut', () {
    test('calls dataSource.signOut', () async {
      when(() => dataSource.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => dataSource.signOut()).called(1);
    });

    test('maps a FirebaseAuthException into an AuthException with the same '
        'code/message', () async {
      when(() => dataSource.signOut()).thenThrow(
        FirebaseAuthException(
          code: 'network-request-failed',
          message: 'no network',
        ),
      );

      expect(
        () => repository.signOut(),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'network-request-failed')
              .having((e) => e.message, 'message', 'no network'),
        ),
      );
    });
  });

  group('signInWithApple', () {
    test('returns a mapped AuthUser on success', () async {
      when(() => dataSource.signInWithApple()).thenAnswer((_) async => user);

      final result = await repository.signInWithApple();

      expect(result.uid, 'uid-1');
      expect(result.email, email);
    });

    test('maps a user cancellation to AuthCancelledException', () async {
      when(() => dataSource.signInWithApple()).thenThrow(
        const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'User canceled authorization',
        ),
      );

      expect(
        () => repository.signInWithApple(),
        throwsA(isA<AuthCancelledException>()),
      );
    });

    test(
      'maps a non-cancel Apple authorization error to AuthException',
      () async {
        when(() => dataSource.signInWithApple()).thenThrow(
          const SignInWithAppleAuthorizationException(
            code: AuthorizationErrorCode.failed,
            message: 'failed',
          ),
        );

        expect(
          () => repository.signInWithApple(),
          throwsA(isA<AuthException>()),
        );
      },
    );
  });
}
