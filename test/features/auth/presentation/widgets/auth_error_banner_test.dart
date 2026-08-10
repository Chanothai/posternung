import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/presentation/auth_error_display.dart';
import 'package:posternung/features/auth/presentation/widgets/auth_error_banner.dart';

/// `AuthErrorBanner` is the ONE place that decides whether a retry button
/// shows at all (ADR-0021 D3 — "the button is tied to the code, not to the
/// screen"). Every screen that renders this banner (`LoginScreen`,
/// `EmailVerificationScreen`, `OtpVerificationScreen`) must simply hand it
/// whatever action retry should run and let the banner decide visibility
/// from `code` alone — none of them may re-check the code themselves
/// (code-critic GATE 3 round 1: three separate copies of the same
/// `code == oauthLoginConflictCode` check meant disarming any *one* of them
/// alone never made a test fail — this file is what makes disarming the
/// banner's own check, specifically, fail).
void main() {
  Widget wrap({
    String message = 'error message',
    String? code,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AuthErrorBanner(message: message, code: code, onRetry: onRetry),
      ),
    );
  }

  testWidgets('always shows the message and, when code is given, the code '
      'line — regardless of retry state', (tester) async {
    await tester.pumpWidget(
      wrap(message: 'อีเมลไม่ถูกต้อง', code: 'invalid-email'),
    );

    expect(find.text('อีเมลไม่ถูกต้อง'), findsOneWidget);
    expect(
      find.text('${AppStrings.authErrorCodeLabel}invalid-email'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.authRetryButton), findsNothing);
  });

  testWidgets('shows the retry button for oauthLoginConflictCode when '
      'onRetry is supplied, and tapping it calls onRetry', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(code: oauthLoginConflictCode, onRetry: () => retried++),
    );

    final retryButton = find.text(AppStrings.authRetryButton);
    expect(retryButton, findsOneWidget);

    await tester.tap(retryButton);
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets(
    'does NOT show the retry button for a different code, even though '
    'onRetry is supplied — this is the assertion that catches the banner '
    'losing its own code check',
    (tester) async {
      await tester.pumpWidget(
        wrap(code: 'OAUTH_TOKEN_INVALID', onRetry: () {}),
      );

      expect(find.text(AppStrings.authRetryButton), findsNothing);
    },
  );

  testWidgets('does NOT show the retry button for oauthLoginConflictCode when '
      'onRetry is null — nothing to retry, so nothing to press', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(code: oauthLoginConflictCode));

    expect(find.text(AppStrings.authRetryButton), findsNothing);
  });

  testWidgets('does NOT show the retry button when there is no code at all, '
      'even with onRetry supplied', (tester) async {
    await tester.pumpWidget(wrap(onRetry: () {}));

    expect(find.text(AppStrings.authRetryButton), findsNothing);
  });

  // Every other backend error code SCR-02 AC-4 names explicitly, proving
  // the retry button really is a one-code allowlist and not, say, "any
  // OAUTH_* code" or "anything starting with OAUTH_LOGIN".
  for (final code in [
    'OAUTH_TOKEN_INVALID',
    'OAUTH_EMAIL_NOT_VERIFIED',
    'LOGIN_RATE_LIMITED',
    'OAUTH_PROVIDER_NOT_CONFIGURED',
  ]) {
    testWidgets(
      'does NOT show the retry button for $code, even with onRetry supplied',
      (tester) async {
        await tester.pumpWidget(wrap(code: code, onRetry: () {}));

        expect(find.text(AppStrings.authRetryButton), findsNothing);
      },
    );
  }
}
