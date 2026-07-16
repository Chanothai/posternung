import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/features/home/presentation/widgets/home_looping_carousel.dart';

void main() {
  const items = ['A', 'B', 'C'];

  Widget wrap() {
    return MaterialApp(
      home: Scaffold(
        body: HomeLoopingCarousel<String>(
          items: items,
          itemWidth: 100,
          spacing: 10,
          height: 50,
          itemBuilder: (context, item) => Text(item),
        ),
      ),
    );
  }

  List<String?> builtTexts(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();

  testWidgets('starts at rest showing the real first item, no exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());

    expect(tester.takeException(), isNull);
    // The default test surface is wide enough to fit more than 3 slots, so
    // the 3-item real list legitimately repeats within the viewport at rest
    // — assert presence, not uniqueness (same reasoning as home_screen_test).
    expect(find.text('A'), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'dragging far in either direction always resolves to a real item via modulo',
    (tester) async {
      await tester.pumpWidget(wrap());

      for (var i = 0; i < 5; i++) {
        await tester.drag(find.byType(ListView), const Offset(-2000, 0));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final texts = builtTexts(tester);
        expect(texts, isNotEmpty);
        expect(texts, everyElement(items.contains));
      }

      for (var i = 0; i < 10; i++) {
        await tester.drag(find.byType(ListView), const Offset(2000, 0));
        await tester.pump();

        expect(tester.takeException(), isNull);
        final texts = builtTexts(tester);
        expect(texts, isNotEmpty);
        expect(texts, everyElement(items.contains));
      }
    },
  );
}
