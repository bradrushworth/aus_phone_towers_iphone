import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/telco_helper.dart';

/// The per-telco marker lean must be baked into the icon bitmap: google_maps_flutter_web
/// ignores Marker.rotation, so on the web build every co-located telco pin rendered bolt
/// upright over the others — the Vodafone pin was completely hidden behind the Telstra one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rotated icons render, enlarge the canvas, and are cached per telco', () async {
    for (final telco in [Telco.Telstra, Telco.Optus, Telco.Vodafone]) {
      final bytes = await TelcoHelper.getRotatedIcon(telco);
      expect(bytes, isNotEmpty, reason: '$telco icon must decode and re-encode');
      // The square canvas that fits the pin swept about its tip is always wider than the
      // source pin — the Marker width is scaled back up by exactly this factor.
      expect(TelcoHelper.rotatedIconWidthFactor(telco), greaterThan(1.0),
          reason: '$telco width factor');
      // Thousands of markers are built while panning: the bytes must come from the cache.
      final again = await TelcoHelper.getRotatedIcon(telco);
      expect(identical(bytes, again), isTrue, reason: '$telco icon must be cached');
    }
  });
}
