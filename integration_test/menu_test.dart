import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phonetowers/main.dart' as app;
import 'package:phonetowers/ui/widgets/option_menu.dart';
import 'package:phonetowers/utils/strings.dart';

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verify menus', (WidgetTester tester) async {
    // Build our app.
    app.main();

    // Trigger a frame.
    await tester.pumpAndSettle(Duration(seconds: 3));
    // The "This is a preview! / still under development" launch dialog was removed, so there is
    // nothing to dismiss here any more — the map is interactive on first frame. Assert that
    // directly, so this test fails again if a blocking startup modal ever comes back.
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pump();
    expect(
      find.byTooltip(Strings.calculate_terrain),
      findsOneWidget,
    );

    await tester.pump();
    final Finder rightHandMenu = find.byType(OptionsMenu);
    await tester.tap(rightHandMenu);

    await tester.pumpAndSettle();
    // expect(
    //   find.byIcon(Icons.play_arrow,
    //     skipOffstage: false,
    //   ),
    //   findsWidgets,
    // );

    // await tester.pump();
    // expect(
    //   find.widgetWithText(Ink, Strings.optus,
    //     skipOffstage: false,
    //   ),
    //   findsOneWidget,
    // );
  }, timeout: Timeout(Duration(minutes: 2)));
}
