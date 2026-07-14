import 'dart:async';

import 'package:flutter/material.dart';
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

  testWidgets('renders the title, section headings, and mock content', (
    tester,
  ) async {
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
    await tester.pumpWidget(wrap());

    await tester.scrollUntilVisible(
      find.text('Load More Titles'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
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
}
