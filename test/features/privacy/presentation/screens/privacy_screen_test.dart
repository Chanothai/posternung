import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/privacy/presentation/screens/privacy_screen.dart';

/// Every `Text.data` on the page, closed-world (test-quality §4) — the
/// allowlist is built entirely from `AppStrings` constants, never copied
/// from what the screen renders today.
Set<String> _allTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toSet();

Widget _harness() => MaterialApp.router(
  routerConfig: GoRouter(
    initialLocation: '/',
    routes: [GoRoute(path: '/', builder: (_, _) => const PrivacyScreen())],
  ),
);

/// The privacy notice is long enough that the default 800x600 test surface
/// only renders the first few sections — a `ListView`'s `Sliver` only
/// builds/lays out what's within the viewport + cache extent, list-view or
/// builder-backed alike. A tall, narrow surface (same trick used in
/// `poster_details_accordion_test.dart`) fits the whole page without
/// needing to scroll, so `find.text()` can see every section at once.
Future<void> _useTallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows the draft badge on the page itself (A5-D2), not only '
      'in a source comment', (tester) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_harness());

    expect(find.text(AppStrings.privacyDraftBadge), findsOneWidget);
  });

  testWidgets('renders every D11-minus-two-lines section verbatim', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_harness());

    for (final expected in <String>[
      AppStrings.privacyPageTitle,
      AppStrings.privacyControllerBody,
      AppStrings.privacyWhatWeCollectHeading,
      AppStrings.privacyWhatWeCollectBody1,
      AppStrings.privacyWhatWeCollectBody2,
      AppStrings.privacyWhyHeading,
      AppStrings.privacyWhyBody1,
      AppStrings.privacyWhyBody2,
      AppStrings.privacyRecipientsHeading,
      AppStrings.privacyRecipientFirebase,
      AppStrings.privacyRecipientGoogleDrive,
      AppStrings.privacyNoSellingData,
      AppStrings.privacyRetentionHeading,
      AppStrings.privacyRetentionShipping,
      AppStrings.privacyRetentionFinancial,
      AppStrings.privacyRetentionAccount,
      AppStrings.privacyContactHeading,
      AppStrings.privacyContactBody1,
      AppStrings.privacyContactBody2,
      AppStrings.privacyContactBody3,
    ]) {
      expect(find.text(expected), findsOneWidget, reason: 'missing: $expected');
    }
  });

  testWidgets(
    'never mentions TikTok or Omise — both were removed from D11 because '
    'ADR-0029 made them false (Amendment 5 A5-D1)',
    (tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_harness());

      final texts = _allTexts(tester);
      expect(texts.where((t) => t.contains('TikTok')), isEmpty);
      expect(texts.where((t) => t.contains('Omise')), isEmpty);
    },
  );

  testWidgets(
    'never uses the forbidden words "รับรอง"/"การันตี" (D11, carried over '
    'unchanged by Amendment 5)',
    (tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_harness());

      final texts = _allTexts(tester);
      expect(texts.where((t) => t.contains('รับรอง')), isEmpty);
      expect(texts.where((t) => t.contains('การันตี')), isEmpty);
    },
  );

  testWidgets('mentions the LINE contact channel (@frameshine)', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await tester.pumpWidget(_harness());

    expect(find.textContaining('@frameshine'), findsOneWidget);
  });

  testWidgets(
    'closed-world: every Text on the page is one of AppStrings\' Privacy '
    'block entries or the draft badge — nothing else was added silently',
    (tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(_harness());

      const allowlist = <String>{
        AppStrings.privacyDraftBadge,
        AppStrings.privacyPageTitle,
        AppStrings.privacyControllerBody,
        AppStrings.privacyWhatWeCollectHeading,
        AppStrings.privacyWhatWeCollectBody1,
        AppStrings.privacyWhatWeCollectBody2,
        AppStrings.privacyWhyHeading,
        AppStrings.privacyWhyBody1,
        AppStrings.privacyWhyBody2,
        AppStrings.privacyRecipientsHeading,
        AppStrings.privacyRecipientFirebase,
        AppStrings.privacyRecipientGoogleDrive,
        AppStrings.privacyNoSellingData,
        AppStrings.privacyRetentionHeading,
        AppStrings.privacyRetentionShipping,
        AppStrings.privacyRetentionFinancial,
        AppStrings.privacyRetentionAccount,
        AppStrings.privacyContactHeading,
        AppStrings.privacyContactBody1,
        AppStrings.privacyContactBody2,
        AppStrings.privacyContactBody3,
      };

      final texts = _allTexts(tester);
      expect(texts.difference(allowlist), isEmpty);
    },
  );

  testWidgets(
    'F9 — opened as the initial route (no back stack), tapping back goes '
    'home instead of throwing GoError(\'There is nothing to pop\')',
    (tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: AppRoutes.privacyPath,
            routes: [
              GoRoute(
                path: AppRoutes.privacyPath,
                builder: (_, _) => const PrivacyScreen(),
              ),
              GoRoute(
                path: AppRoutes.homePath,
                builder: (_, _) => const Text('HOME_STUB'),
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('HOME_STUB'), findsOneWidget);
    },
  );
}
