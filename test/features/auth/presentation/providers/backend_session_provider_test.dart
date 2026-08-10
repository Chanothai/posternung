import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/network/token_storage.dart';
import 'package:posternung/features/auth/data/datasources/backend_auth_data_source.dart';
import 'package:posternung/features/auth/data/datasources/email_password_sign_in_data_source.dart';
import 'package:posternung/features/auth/data/datasources/google_sign_in_data_source.dart';
import 'package:posternung/features/auth/data/models/backend_user.dart';
import 'package:posternung/features/auth/data/models/token_response.dart';
import 'package:posternung/features/auth/presentation/providers/backend_session_provider.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

class MockGoogleSignInDataSource extends Mock
    implements GoogleSignInDataSource {}

class MockEmailPasswordSignInDataSource extends Mock
    implements EmailPasswordSignInDataSource {}

class MockBackendAuthDataSource extends Mock implements BackendAuthDataSource {}

BackendUser _user() => BackendUser(
  id: 'u1',
  email: 'a@b.com',
  phone: null,
  isVerified: true,
  createdAt: DateTime(2024),
);

void main() {
  late MockTokenStorage storage;
  late MockGoogleSignInDataSource google;
  late MockEmailPasswordSignInDataSource emailPassword;
  late MockBackendAuthDataSource backend;

  setUp(() {
    storage = MockTokenStorage();
    google = MockGoogleSignInDataSource();
    emailPassword = MockEmailPasswordSignInDataSource();
    backend = MockBackendAuthDataSource();
    when(
      () => storage.save(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
    when(() => storage.clear()).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        googleSignInDataSourceProvider.overrideWithValue(google),
        emailPasswordSignInDataSourceProvider.overrideWithValue(emailPassword),
        backendAuthDataSourceProvider.overrideWithValue(backend),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('build / restore', () {
    test('returns null when no access token is stored', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => null);

      final user = await makeContainer().read(backendSessionProvider.future);

      expect(user, isNull);
    });

    test('validates a stored token via /auth/me', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => 'a');
      when(() => backend.getMe('a')).thenAnswer((_) async => _user());

      final user = await makeContainer().read(backendSessionProvider.future);

      expect(user!.uid, 'u1');
    });

    test('refreshes once on 401, then returns the user', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => 'expired');
      when(
        () => backend.getMe('expired'),
      ).thenThrow(const AuthException(code: 'unauthorized'));
      when(() => storage.readRefreshToken()).thenAnswer((_) async => 'refresh');
      when(() => backend.refresh('refresh')).thenAnswer(
        (_) async =>
            const TokenResponse(accessToken: 'new', refreshToken: 'new-r'),
      );
      when(() => backend.getMe('new')).thenAnswer((_) async => _user());

      final user = await makeContainer().read(backendSessionProvider.future);

      expect(user!.uid, 'u1');
      verify(
        () => storage.save(accessToken: 'new', refreshToken: 'new-r'),
      ).called(1);
    });

    test('clears tokens when 401 and no refresh token is available', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => 'expired');
      when(
        () => backend.getMe('expired'),
      ).thenThrow(const AuthException(code: 'unauthorized'));
      when(() => storage.readRefreshToken()).thenAnswer((_) async => null);

      final user = await makeContainer().read(backendSessionProvider.future);

      expect(user, isNull);
      verify(() => storage.clear()).called(1);
    });

    test(
      'keeps tokens on a non-401 (network) error but reports logged out',
      () async {
        when(() => storage.readAccessToken()).thenAnswer((_) async => 'a');
        when(
          () => backend.getMe('a'),
        ).thenThrow(const AuthException(code: 'network_error'));

        final user = await makeContainer().read(backendSessionProvider.future);

        expect(user, isNull);
        verifyNever(() => storage.clear());
      },
    );
  });

  group('signInWithGoogle', () {
    test(
      'exchanges the id_token, saves tokens, and publishes the user',
      () async {
        when(() => storage.readAccessToken()).thenAnswer((_) async => null);
        when(() => google.getIdToken()).thenAnswer((_) async => 'id-tok');
        when(() => backend.firebaseLogin('id-tok')).thenAnswer(
          (_) async => const TokenResponse(accessToken: 'a', refreshToken: 'r'),
        );
        when(() => backend.getMe('a')).thenAnswer((_) async => _user());

        final container = makeContainer();
        await container.read(backendSessionProvider.future);
        await container
            .read(backendSessionProvider.notifier)
            .signInWithGoogle();

        expect(container.read(backendSessionProvider).value!.uid, 'u1');
        verify(
          () => storage.save(accessToken: 'a', refreshToken: 'r'),
        ).called(1);
      },
    );
  });

  group('signInWithEmailPassword', () {
    test(
      'signs into Firebase, exchanges the id_token, and publishes the user',
      () async {
        when(() => storage.readAccessToken()).thenAnswer((_) async => null);
        when(
          () => emailPassword.signIn(email: 'a@b.com', password: 'pw'),
        ).thenAnswer((_) async => 'id-tok');
        when(() => backend.firebaseLogin('id-tok')).thenAnswer(
          (_) async => const TokenResponse(accessToken: 'a', refreshToken: 'r'),
        );
        when(() => backend.getMe('a')).thenAnswer((_) async => _user());

        final container = makeContainer();
        await container.read(backendSessionProvider.future);
        await container
            .read(backendSessionProvider.notifier)
            .signInWithEmailPassword(email: 'a@b.com', password: 'pw');

        expect(container.read(backendSessionProvider).value!.uid, 'u1');
        verify(
          () => storage.save(accessToken: 'a', refreshToken: 'r'),
        ).called(1);
      },
    );
  });

  group('registerWithEmailPassword', () {
    test(
      'creates the Firebase account and sends a verification email — does '
      'NOT exchange with the backend (ADR-0021 D2: the password provider '
      'requires email_verified=true, so exchanging here would always 403)',
      () async {
        when(() => storage.readAccessToken()).thenAnswer((_) async => null);
        when(
          () => emailPassword.register(email: 'new@b.com', password: 'pw'),
        ).thenAnswer((_) async => 'id-tok');
        when(
          () => emailPassword.sendEmailVerification(),
        ).thenAnswer((_) async {});

        final container = makeContainer();
        await container.read(backendSessionProvider.future);
        await container
            .read(backendSessionProvider.notifier)
            .registerWithEmailPassword(email: 'new@b.com', password: 'pw');

        verify(() => emailPassword.sendEmailVerification()).called(1);
        verifyNever(() => backend.firebaseLogin(any()));
        // No half-registered session — still logged out.
        expect(container.read(backendSessionProvider).value, isNull);
        verifyNever(
          () => storage.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          ),
        );
      },
    );

    test(
      'propagates a sendEmailVerification failure without attempting any '
      'exchange — ADR-0021 D2 removed the rollback entirely (there is no '
      'longer a deleteCurrentUser to call at all): an unverified Firebase '
      'account left behind mid-flow is normal now, not orphaned garbage',
      () async {
        when(() => storage.readAccessToken()).thenAnswer((_) async => null);
        when(
          () => emailPassword.register(email: 'new@b.com', password: 'pw'),
        ).thenAnswer((_) async => 'id-tok');
        when(
          () => emailPassword.sendEmailVerification(),
        ).thenThrow(const AuthException(code: 'email_password_unexpected'));

        final container = makeContainer();
        await container.read(backendSessionProvider.future);

        await expectLater(
          container
              .read(backendSessionProvider.notifier)
              .registerWithEmailPassword(email: 'new@b.com', password: 'pw'),
          throwsA(isA<AuthException>()),
        );

        verifyNever(() => backend.firebaseLogin(any()));
      },
    );
  });

  group('resendVerificationEmail', () {
    test('resends via the data source', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => null);
      when(
        () => emailPassword.sendEmailVerification(),
      ).thenAnswer((_) async {});

      final container = makeContainer();
      await container.read(backendSessionProvider.future);
      await container
          .read(backendSessionProvider.notifier)
          .resendVerificationEmail();

      verify(() => emailPassword.sendEmailVerification()).called(1);
    });
  });

  group('checkEmailVerifiedAndContinue', () {
    test('returns false and does NOT exchange when the email is not verified '
        'yet — this is not an error, it is "not yet"', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => null);
      when(
        () => emailPassword.reloadAndCheckEmailVerified(),
      ).thenAnswer((_) async => false);

      final container = makeContainer();
      await container.read(backendSessionProvider.future);
      final verified = await container
          .read(backendSessionProvider.notifier)
          .checkEmailVerifiedAndContinue();

      expect(verified, isFalse);
      verifyNever(() => emailPassword.currentIdToken());
      verifyNever(() => backend.firebaseLogin(any()));
      expect(container.read(backendSessionProvider).value, isNull);
    });

    test('when verified, exchanges a force-refreshed id token and publishes '
        'the session, returning true', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => null);
      when(
        () => emailPassword.reloadAndCheckEmailVerified(),
      ).thenAnswer((_) async => true);
      when(
        () => emailPassword.currentIdToken(),
      ).thenAnswer((_) async => 'fresh-id-tok');
      when(() => backend.firebaseLogin('fresh-id-tok')).thenAnswer(
        (_) async => const TokenResponse(accessToken: 'a', refreshToken: 'r'),
      );
      when(() => backend.getMe('a')).thenAnswer((_) async => _user());

      final container = makeContainer();
      await container.read(backendSessionProvider.future);
      final verified = await container
          .read(backendSessionProvider.notifier)
          .checkEmailVerifiedAndContinue();

      expect(verified, isTrue);
      expect(container.read(backendSessionProvider).value!.uid, 'u1');
      verify(() => storage.save(accessToken: 'a', refreshToken: 'r')).called(1);
    });
  });

  group('signOut', () {
    test('revokes the stored refresh token, then clears storage and nulls '
        'the session', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => 'a');
      when(() => backend.getMe('a')).thenAnswer((_) async => _user());
      when(
        () => storage.readRefreshToken(),
      ).thenAnswer((_) async => 'refresh-token');
      when(() => backend.logout('refresh-token')).thenAnswer((_) async {});

      final container = makeContainer();
      await container.read(backendSessionProvider.future);
      await container.read(backendSessionProvider.notifier).signOut();

      expect(container.read(backendSessionProvider).value, isNull);
      verify(() => backend.logout('refresh-token')).called(1);
      verify(() => storage.clear()).called(1);
    });

    test(
      'still clears storage and nulls the session when the revoke fails '
      '— signing out offline must never leave the app looking logged in',
      () async {
        when(() => storage.readAccessToken()).thenAnswer((_) async => 'a');
        when(() => backend.getMe('a')).thenAnswer((_) async => _user());
        when(
          () => storage.readRefreshToken(),
        ).thenAnswer((_) async => 'refresh-token');
        when(
          () => backend.logout('refresh-token'),
        ).thenThrow(const AuthException(code: 'network_error'));

        final container = makeContainer();
        await container.read(backendSessionProvider.future);
        await container.read(backendSessionProvider.notifier).signOut();

        expect(container.read(backendSessionProvider).value, isNull);
        verify(() => storage.clear()).called(1);
      },
    );

    test('never calls logout when no refresh token is stored', () async {
      when(() => storage.readAccessToken()).thenAnswer((_) async => 'a');
      when(() => backend.getMe('a')).thenAnswer((_) async => _user());
      when(() => storage.readRefreshToken()).thenAnswer((_) async => null);

      final container = makeContainer();
      await container.read(backendSessionProvider.future);
      await container.read(backendSessionProvider.notifier).signOut();

      expect(container.read(backendSessionProvider).value, isNull);
      verifyNever(() => backend.logout(any()));
      verify(() => storage.clear()).called(1);
    });
  });
}
