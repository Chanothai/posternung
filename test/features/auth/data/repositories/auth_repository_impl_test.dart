import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  const password = 'hunter2';

  setUp(() {
    dataSource = MockAuthRemoteDataSource();
    repository = AuthRepositoryImpl(dataSource);
    user = MockUser();
    when(() => user.uid).thenReturn('uid-1');
    when(() => user.email).thenReturn(email);
  });

  group('signInWithEmailAndPassword', () {
    test('returns a mapped AuthUser on success', () async {
      when(
        () => dataSource.signIn(email: email, password: password),
      ).thenAnswer((_) async => user);

      final result = await repository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      expect(result.uid, 'uid-1');
      expect(result.email, email);
    });

    test('maps a FirebaseAuthException into an AuthException with the same '
        'code/message', () async {
      when(() => dataSource.signIn(email: email, password: password)).thenThrow(
        FirebaseAuthException(
          code: 'wrong-password',
          message: 'The password is invalid.',
        ),
      );

      expect(
        () => repository.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'wrong-password')
              .having((e) => e.message, 'message', 'The password is invalid.'),
        ),
      );
    });
  });

  group('signUpWithEmailAndPassword', () {
    test('returns a mapped AuthUser on success', () async {
      when(
        () => dataSource.signUp(email: email, password: password),
      ).thenAnswer((_) async => user);

      final result = await repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );

      expect(result.uid, 'uid-1');
      expect(result.email, email);
    });

    test('maps a FirebaseAuthException into an AuthException with the same '
        'code/message', () async {
      when(() => dataSource.signUp(email: email, password: password)).thenThrow(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use.',
        ),
      );

      expect(
        () => repository.signUpWithEmailAndPassword(
          email: email,
          password: password,
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'email-already-in-use',
          ),
        ),
      );
    });
  });

  group('signInWithGoogle', () {
    test('returns a mapped AuthUser on success', () async {
      when(() => dataSource.signInWithGoogle()).thenAnswer((_) async => user);

      final result = await repository.signInWithGoogle();

      expect(result.uid, 'uid-1');
      expect(result.email, email);
    });

    test('maps a user cancellation to AuthCancelledException', () async {
      when(() => dataSource.signInWithGoogle()).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      expect(
        () => repository.signInWithGoogle(),
        throwsA(isA<AuthCancelledException>()),
      );
    });

    test('maps a non-cancel GoogleSignInException to AuthException', () async {
      when(() => dataSource.signInWithGoogle()).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'bad config',
        ),
      );

      expect(
        () => repository.signInWithGoogle(),
        throwsA(isA<AuthException>()),
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
