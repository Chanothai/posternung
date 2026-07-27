import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/data/datasources/phone_sign_in_data_source.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth firebaseAuth;
  late PhoneSignInDataSourceImpl dataSource;

  setUpAll(() {
    registerFallbackValue(
      PhoneAuthProvider.credential(verificationId: 'v', smsCode: '123456'),
    );
  });

  setUp(() {
    firebaseAuth = MockFirebaseAuth();
    dataSource = PhoneSignInDataSourceImpl(firebaseAuth);
  });

  group('confirmCode', () {
    test('throws missing_id_token when getIdToken resolves to an empty string '
        '— not just null. This is the exact regression that let an empty '
        'id_token reach the backend as {"id_token": ""} and 422 with no '
        'diagnosable reason', () async {
      final credential = MockUserCredential();
      final user = MockUser();
      when(
        () => firebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => credential);
      when(() => credential.user).thenReturn(user);
      when(() => user.getIdToken()).thenAnswer((_) async => '');

      expect(
        () => dataSource.confirmCode(verificationId: 'v', smsCode: '123456'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'missing_id_token',
          ),
        ),
      );
    });

    test('maps a FirebaseAuthException (e.g. a wrong or expired code) to an '
        'AuthException carrying the same code', () async {
      when(() => firebaseAuth.signInWithCredential(any())).thenThrow(
        FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'The SMS code has expired.',
        ),
      );

      expect(
        () => dataSource.confirmCode(verificationId: 'v', smsCode: '000000'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'invalid-verification-code',
          ),
        ),
      );
    });

    test(
      'wraps a non-FirebaseAuthException failure (a PlatformException from '
      "the plugin channel, say) into an AuthException that names the real "
      'type — this used to escape uncaught and reach the login/OTP screen '
      'as a code-less generic error with no way to tell what actually broke',
      () async {
        when(
          () => firebaseAuth.signInWithCredential(any()),
        ).thenThrow(PlatformException(code: 'channel-error', message: 'boom'));

        expect(
          () => dataSource.confirmCode(verificationId: 'v', smsCode: '123456'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.code,
              'code',
              contains('PlatformException'),
            ),
          ),
        );
      },
    );
  });
}
