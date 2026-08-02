import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posternung/core/theme/app_colors.dart';
import 'package:posternung/core/theme/app_text_styles.dart';
import 'package:posternung/core/widgets/app_status_view.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    // The app's real theme is an unstyled `ColorScheme.fromSeed(deepPurple)`
    // — matching main.dart — so a widget that leans on Material defaults
    // instead of the app's tokens shows up here rather than on a device.
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
    ),
    home: Scaffold(body: child),
  );

  testWidgets('renders icon, title and body; omits the action when there is '
      'nothing to do', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppStatusView(
          icon: Icons.inbox_outlined,
          title: 'ว่างเปล่า',
          body: 'ยังไม่มีอะไรตรงนี้',
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('ว่างเปล่า'), findsOneWidget);
    expect(find.text('ยังไม่มีอะไรตรงนี้'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('the action button fires its callback', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      wrap(
        AppStatusView(
          icon: Icons.wifi_off_rounded,
          tone: AppStatusTone.error,
          title: 'โหลดไม่สำเร็จ',
          body: 'เน็ตหลุด',
          actionLabel: 'ลองใหม่อีกครั้ง',
          actionIcon: Icons.refresh_rounded,
          onAction: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('ลองใหม่อีกครั้ง'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('every piece of text carries an AppTextStyles token — the '
      'reason this widget exists is that hand-rolled state views fell back '
      'to the Material default font/colour', (tester) async {
    await tester.pumpWidget(
      wrap(
        AppStatusView(
          icon: Icons.wifi_off_rounded,
          tone: AppStatusTone.error,
          title: 'โหลดไม่สำเร็จ',
          body: 'เน็ตหลุด',
          actionLabel: 'ลองใหม่อีกครั้ง',
          onAction: () {},
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('โหลดไม่สำเร็จ')).style,
      AppTextStyles.statusTitle,
    );
    expect(
      tester.widget<Text>(find.text('เน็ตหลุด')).style,
      AppTextStyles.statusBody,
    );
    expect(
      tester.widget<Text>(find.text('ลองใหม่อีกครั้ง')).style,
      AppTextStyles.statusActionLabel,
    );
  });

  testWidgets('tone drives the icon colour: error is red, neutral never is', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const AppStatusView(
          icon: Icons.wifi_off_rounded,
          tone: AppStatusTone.error,
          title: 't',
          body: 'b',
        ),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.wifi_off_rounded)).color,
      AppColors.accentRed,
    );

    await tester.pumpWidget(
      wrap(
        const AppStatusView(
          icon: Icons.search_off_rounded,
          title: 't',
          body: 'b',
        ),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.search_off_rounded)).color,
      AppColors.textSecondary,
    );
  });
}
