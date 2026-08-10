import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/error/auth_exception.dart';
import 'package:posternung/core/router/app_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/email_verification_flow_provider.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:posternung/features/auth/presentation/screens/login_screen.dart';

import '../../../../support/email_verification_flow_harness.dart';
import '../../../../support/router_harness.dart';

/// Fake view model — sets `state` rather than throwing, mirroring what
/// `AsyncValue.guard` does in the real one (`add-feature-slice` skill §3).
class FakeAuthViewModel extends AuthViewModel {
  FakeAuthViewModel({
    this.checkResult = false,
    this.checkErrorToThrow,
    this.resendErrorToThrow,
  });

  final bool checkResult;
  final Object? checkErrorToThrow;
  final Object? resendErrorToThrow;

  int checkCallCount = 0;
  int resendCallCount = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> checkEmailVerifiedAndContinue() async {
    checkCallCount++;
    final error = checkErrorToThrow;
    if (error != null) {
      state = AsyncError(error, StackTrace.current);
      return false;
    }
    state = const AsyncData(null);
    return checkResult;
  }

  @override
  Future<void> resendVerificationEmail() async {
    resendCallCount++;
    final error = resendErrorToThrow;
    state = error != null
        ? AsyncError(error, StackTrace.current)
        : const AsyncData(null);
  }
}

void main() {
  const email = 'someone@example.com';

  Widget wrap({
    bool checkResult = false,
    Object? checkErrorToThrow,
    Object? resendErrorToThrow,
    bool justSentEmail = false,
    void Function(GoRouter router)? onRouter,
    void Function(FakeAuthViewModel viewModel)? onViewModel,
  }) {
    return ProviderScope(
      overrides: [
        authViewModelProvider.overrideWith(() {
          final viewModel = FakeAuthViewModel(
            checkResult: checkResult,
            checkErrorToThrow: checkErrorToThrow,
            resendErrorToThrow: resendErrorToThrow,
          );
          onViewModel?.call(viewModel);
          return viewModel;
        }),
        sessionProvider.overrideWithValue(const AsyncData<AuthUser?>(null)),
        emailVerificationFlowProvider.overrideWith(
          () => SeededEmailVerificationFlow(
            EmailVerificationFlowState(
              email: email,
              justSentEmail: justSentEmail,
            ),
          ),
        ),
      ],
      // Reached by its real path (ADR-0018 D9) rather than by naming the
      // widget.
      child: routedApp(
        location: AppRoutes.emailVerificationPath,
        routes: appRoutes,
        onRouter: onRouter,
      ),
    );
  }

  testWidgets('renders the heading, the email the flow is for, and the '
      'instructions', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text(AppStrings.authEmailVerificationHeading), findsOneWidget);
    expect(find.text(email), findsOneWidget);
    expect(
      find.text(AppStrings.authEmailVerificationInstructions),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping "check status" while not verified shows the "not yet" message '
    'and stays on this screen',
    (tester) async {
      late GoRouter router;
      await tester.pumpWidget(
        wrap(checkResult: false, onRouter: (r) => router = r),
      );

      final button = find.text(AppStrings.authEmailVerificationCheckButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.authEmailVerificationNotYetMessage),
        findsOneWidget,
      );
      expect(find.byType(EmailVerificationScreen), findsOneWidget);
      expect(router.state.uri.toString(), AppRoutes.emailVerificationPath);
    },
  );

  testWidgets(
    'tapping "check status" once verified completes the auth flow (goes '
    'home)',
    (tester) async {
      late GoRouter router;
      await tester.pumpWidget(
        wrap(checkResult: true, onRouter: (r) => router = r),
      );

      final button = find.text(AppStrings.authEmailVerificationCheckButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(router.state.uri.toString(), AppRoutes.homePath);
      // sessionProvider is stubbed signed-out here, so the gate falls back
      // to LoginScreen — what matters is that the flow left this screen for
      // home, not what home happens to render in this fixture.
      expect(find.byType(EmailVerificationScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  group('resend', () {
    testWidgets(
      'tapping resend calls the resend action and starts a 60s cooldown',
      (tester) async {
        await tester.pumpWidget(wrap());

        final resend = find.text(
          '${AppStrings.authEmailVerificationResendPrompt}'
          '${AppStrings.authEmailVerificationResendAction}',
          findRichText: true,
        );
        await tester.ensureVisible(resend);
        await tester.tap(resend);
        await tester.pump();

        expect(
          find.textContaining(
            AppStrings.authEmailVerificationResendCountdownPrefix,
          ),
          findsOneWidget,
        );
        // The tappable resend link itself is gone while the cooldown runs.
        expect(
          find.text(
            '${AppStrings.authEmailVerificationResendPrompt}'
            '${AppStrings.authEmailVerificationResendAction}',
            findRichText: true,
          ),
          findsNothing,
        );
      },
    );

    testWidgets('a failed resend shows the error banner and does NOT start the '
        'cooldown — the tap must stay retryable', (tester) async {
      await tester.pumpWidget(
        wrap(resendErrorToThrow: const AuthException(code: 'network_error')),
      );

      final resend = find.text(
        '${AppStrings.authEmailVerificationResendPrompt}'
        '${AppStrings.authEmailVerificationResendAction}',
        findRichText: true,
      );
      await tester.ensureVisible(resend);
      await tester.tap(resend);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.authErrorNetwork), findsOneWidget);
      expect(
        find.text(
          '${AppStrings.authEmailVerificationResendPrompt}'
          '${AppStrings.authEmailVerificationResendAction}',
          findRichText: true,
        ),
        findsOneWidget,
        reason: 'a failed resend must not start the cooldown',
      );
    });

    testWidgets('the cooldown lasts exactly 60 seconds, not any other duration '
        '(code-critic GATE 3 round 1 — a 60→3 mutant left every prior test '
        'here green: they only asserted a countdown appeared, never its '
        'length)', (tester) async {
      Finder resendLink() => find.text(
        '${AppStrings.authEmailVerificationResendPrompt}'
        '${AppStrings.authEmailVerificationResendAction}',
        findRichText: true,
      );

      await tester.pumpWidget(wrap());
      await tester.ensureVisible(resendLink());
      await tester.tap(resendLink());
      await tester.pump();

      // At t=3s specifically — the exact boundary a 60→3 mutant would
      // already have reset at. Real code must still be well within the
      // cooldown.
      await tester.pump(const Duration(seconds: 3));
      expect(
        resendLink(),
        findsNothing,
        reason: 'must still be counting down at t=3s, not reset',
      );
      expect(
        find.text(
          '${AppStrings.authEmailVerificationResendCountdownPrefix}57'
          '${AppStrings.authEmailVerificationResendCountdownSuffix}',
        ),
        findsOneWidget,
        reason: '60 - 3 = 57 seconds remaining',
      );

      // t=59s — one tick before the cooldown should end.
      await tester.pump(const Duration(seconds: 56));
      expect(
        resendLink(),
        findsNothing,
        reason: 'must still be counting down at t=59s',
      );

      // t=60s — the cooldown ends and the resend link comes back.
      await tester.pump(const Duration(seconds: 1));
      expect(resendLink(), findsOneWidget);
    });

    testWidgets(
      'arriving from register (justSentEmail: true) arms the cooldown '
      'immediately — registerWithEmailPassword just sent one, so an '
      'un-cooled-down resend link would let the user re-send moments '
      'later into Firebase\'s silent same-address throttle (ADR-0021 D2 '
      'row 4, code-critic GATE 3 round 1)',
      (tester) async {
        await tester.pumpWidget(wrap(justSentEmail: true));

        expect(
          find.text(
            '${AppStrings.authEmailVerificationResendCountdownPrefix}60'
            '${AppStrings.authEmailVerificationResendCountdownSuffix}',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            '${AppStrings.authEmailVerificationResendPrompt}'
            '${AppStrings.authEmailVerificationResendAction}',
            findRichText: true,
          ),
          findsNothing,
          reason: 'the resend link itself must not be tappable yet',
        );
      },
    );

    testWidgets(
      'arriving from the login-403 redirect (justSentEmail: false) does '
      'NOT arm the cooldown — no email went out as part of reaching this '
      'screen that way, so the resend link must be usable immediately',
      (tester) async {
        await tester.pumpWidget(wrap(justSentEmail: false));

        expect(
          find.text(
            '${AppStrings.authEmailVerificationResendPrompt}'
            '${AppStrings.authEmailVerificationResendAction}',
            findRichText: true,
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            AppStrings.authEmailVerificationResendCountdownPrefix,
          ),
          findsNothing,
        );
      },
    );
  });

  group('ADR-0021 D3 — the retry button on this screen too is tied to '
      'OAUTH_LOGIN_CONFLICT', () {
    testWidgets('appears and re-runs the check', (tester) async {
      late FakeAuthViewModel viewModel;
      await tester.pumpWidget(
        wrap(
          checkErrorToThrow: const AuthException(code: 'OAUTH_LOGIN_CONFLICT'),
          onViewModel: (vm) => viewModel = vm,
        ),
      );

      final button = find.text(AppStrings.authEmailVerificationCheckButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(viewModel.checkCallCount, 1);
      final retry = find.text(AppStrings.authRetryButton);
      expect(retry, findsOneWidget);

      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(viewModel.checkCallCount, 2);
    });

    testWidgets('does not appear for a different code', (tester) async {
      await tester.pumpWidget(
        wrap(checkErrorToThrow: const AuthException(code: 'network_error')),
      );

      final button = find.text(AppStrings.authEmailVerificationCheckButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.authErrorNetwork), findsOneWidget);
      expect(find.text(AppStrings.authRetryButton), findsNothing);
    });
  });

  testWidgets('the back-to-login link pops back to where the flow was '
      'entered from', (tester) async {
    await tester.pumpWidget(wrap());

    final link = find.text('เปลี่ยนใจ? เข้าสู่ระบบ', findRichText: true);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.byType(EmailVerificationScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
