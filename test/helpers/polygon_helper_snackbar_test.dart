import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Regression: queryForSignalPolygon used to force-unwrap its nullable showSnackBar callback.
  // refreshPolygons, switchTerrainAwareness and clearSitePatterns all call it without one, so
  // every signal-strength / filter / terrain change threw "Null check operator used on a null
  // value" once a coverage polygon was drawn — aborting the redraw part-way through. The
  // fallback must therefore be safe to call even with no live map state.
  test('defaultShowSnackBar is a no-op when there is no map state', () {
    expect(() => defaultShowSnackBar(message: 'no map yet'), returnsNormally);
    expect(
        () => defaultShowSnackBar(
            message: 'with args', duration: const Duration(seconds: 2), isDismissible: true),
        returnsNormally);
  });

  test('defaultShowSnackBar satisfies the ShowSnackBar contract', () {
    // Assigning it to the typedef is what queryForSignalPolygon relies on.
    final ShowSnackBar callback = defaultShowSnackBar;
    expect(() => callback(message: 'via typedef'), returnsNormally);
  });
}
