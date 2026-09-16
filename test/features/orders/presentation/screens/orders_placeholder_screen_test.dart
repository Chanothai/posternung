import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posternung/core/router/app_routes.dart';
import 'package:posternung/core/strings/app_strings.dart';
import 'package:posternung/features/auth/domain/entities/auth_user.dart';
import 'package:posternung/features/auth/presentation/providers/session_provider.dart';
import 'package:posternung/features/orders/presentation/screens/orders_placeholder_screen.dart';
import 'package:posternung/features/poster/domain/entities/paginated_posters.dart';
import 'package:posternung/features/poster/domain/repositories/poster_repository.dart';
import 'package:posternung/features/poster/presentation/providers/poster_providers.dart';

import '../../../../support/router_harness.dart';

class _MockPosterRepository extends Mock implements PosterRepository {}

void main() {
  Widget wrap() =>
      routedApp(routes: routesHosting(const OrdersPlaceholderScreen()));

  testWidgets('shows the "no orders yet" placeholder copy', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.ordersPlaceholderTitle), findsOneWidget);
    expect(find.text(AppStrings.ordersPlaceholderBody), findsOneWidget);
  });

  testWidgets(
    'closed-world: nothing else on screen — no list, no button beyond the '
    'bottom nav\'s 3 tabs (SCR-09 is what adds a real list, not this round)',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsNothing);
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      // The bottom nav's own 3 tabs are the only tappables on this screen —
      // AppStatusView renders no action here (no `actionLabel`/`onAction`
      // passed).
      expect(find.byType(InkWell), findsNWidgets(3));
    },
  );

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
            posterRepositoryProvider.overrideWithValue(repository),
            sessionProvider.overrideWithValue(
              const AsyncData<AuthUser?>(AuthUser(uid: 'u1', email: 'a@b.co')),
            ),
          ],
          child: routedApp(
            routes: routesHosting(const OrdersPlaceholderScreen()),
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
