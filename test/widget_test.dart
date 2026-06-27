import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whack_mole/main.dart';
import 'package:whack_mole/widgets/mole_widget.dart';

void main() {
  testWidgets('Cute Whack-a-Mole App UI rendering and flow test', (WidgetTester tester) async {
    // Mock SharedPreferences and MoleImageCache loaded state
    SharedPreferences.setMockInitialValues({});
    MoleImageCache.loaded = true;

    // 1. Pump MainApp
    await tester.pumpWidget(const MainApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 2. Verify Home Screen is rendered
    expect(find.text('可愛打地鼠'), findsNWidgets(2)); // We have background outline + foreground fill text!
    expect(find.text('開始遊戲'), findsOneWidget);
    expect(find.text('最高得分: 0'), findsOneWidget);

    // 3. Tap '開始遊戲' button
    await tester.tap(find.text('開始遊戲'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 4. Verify game screen loaded
    // HUD element: "得分: 0"
    expect(find.text('得分: 0'), findsOneWidget);
    // Pause button icon
    expect(find.byIcon(Icons.pause), findsOneWidget);
    // Board grid should exist
    expect(find.byType(GridView), findsOneWidget);
  });
}
