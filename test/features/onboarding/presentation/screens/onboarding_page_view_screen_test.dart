import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:posternung/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:posternung/features/onboarding/presentation/screens/onboarding_page_view_screen.dart';

void main() {
  testWidgets('renders the first page copy, CTA, and skip action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingPageViewScreen())),
    );

    expect(find.text('PosterNung'), findsOneWidget);
    expect(
      find.text(
        'เป็นเจ้าของชิ้นส่วนหนึ่งของ\nประวัติศาสตร์ภาพยนตร์',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('ถัดไป'), findsOneWidget);
    expect(find.text('ข้าม'), findsOneWidget);
  });

  testWidgets('tapping Next advances page 1 to page 2', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPageViewScreen()),
      ),
    );

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(container.read(onboardingControllerProvider), 1);
  });

  testWidgets(
    'tapping Next on the last page shows Get Started and hides skip',
    (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OnboardingPageViewScreen()),
        ),
      );

      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ถัดไป'));
      await tester.pumpAndSettle();

      expect(container.read(onboardingControllerProvider), 2);
      expect(find.text('เริ่มต้นใช้งาน'), findsOneWidget);

      final skip = tester.widget<Opacity>(
        find.ancestor(of: find.text('ข้าม'), matching: find.byType(Opacity)),
      );
      expect(skip.opacity, 0);
    },
  );

  testWidgets('swiping the PageView advances to the next page', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OnboardingPageViewScreen()),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(container.read(onboardingControllerProvider), 1);
  });
}
