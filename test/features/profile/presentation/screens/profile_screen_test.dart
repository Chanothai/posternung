import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/core/widgets/app_bottom_nav_bar.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';
import 'package:posternung/features/profile/presentation/screens/profile_screen.dart';

import '../../../../support/router_harness.dart';

class _MockPosterRepository extends Mock implements PosterRepository {}

class FakeAuthViewModel extends AuthViewModel {
  bool signOutCalled = false;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

void main() {
  late FakeAuthViewModel authViewModel;

  setUp(() {
    authViewModel = FakeAuthViewModel();
  });

  Widget wrap(AuthUser user) => ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith(() => authViewModel),
      sessionProvider.overrideWithValue(AsyncData<AuthUser?>(user)),
    ],
    child: routedApp(routes: routesHosting(const ProfileScreen())),
  );

  const emailUser = AuthUser(uid: 'u1', email: 'reader@example.com');
  const phoneUser = AuthUser(uid: 'u2');

  testWidgets('shows the signed-in email when there is one', (tester) async {
    await tester.pumpWidget(wrap(emailUser));
    await tester.pumpAndSettle();

    expect(find.text('reader@example.com'), findsOneWidget);
    expect(find.text(AppStrings.profilePhoneLoginLabel), findsNothing);
  });

  testWidgets(
    'a phone-authenticated user (no email) sees "เข้าสู่ระบบด้วยเบอร์โทร" '
    'and nothing that looks like a phone number — AuthUser carries no phone '
    'to leak in the first place (A4-D2 #5)',
    (tester) async {
      await tester.pumpWidget(wrap(phoneUser));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.profilePhoneLoginLabel), findsOneWidget);
      // Closed-world over every Text on screen: none of them may look like
      // a Thai mobile number (leading 0, 9-10 digits). A single named
      // assertion ("no '0812345678'") would only catch the exact string
      // this test guessed — this catches any digit run in that shape,
      // wherever it might get added.
      final phoneShaped = RegExp(r'0\d{8,9}');
      final allText = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' | ');
      expect(
        phoneShaped.hasMatch(allText),
        isFalse,
        reason: 'found a phone-number-shaped string in: $allText',
      );
    },
  );

  testWidgets(
    'closed-world: the only interactive controls are the sign-out button '
    'and the bottom nav\'s 3 tabs',
    (tester) async {
      await tester.pumpWidget(wrap(emailUser));
      await tester.pumpAndSettle();

      // The one action this screen has of its own.
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing); // only inside the dialog
      expect(find.byType(IconButton), findsNothing);
      // The bottom nav's 3 tabs, scoped to that widget specifically — an
      // unscoped `InkWell` count here would also catch `OutlinedButton`'s
      // own internal ripple `InkWell`, double-counting the sign-out button
      // already asserted above.
      expect(
        find.descendant(
          of: find.byType(AppBottomNavBar),
          matching: find.byType(InkWell),
        ),
        findsNWidgets(3),
      );
      // And nothing tappable sits outside both of those.
      expect(
        find.byWidgetPredicate((Widget w) => w is InkWell && w.onTap != null),
        findsNWidgets(4), // 3 nav tabs + OutlinedButton's own ripple InkWell
      );
    },
  );

  testWidgets('tapping sign out opens a confirm dialog — signOut is not '
      'called yet', (tester) async {
    await tester.pumpWidget(wrap(emailUser));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.profileSignOutButton));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(authViewModel.signOutCalled, isFalse);
  });

  testWidgets(
    'cancelling the confirm dialog does NOT sign out (negative assertion — '
    'the whole point of the confirm step)',
    (tester) async {
      await tester.pumpWidget(wrap(emailUser));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.profileSignOutButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.profileSignOutConfirmCancel));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(authViewModel.signOutCalled, isFalse);
    },
  );

  testWidgets('confirming the dialog signs out', (tester) async {
    await tester.pumpWidget(wrap(emailUser));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.profileSignOutButton));
    await tester.pumpAndSettle();

    // The dialog's confirm button carries the same Thai label as the
    // trigger button underneath it ("ออกจากระบบ"), so this must be scoped
    // to the dialog rather than matched by text alone.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(AppStrings.profileSignOutConfirmConfirm),
      ),
    );
    await tester.pumpAndSettle();

    expect(authViewModel.signOutCalled, isTrue);
  });

  testWidgets(
    'F7 — system back does not leave the app: it lands on /home instead '
    '(ADR-0037 A4-D2 #6, PopScope(canPop: false))',
    (tester) async {
      final repository = _MockPosterRepository();
      when(
        () => repository.listPosters(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async =>
            const PaginatedPosters(items: [], total: 0, limit: 20, offset: 0),
      );
      late GoRouter router;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(() => authViewModel),
            sessionProvider.overrideWithValue(
              const AsyncData<AuthUser?>(emailUser),
            ),
            posterRepositoryProvider.overrideWithValue(repository),
          ],
          child: routedApp(
            routes: routesHosting(const ProfileScreen()),
            onRouter: (r) => router = r,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), AppRoutes.homePath);
    },
  );
}
