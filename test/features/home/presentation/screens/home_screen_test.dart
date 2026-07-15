import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/auth/presentation/providers/auth_providers.dart';
import 'package:posternung/features/home/presentation/screens/home_screen.dart';

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
  late FakeAuthViewModel viewModel;

  Widget wrap() {
    viewModel = FakeAuthViewModel();
    return ProviderScope(
      overrides: [authViewModelProvider.overrideWith(() => viewModel)],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  // The Home screen is a lazy CustomScrollView, so below-the-fold sections
  // aren't laid out at the default 800x600 test surface. Tests that assert on
  // (or tap) content across all sections grow the surface so every sliver is
  // built and on-screen.
  Future<void> useTallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('renders the title, section headings, and mock content', (
    tester,
  ) async {
    await useTallSurface(tester);
    await tester.pumpWidget(wrap());

    expect(find.text('Cinevault 2'), findsOneWidget);
    expect(find.text('Featured Collections'), findsOneWidget);
    expect(find.text('Ending Soon'), findsOneWidget);
    expect(find.text('All Posters'), findsOneWidget);
    expect(find.text('70s Sci-Fi Masterpieces'), findsOneWidget);
    expect(find.text('Blade Runner'), findsOneWidget);
  });

  testWidgets(
    'tapping a not-yet-built nav tab shows the coming-soon snackbar',
    (tester) async {
      await tester.pumpWidget(wrap());

      await tester.tap(find.text('Search'));
      await tester.pump();

      expect(find.text('ฟีเจอร์นี้กำลังจะมาเร็ว ๆ นี้'), findsOneWidget);
    },
  );

  testWidgets('tapping "Load More Titles" shows the coming-soon snackbar', (
    tester,
  ) async {
    await useTallSurface(tester);
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Load More Titles'));
    await tester.pump();

    expect(find.text('ฟีเจอร์นี้กำลังจะมาเร็ว ๆ นี้'), findsOneWidget);
  });

  testWidgets('tapping Profile signs out', (tester) async {
    await tester.pumpWidget(wrap());

    await tester.tap(find.text('Profile'));
    await tester.pump();

    expect(viewModel.signOutCalled, isTrue);
  });

  testWidgets(
    'top bar collapses continuously on scroll down and recovers on scroll up',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // SliverPersistentHeader(floating: true) is backed by more than one
      // RenderSliverPersistentHeader (an inner wrapper); the live one carries
      // the actual paint extent, so read the max across them.
      double paintExtent() => tester.allRenderObjects
          .whereType<RenderSliverPersistentHeader>()
          .map((h) => h.geometry?.paintExtent ?? 0.0)
          .reduce(math.max);

      final fullExtent = paintExtent();
      expect(fullExtent, greaterThan(0));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pump();
      final collapsedExtent = paintExtent();
      expect(collapsedExtent, lessThan(fullExtent));

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 150));
      await tester.pump();
      expect(paintExtent(), greaterThan(collapsedExtent));
    },
  );
}
