import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:posternung/core/error/auth_cancelled_exception.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/features/auth/data/datasources/google_sign_in_data_source.dart';

/// Substitutes the real native plugin channel `GoogleSignIn.instance`
/// delegates to. `GoogleSignInPlatform.instance` is a settable seam meant
/// exactly for this (the package's own doc comment on `PlatformInterface
/// .verify` points at `MockPlatformInterfaceMixin` for it) — `GoogleSignIn`
/// itself has no injectable constructor to mock instead (it is a bare
/// `static final GoogleSignIn instance = GoogleSignIn._()` singleton).
class FakeGoogleSignInPlatform extends GoogleSignInPlatform
    with MockPlatformInterfaceMixin {
  FakeGoogleSignInPlatform({this.authenticateResult, this.authenticateError});

  final AuthenticationResults? authenticateResult;
  final Object? authenticateError;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    final error = authenticateError;
    if (error != null) throw error;
    return authenticateResult!;
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

AuthenticationResults _results({String? idToken}) => AuthenticationResults(
  user: const GoogleSignInUserData(email: 'a@b.com', id: 'google-uid'),
  authenticationTokens: AuthenticationTokenData(idToken: idToken),
);

class _FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeAuthCredential()));

  late MockFirebaseAuth firebaseAuth;
  late GoogleSignInDataSourceImpl dataSource;

  setUp(() {
    firebaseAuth = MockFirebaseAuth();
    dataSource = GoogleSignInDataSourceImpl(firebaseAuth);
  });

  test('runs the picker, exchanges the Google id_token for a Firebase session, '
      'and returns the Firebase ID token — not the Google one', () async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
      authenticateResult: _results(idToken: 'google-id-tok'),
    );
    final credential = MockUserCredential();
    final user = MockUser();
    when(
      () => firebaseAuth.signInWithCredential(any()),
    ).thenAnswer((_) async => credential);
    when(() => credential.user).thenReturn(user);
    when(() => user.getIdToken()).thenAnswer((_) async => 'firebase-id-tok');

    final result = await dataSource.getIdToken();

    expect(result, 'firebase-id-tok');
    final captured = verify(
      () => firebaseAuth.signInWithCredential(captureAny()),
    ).captured;
    expect((captured.single as OAuthCredential).providerId, 'google.com');
  });

  test('throws missing_id_token when the Google account has no id_token — '
      'nothing to exchange with Firebase', () async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
      authenticateResult: _results(idToken: null),
    );

    expect(
      () => dataSource.getIdToken(),
      throwsA(
        isA<AuthException>().having((e) => e.code, 'code', 'missing_id_token'),
      ),
    );
  });

  test('throws missing_id_token when the Firebase exchange yields no id_token '
      'either — same empty-string/null trap as the other providers', () async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
      authenticateResult: _results(idToken: 'google-id-tok'),
    );
    final credential = MockUserCredential();
    final user = MockUser();
    when(
      () => firebaseAuth.signInWithCredential(any()),
    ).thenAnswer((_) async => credential);
    when(() => credential.user).thenReturn(user);
    when(() => user.getIdToken()).thenAnswer((_) async => '');

    expect(
      () => dataSource.getIdToken(),
      throwsA(
        isA<AuthException>().having((e) => e.code, 'code', 'missing_id_token'),
      ),
    );
  });

  test('maps a user-cancelled picker to AuthCancelledException, silently — '
      'not a failure the UI should show an error for', () async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
      authenticateError: GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'canceled',
      ),
    );

    expect(
      () => dataSource.getIdToken(),
      throwsA(isA<AuthCancelledException>()),
    );
  });

  test('maps a non-cancel GoogleSignInException to an AuthException carrying '
      'the SDK code, with the description only as debugDetail (ADR-0017 D2 — '
      'never displayMessage)', () async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
      authenticateError: GoogleSignInException(
        code: GoogleSignInExceptionCode.interrupted,
        description: 'interrupted by the user leaving the app',
      ),
    );

    expect(
      () => dataSource.getIdToken(),
      throwsA(
        isA<AuthException>()
            .having((e) => e.code, 'code', 'interrupted')
            .having(
              (e) => e.debugDetail,
              'debugDetail',
              'interrupted by the user leaving the app',
            )
            .having((e) => e.displayMessage, 'displayMessage', isNull),
      ),
    );
  });

  test('maps a FirebaseAuthException from the credential exchange (e.g. '
      'account-exists-with-different-credential) to an AuthException carrying '
      'the same code', () async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
      authenticateResult: _results(idToken: 'google-id-tok'),
    );
    when(() => firebaseAuth.signInWithCredential(any())).thenThrow(
      FirebaseAuthException(
        code: 'account-exists-with-different-credential',
        message: 'account exists',
      ),
    );

    expect(
      () => dataSource.getIdToken(),
      throwsA(
        isA<AuthException>().having(
          (e) => e.code,
          'code',
          'account-exists-with-different-credential',
        ),
      ),
    );
  });

  test('wraps anything else (a plugin-channel failure, say) into a fixed code '
      'instead of letting it escape uncaught with nothing to display — this '
      'data source used to have no trailing catch-all, unlike every other '
      'guard in this feature', () async {
    GoogleSignInPlatform.instance = FakeGoogleSignInPlatform(
      authenticateError: StateError('channel broke'),
    );

    expect(
      () => dataSource.getIdToken(),
      throwsA(
        isA<AuthException>()
            .having((e) => e.code, 'code', 'google_signin_unexpected')
            .having(
              (e) => e.debugDetail,
              'debugDetail',
              contains('channel broke'),
            )
            .having((e) => e.displayMessage, 'displayMessage', isNull),
      ),
    );
  });
}
