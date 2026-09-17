import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/features/auth/data/datasources/phone_sign_in_data_source.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';
import 'package:posternung/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/register_screen.dart';
import 'package:posternung/features/auth/presentation/widgets/auth_email_field.dart';

import '../../../../support/router_harness.dart';

class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({
    this.errorToThrow,
    this.confirmPhoneCodeErrorToThrow,
    this.signInErrorToThrow,
    this.signInWithGoogleErrorToThrow,
  });

  final Object? errorToThrow;

  /// Set to make [confirmPhoneCode] fail, for exercising the OTP screen's
  /// error banner (which shares this same provider with [LoginScreen]).
  final Object? confirmPhoneCodeErrorToThrow;

  /// Set to make [signIn] fail — as `state = AsyncError(...)`, mirroring what
  /// `AsyncValue.guard` does in the real view model, not a `throw` (see
  /// `add-feature-slice` skill §3: a throw here would skip the state
  /// transition `LoginScreen._submit` reads from).
  final Object? signInErrorToThrow;

  /// Set to make [signInWithGoogle] fail the same way.
  final Object? signInWithGoogleErrorToThrow;

  /// How many times [signIn] ran — used to prove the D3 retry button
  /// actually re-invokes the action rather than just re-rendering.
  int signInCallCount = 0;

  @override
  FutureOr<void> build() {
    final error = errorToThrow;
    if (error != null) throw error;
    return null;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCallCount++;
    final error = signInErrorToThrow;
    state = error != null
        ? AsyncError(error, StackTrace.current)
        : const AsyncData(null);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {
    final error = signInWithGoogleErrorToThrow;
    state = error != null
        ? AsyncError(error, StackTrace.current)
        : const AsyncData(null);
  }

  @override
  Future<PhoneVerificationResult?> sendPhoneCode(
    String phoneNumber, {
    int? resendToken,
  }) async => SmsCodeSent('test-verification-id');

  @override
  Future<void> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
  }) async {
    // Mirror what the real method does via `AsyncValue.guard` — set `state`
    // rather than throw, so `state.error` actually reflects the failure.
    final error = confirmPhoneCodeErrorToThrow;
    state = error != null
        ? AsyncError(error, StackTrace.current)
        : const AsyncData(null);
  }
}

void main() {
  Widget wrap({
    Object? errorToThrow,
    Object? confirmPhoneCodeErrorToThrow,
    Object? signInErrorToThrow,
    Object? signInWithGoogleErrorToThrow,
    void Function(GoRouter router)? onRouter,
    void Function(FakeAuthViewModel viewModel)? onViewModel,
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(() {
          final viewModel = FakeAuthViewModel(
            errorToThrow: errorToThrow,
            confirmPhoneCodeErrorToThrow: confirmPhoneCodeErrorToThrow,
            signInErrorToThrow: signInErrorToThrow,
            signInWithGoogleErrorToThrow: signInWithGoogleErrorToThrow,
          );
          onViewModel?.call(viewModel);
          return viewModel;
        }),
        // Signed out — which is the only state in which the gate at
        // `/home` renders the screen this file is about.
        sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
      ],
      // `/home`, not `MaterialApp(home: LoginScreen())`: `LoginScreen` is
      // not a route of its own — it is what `AuthGate` renders at
      // `AppRoutes.homePath` while signed out (ADR-0018 D4). Starting from
      // the path proves that is still true, and gives the screen a real
      // router to push `/register` and `/otp` onto.
      child: routedApp(
        location: AppRoutes.homePath,
        routes: appRoutes,
        onRouter: onRouter,
      ),
    );
  }

  testWidgets('renders login-mode copy by default', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('PosterNung'), findsOneWidget);
    expect(find.text('ยินดีต้อนรับกลับ'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
    expect(
      find.text('ยังไม่มีบัญชี? สร้างบัญชีใหม่', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('autofocuses the email field on entry', (tester) async {
    await tester.pumpWidget(wrap());
    // Let the post-frame autofocus request settle.
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(AuthEmailField),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('tapping the mode toggle pushes the register screen — pushes, '
      'so back comes straight back here rather than stranding someone who '
      'only wanted to look', (tester) async {
    late GoRouter router;
    await tester.pumpWidget(wrap(onRouter: (r) => router = r));

    // The toggle link reads "สร้างบัญชีใหม่" (inside a Text.rich, hence
    // findRichText: true, matched against the full combined text). It sits
    // at the bottom of a scrollable card, so scroll it into view first.
    final toggleLink = find.text(
      'ยังไม่มีบัญชี? สร้างบัญชีใหม่',
      findRichText: true,
    );
    await tester.ensureVisible(toggleLink);
    await tester.tap(toggleLink);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    // `go` would show the same screen and leave nothing to go back to, so
    // asserting only on what is rendered cannot tell the two apart.
    expect(
      router.canPop(),
      isTrue,
      reason: 'register must sit on top of the gate, not replace it',
    );

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(router.state.uri.toString(), AppRoutes.homePath);
  });

  testWidgets(
    'error banner shows a friendly Thai message + the raw error code',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          errorToThrow: const AuthException(
            code: 'wrong-password',
            // Firebase's own English text — real data sources put this in
            // debugDetail (ADR-0017 D2/D7); asserted below that it never
            // reaches the widget tree no matter what a guard puts here.
            debugDetail: 'The password is invalid.',
          ),
        ),
      );
      await tester.pump();

      // Firebase's English message is mapped to Thai; the raw code shows on a
      // second line for diagnosis.
      expect(find.text(AppStrings.authErrorWrongPassword), findsOneWidget);
      expect(
        find.text('${AppStrings.authErrorCodeLabel}wrong-password'),
        findsOneWidget,
      );
      expect(find.text('The password is invalid.'), findsNothing);
    },
  );

  group('ADR-0021 D2 — password-provider 403 OAUTH_EMAIL_NOT_VERIFIED is a '
      'route, not an error', () {
    testWidgets(
      '🔴 the SAME code from the Google button does NOT redirect — Google '
      'verifies email itself, so this would mean something else is wrong; '
      'it must fall through to the ordinary error banner',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            signInWithGoogleErrorToThrow: const AuthException(
              code: 'OAUTH_EMAIL_NOT_VERIFIED',
            ),
          ),
        );

        final googleButton = find.text(AppStrings.authGoogleSignIn);
        await tester.ensureVisible(googleButton);
        await tester.tap(googleButton);
        await tester.pumpAndSettle();

        expect(find.byType(EmailVerificationScreen), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(
          find.text('${AppStrings.authErrorCodeLabel}OAUTH_EMAIL_NOT_VERIFIED'),
          findsOneWidget,
          reason: 'must show as an ordinary error banner, not redirect',
        );
      },
    );

    testWidgets(
      'navigates to the email-verification screen carrying the email that '
      'was submitted, instead of showing an error banner, and clears the '
      'view-model error along the way',
      (tester) async {
        late GoRouter router;
        await tester.pumpWidget(
          wrap(
            signInErrorToThrow: const AuthException(
              code: 'OAUTH_EMAIL_NOT_VERIFIED',
            ),
            onRouter: (r) => router = r,
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'unverified@example.com',
        );
        await tester.enterText(find.byType(TextFormField).last, 'password123');
        final submit = find.text(AppStrings.authSubmitLogin);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.byType(EmailVerificationScreen), findsOneWidget);
        expect(find.text('unverified@example.com'), findsOneWidget);
        expect(router.state.uri.toString(), AppRoutes.emailVerificationPath);
        // Not left showing as an error banner underneath — the code proves
        // that if this ever renders LoginScreen again the banner is gone.
        expect(
          find.text('${AppStrings.authErrorCodeLabel}OAUTH_EMAIL_NOT_VERIFIED'),
          findsNothing,
        );
        // login_screen.dart passes `justSentEmail: false` here — no email
        // went out as part of *this* arrival (whatever register sent could
        // be long gone), so the resend link must be usable immediately, not
        // artificially cooled down. A `false` → `true` mutant here would
        // regress that, and every prior test reaching this screen via the
        // real login-403 path only asserted "arrived", never this.
        expect(
          find.text(
            '${AppStrings.authEmailVerificationResendPrompt}'
            '${AppStrings.authEmailVerificationResendAction}',
            findRichText: true,
          ),
          findsOneWidget,
          reason:
              'arriving from the login-403 redirect must NOT arm the '
              'cooldown — the resend link must be tappable immediately',
        );
        expect(
          find.textContaining(
            AppStrings.authEmailVerificationResendCountdownPrefix,
          ),
          findsNothing,
          reason: 'no countdown must be showing',
        );
      },
    );
  });

  group('ADR-0021 D3 — the error banner\'s retry button is tied to '
      'OAUTH_LOGIN_CONFLICT, not to any other code', () {
    testWidgets('appears for OAUTH_LOGIN_CONFLICT and re-runs the action '
        'that produced it', (tester) async {
      late FakeAuthViewModel viewModel;
      await tester.pumpWidget(
        wrap(
          signInErrorToThrow: const AuthException(code: 'OAUTH_LOGIN_CONFLICT'),
          onViewModel: (vm) => viewModel = vm,
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      final submit = find.text(AppStrings.authSubmitLogin);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(viewModel.signInCallCount, 1);
      final retry = find.text(AppStrings.authRetryButton);
      expect(retry, findsOneWidget);

      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(
        viewModel.signInCallCount,
        2,
        reason:
            'the retry button must re-run the failed action, not just '
            're-render the same state',
      );
    });

    testWidgets(
      'does NOT appear for a different code, even with an action to retry',
      (tester) async {
        await tester.pumpWidget(
          wrap(signInErrorToThrow: const AuthException(code: 'wrong-password')),
        );

        await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
        await tester.enterText(find.byType(TextFormField).last, 'password123');
        final submit = find.text(AppStrings.authSubmitLogin);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.authErrorWrongPassword), findsOneWidget);
        expect(find.text(AppStrings.authRetryButton), findsNothing);
      },
    );
  });

  group('phone method', () {
    testWidgets(
      'tapping the phone tab hides the password field and mode toggle, '
      'shows the phone field',
      (tester) async {
        await tester.pumpWidget(wrap());

        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        expect(find.text(AppStrings.authPhoneHeading), findsOneWidget);
        expect(find.text(AppStrings.authPhoneLabel), findsOneWidget);
        expect(find.text(AppStrings.authPasswordLabel), findsNothing);
        expect(find.text(AppStrings.authForgotPassword), findsNothing);
        expect(
          find.text('ยังไม่มีบัญชี? สร้างบัญชีใหม่', findRichText: true),
          findsNothing,
        );
        expect(find.text(AppStrings.authSubmitPhoneOtp), findsOneWidget);
      },
    );

    testWidgets(
      'submitting an incomplete phone number shows the validation error',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '812345');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();

        expect(find.text(AppStrings.authPhoneValidationError), findsOneWidget);
      },
    );

    testWidgets(
      'submitting a valid 9-digit phone number navigates to the OTP screen '
      'showing the phone number — and the URL that navigation produced '
      'carries none of the phone number, verification id or resend token '
      '(AC-5 / ADR-0018 D6)',
      (tester) async {
        late GoRouter router;
        await tester.pumpWidget(wrap(onRouter: (r) => router = r));
        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '812345678');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.byType(OtpVerificationScreen), findsOneWidget);
        expect(find.text('+66812345678'), findsOneWidget);

        // 🔴 This is the assertion that has to be made *here* rather than in
        // `app_router_test.dart`. That file starts a router at
        // `AppRoutes.otpPath` and then checks the location is
        // `AppRoutes.otpPath` — a URL the test fed in itself, which stays
        // true no matter what the production call site does. What matters is
        // the URL `LoginScreen._submit` produced, so it is read after the
        // real tap and nowhere else.
        final uri = router.state.uri;
        expect(uri.path, AppRoutes.otpPath);
        expect(uri.queryParameters, isEmpty);
        expect(uri.fragment, isEmpty);

        final location = uri.toString();
        expect(location, AppRoutes.otpPath);
        expect(location, isNot(contains('+66812345678')));
        // Also without the '+': percent-encoded or stripped is still a leak.
        expect(location, isNot(contains('66812345678')));
        // The id the fake view model handed back at this exact call site —
        // not a literal retyped here, so it cannot drift out of the check.
        expect(location, isNot(contains('test-verification-id')));
      },
    );

    testWidgets(
      'submitting the habitual leading-zero form normalizes it to E.164 '
      'instead of dialing an invalid number',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), '0812345678');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(find.byType(OtpVerificationScreen), findsOneWidget);
        expect(find.text('+66812345678'), findsOneWidget);
      },
    );

    testWidgets(
      'backing out of a failed OTP attempt clears its error banner — it and '
      'the login screen share authViewModelProvider, so a wrong-code error '
      'must not still be showing once the user is back here',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            confirmPhoneCodeErrorToThrow: const AuthException(
              code: 'invalid-verification-code',
              debugDetail: 'The SMS code has expired.',
            ),
          ),
        );

        await tester.tap(find.text(AppStrings.authMethodPhoneTab));
        await tester.pump();
        await tester.enterText(find.byType(TextFormField), '812345678');
        final submit = find.text(AppStrings.authSubmitPhoneOtp);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.byType(OtpVerificationScreen), findsOneWidget);

        // Entering a full code on the real OTP screen auto-submits and,
        // with the fake configured to fail, leaves its error banner up.
        await tester.enterText(find.byType(TextField), '472019');
        await tester.pumpAndSettle();
        expect(
          find.text(
            '${AppStrings.authErrorCodeLabel}invalid-verification-code',
          ),
          findsOneWidget,
        );

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.byType(OtpVerificationScreen), findsNothing);
        expect(
          find.text(
            '${AppStrings.authErrorCodeLabel}invalid-verification-code',
          ),
          findsNothing,
        );
      },
    );
  });

  // SCR-07 B9 GATE 2 (ง2) · SCR-02 gap N-1 — under the app's real theme
  // (`routedApp` installs `AppTheme.dark()`), the white auth inputs must
  // paint a border that is actually visible on their white fill. Read off
  // what `InputDecorator` renders (its private `_BorderContainer`), the
  // same way `checkout_screen_test.dart`'s AC-B9-3 does — not off
  // `InputDecoration.border`, which is precisely the value M3 never paints.
  group('(ง2) / SCR-02 N-1 — auth inputs paint a visible border under '
      'AppTheme', () {
    /// WCAG-style relative-luminance contrast ratio of the border as it is
    /// composited onto the fill. The pre-fix state — the theme's white-10%
    /// `inputBorder` blended onto a white fill — is exactly 1.0 (identical
    /// colour); the Figma resting value `borderMuted` (#E5E7EB) on white
    /// measures ≈1.21, which is why this group exists at all (SCR-02 gap,
    /// 2026-09-17: an owner's on-device SIT read called that "visible in a
    /// technical sense" but not visibly a border). `AppColors.borderOnLight`
    /// (#948A7C) replaces it for the resting state and clears WCAG 1.4.11's
    /// 3:1 non-text floor — see that token's own doc comment for the
    /// computation — so the threshold below **is** the WCAG pass mark now,
    /// not merely "better than 1.0".
    double contrastOnFill(Color border, Color fill) {
      final Color painted = Color.alphaBlend(border, fill);
      final double l1 = painted.computeLuminance();
      final double l2 = fill.computeLuminance();
      final double hi = l1 > l2 ? l1 : l2;
      final double lo = l1 > l2 ? l2 : l1;
      return (hi + 0.05) / (lo + 0.05);
    }

    const double wcagNonTextContrast = 3.0;

    /// Asserts the painted border/fill of the `TextFormField` at [field].
    void expectVisibleBorder(
      WidgetTester tester,
      Finder field, {
      required Color expectedBorder,
      required String label,
    }) {
      final decorator = tester.widget<InputDecorator>(
        find.descendant(of: field, matching: find.byType(InputDecorator)),
      );
      final decoration = decorator.decoration;
      expect(decoration.filled, isTrue, reason: '$label is not filled');
      expect(decoration.fillColor, AppColors.white, reason: label);
      expect(
        decoration.enabledBorder,
        isA<OutlineInputBorder>().having(
          (b) => b.borderSide.color,
          'enabledBorder color',
          AppColors.borderOnLight,
        ),
        reason: '$label must set its own enabledBorder',
      );

      final painted = find.descendant(
        of: field,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_BorderContainer',
        ),
      );
      expect(painted, findsOneWidget, reason: label);
      final dynamic container = tester.widget(painted);
      final Color fill = container.fillColor as Color;
      final Color border =
          (container.border as OutlineInputBorder).borderSide.color;
      expect(fill, AppColors.white, reason: '$label painted fill');
      expect(border, expectedBorder, reason: '$label painted border');
      // Negative: the theme's dark-ground resting border (white at 10%)
      // must never be what paints on a white field.
      expect(border, isNot(AppColors.inputBorder), reason: label);
      // Negative: the old (too-faint) Figma resting value must never be
      // what paints either — this is the SCR-02 gap this group closes.
      expect(border, isNot(AppColors.borderMuted), reason: label);
      expect(
        contrastOnFill(border, fill),
        greaterThan(wcagNonTextContrast),
        reason:
            '$label border is not visible on its fill '
            '(contrast ${contrastOnFill(border, fill)})',
      );
    }

    testWidgets(
      'email + password: resting border is borderMuted on a white fill — '
      'visible — and the field is 56px tall, as before the theme existed. '
      '🔴 mutation-locking: removing `enabledBorder:` from either field '
      'turns this red (the theme\'s white-10% border then paints)',
      (tester) async {
        await tester.pumpWidget(wrap());
        await tester.pump();

        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        // Email is `autofocus: true` on login — so first it paints its own
        // `focusedBorder` (accent), also visible on white …
        expectVisibleBorder(
          tester,
          fields.at(0),
          expectedBorder: AppColors.accent,
          label: 'email (focused)',
        );
        // … and once focus leaves, the resting `enabledBorder`.
        tester.binding.focusManager.primaryFocus?.unfocus();
        await tester.pump();
        expectVisibleBorder(
          tester,
          fields.at(0),
          expectedBorder: AppColors.borderOnLight,
          label: 'email',
        );
        expectVisibleBorder(
          tester,
          fields.at(1),
          expectedBorder: AppColors.borderOnLight,
          label: 'password',
        );
        // Height: the theme's 16/12 contentPadding would make these 48.
        expect(tester.getSize(fields.at(0)).height, 56, reason: 'email');
        expect(tester.getSize(fields.at(1)).height, 56, reason: 'password');
      },
    );

    testWidgets('phone: resting border is borderMuted on a white fill and the '
        'field is 56px tall', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.tap(find.text(AppStrings.authMethodPhoneTab));
      await tester.pump();
      // `_PhoneField` is `autofocus: true` as well — rest it first.
      tester.binding.focusManager.primaryFocus?.unfocus();
      await tester.pump();

      final field = find.byType(TextFormField);
      expect(field, findsOneWidget);
      expectVisibleBorder(
        tester,
        field,
        expectedBorder: AppColors.borderOnLight,
        label: 'phone',
      );
      expect(tester.getSize(field).height, 56);
    });

    testWidgets('a validation failure paints accentRed on the email field — '
        'the error state has its own explicit border too, not `border:`\'s '
        'never-painted side', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pump();

      await tester.tap(find.text(AppStrings.authSubmitLogin));
      await tester.pump();
      expect(find.text(AppStrings.authEmailValidationError), findsOneWidget);

      final email = find.byType(TextFormField).first;
      final painted = find.descendant(
        of: email,
        matching: find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_BorderContainer',
        ),
      );
      expect(painted, findsOneWidget);
      final dynamic container = tester.widget(painted);
      final Color border =
          (container.border as OutlineInputBorder).borderSide.color;
      expect(border, AppColors.accentRed);
      expect(border, isNot(AppColors.inputBorder));
      expect(border, isNot(AppColors.borderMuted));
      expect(
        contrastOnFill(border, container.fillColor as Color),
        greaterThan(wcagNonTextContrast),
      );
    });
  });
}
