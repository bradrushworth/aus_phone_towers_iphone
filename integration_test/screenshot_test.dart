import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:phonetowers/main.dart' as app;

Future<void> main() async {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized()
          as IntegrationTestWidgetsFlutterBinding;

  testWidgets('take screenshot', (WidgetTester tester) async {
    // Build the app and pump a frame.
    app.main();
    await tester.pumpAndSettle();

    // This is required prior to taking the screenshot (Android only).
    await binding.convertFlutterSurfaceToImage();

    // Trigger a frame.
    await tester.pump(Duration(seconds: 3)); // Render another frame in 3s
    await binding.takeScreenshot('screenshot');
  }, timeout: Timeout(Duration(minutes: 2)));
}
