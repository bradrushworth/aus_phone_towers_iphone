import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phonetowers/main.dart' as app;
import 'package:phonetowers/ui/widgets/navigation_menu.dart';
import 'package:phonetowers/ui/widgets/option_menu.dart';
import 'package:phonetowers/utils/strings.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized()
          as IntegrationTestWidgetsFlutterBinding;

  testWidgets('verify menus', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    app.main();

    // Trigger a frame.
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AlertDialog, Strings.betaLaunchPopupDesc),
        findsOneWidget);

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is SingleRowItem &&
            (widget as SingleRowItem).title == Strings.donateSmall,
      ),
      findsOneWidget,
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is LicenceesMenuItem &&
            (widget as LicenceesMenuItem).valueName == Strings.optus,
      ),
      findsOneWidget,
    );

  });
}
