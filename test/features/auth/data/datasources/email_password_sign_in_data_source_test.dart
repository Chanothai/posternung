import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/data/datasources/email_password_sign_in_data_source.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth firebaseAuth;
  late EmailPasswordSignInDataSourceImpl dataSource;

  setUp(() {
    firebaseAuth = MockFirebaseAuth();
    dataSource = EmailPasswordSignInDataSourceImpl(firebaseAuth);
  });

  group('signIn', () {
    test('returns the Firebase ID token on success', () async {
      final credential = MockUserCredential();
      final user = MockUser();
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'a@b.com',
          password: 'pw',
        ),
      ).thenAnswer((_) async => credential);
      when(() => credential.user).thenReturn(user);
      when(() => user.getIdToken()).thenAnswer((_) async => 'id-tok');

      final result = await dataSource.signIn(email: 'a@b.com', password: 'pw');

      expect(result, 'id-tok');
    });

    test(
      'throws missing_id_token when getIdToken resolves to an empty '
      'string — not just null (same trap as PhoneSignInDataSource)',
      () async {
        final credential = MockUserCredential();
        final user = MockUser();
        when(
          () => firebaseAuth.signInWithEmailAndPassword(
            email: 'a@b.com',
            password: 'pw',
          ),
        ).thenAnswer((_) async => credential);
        when(() => credential.user).thenReturn(user);
        when(() => user.getIdToken()).thenAnswer((_) async => '');

        expect(
          () => dataSource.signIn(email: 'a@b.com', password: 'pw'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              'missing_id_token',
            ),
          ),
        );
      },
    );

    test('maps a FirebaseAuthException (e.g. wrong-password) to an '
        'AuthException carrying the same code', () async {
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'a@b.com',
          password: 'wrong',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'wrong-password',
          message: 'The password is invalid.',
        ),
      );

      expect(
        () => dataSource.signIn(email: 'a@b.com', password: 'wrong'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'wrong-password')
              .having((e) => e.displayMessage, 'displayMessage', isNull),
        ),
      );
    });

    test('wraps a non-FirebaseAuthException failure into a fixed code — '
        'ADR-0017 D6 forbids composing it from runtimeType, so the real type '
        'lands in debugDetail instead', () async {
      when(
        () => firebaseAuth.signInWithEmailAndPassword(
          email: 'a@b.com',
          password: 'pw',
        ),
      ).thenThrow(PlatformException(code: 'channel-error', message: 'boom'));

      expect(
        () => dataSource.signIn(email: 'a@b.com', password: 'pw'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.code, 'code', 'email_password_unexpected')
              .having(
                (e) => e.debugDetail,
                'debugDetail',
                contains('PlatformException'),
              ),
        ),
      );
    });
  });

  group('register', () {
    test('returns the Firebase ID token on success', () async {
      final credential = MockUserCredential();
      final user = MockUser();
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: 'new@b.com',
          password: 'pw',
        ),
      ).thenAnswer((_) async => credential);
      when(() => credential.user).thenReturn(user);
      when(() => user.getIdToken()).thenAnswer((_) async => 'id-tok');

      final result = await dataSource.register(
        email: 'new@b.com',
        password: 'pw',
      );

      expect(result, 'id-tok');
    });

    test('maps email-already-in-use through unchanged', () async {
      when(
        () => firebaseAuth.createUserWithEmailAndPassword(
          email: 'taken@b.com',
          password: 'pw',
        ),
      ).thenThrow(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The email address is already in use.',
        ),
      );

      expect(
        () => dataSource.register(email: 'taken@b.com', password: 'pw'),
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

  group('sendEmailVerification', () {
    test('sends the verification email for the current user', () async {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.sendEmailVerification()).thenAnswer((_) async {});

      await dataSource.sendEmailVerification();

      verify(() => user.sendEmailVerification()).called(1);
    });

    test('throws no_current_user when nobody is signed in — defensive, '
        'should not happen in the flow this exists for', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      expect(
        () => dataSource.sendEmailVerification(),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'no_current_user'),
        ),
      );
    });

    test('maps a FirebaseAuthException (e.g. too-many-requests)', () async {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.sendEmailVerification()).thenThrow(
        FirebaseAuthException(code: 'too-many-requests', message: 'slow down'),
      );

      expect(
        () => dataSource.sendEmailVerification(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'too-many-requests',
          ),
        ),
      );
    });
  });

  group('reloadAndCheckEmailVerified', () {
    test('returns true once the (reloaded) current user is verified', () async {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.reload()).thenAnswer((_) async {});
      when(() => user.emailVerified).thenReturn(true);

      final verified = await dataSource.reloadAndCheckEmailVerified();

      expect(verified, isTrue);
      verify(() => user.reload()).called(1);
    });

    test('returns false when still not verified', () async {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.reload()).thenAnswer((_) async {});
      when(() => user.emailVerified).thenReturn(false);

      final verified = await dataSource.reloadAndCheckEmailVerified();

      expect(verified, isFalse);
    });

    test('throws no_current_user when nobody is signed in', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      expect(
        () => dataSource.reloadAndCheckEmailVerified(),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'no_current_user'),
        ),
      );
    });
  });

  group('currentIdToken', () {
    test('force-refreshes and returns the token', () async {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.getIdToken(true)).thenAnswer((_) async => 'fresh-tok');

      final token = await dataSource.currentIdToken();

      expect(token, 'fresh-tok');
      verify(() => user.getIdToken(true)).called(1);
    });

    test('throws missing_id_token on an empty token, same trap as '
        'signIn/register', () async {
      final user = MockUser();
      when(() => firebaseAuth.currentUser).thenReturn(user);
      when(() => user.getIdToken(true)).thenAnswer((_) async => '');

      expect(
        () => dataSource.currentIdToken(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'missing_id_token',
          ),
        ),
      );
    });

    test('throws no_current_user when nobody is signed in', () async {
      when(() => firebaseAuth.currentUser).thenReturn(null);

      expect(
        () => dataSource.currentIdToken(),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'no_current_user'),
        ),
      );
    });
  });
}
