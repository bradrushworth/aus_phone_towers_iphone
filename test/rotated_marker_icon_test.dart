import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/telco_helper.dart';

/// The per-telco marker lean must be baked into the icon bitmap: google_maps_flutter_web
/// ignores Marker.rotation, so on the web build every co-located telco pin rendered bolt
/// upright over the others — the Vodafone pin was completely hidden behind the Telstra one.
///
/// The bitmap must also be CROPPED to the rotated pin's tight bounding box, with the tip
/// exposed as the Marker anchor: markers hit-test on the whole icon rectangle (transparent
/// pixels included), and a first version that centred every pin on the same swept-circle
/// square made all co-located tap targets identical — every tap selected the top of the
/// stack (always Telstra). Tight boxes lean each telco's tap target to its own side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rotated icons render, are cached, and expose a valid anchor', () async {
    for (final telco in [Telco.Telstra, Telco.Optus, Telco.Vodafone]) {
      final bytes = await TelcoHelper.getRotatedIcon(telco);
      expect(bytes, isNotEmpty, reason: '$telco icon must decode and re-encode');
      final anchor = TelcoHelper.rotatedIconAnchor(telco);
      expect(anchor.dx, inInclusiveRange(0.0, 1.0), reason: '$telco anchor.dx');
      expect(anchor.dy, inInclusiveRange(0.0, 1.0), reason: '$telco anchor.dy');
      // Thousands of markers are built while panning: the bytes must come from the cache.
      final again = await TelcoHelper.getRotatedIcon(telco);
      expect(identical(bytes, again), isTrue, reason: '$telco icon must be cached');
    }
  });

  test('tight crop leans each tap target to its own side of the shared tip', () async {
    await TelcoHelper.getRotatedIcon(Telco.Telstra);
    await TelcoHelper.getRotatedIcon(Telco.Optus);
    await TelcoHelper.getRotatedIcon(Telco.Vodafone);

    // Optus is upright: the crop is the original pin, tip at bottom-centre, no growth.
    expect(TelcoHelper.rotatedIconWidthFactor(Telco.Optus), closeTo(1.0, 0.1));
    final optus = TelcoHelper.rotatedIconAnchor(Telco.Optus);
    expect(optus.dx, closeTo(0.5, 0.05));
    expect(optus.dy, closeTo(1.0, 0.05));

    // Telstra leans -60deg (head to the LEFT of the tip): its box extends left, so the
    // tip sits near the box's right edge. Vodafone (+60deg) is the mirror image. This is
    // exactly what keeps their tap rectangles from covering each other's pin heads.
    expect(TelcoHelper.rotatedIconWidthFactor(Telco.Telstra), greaterThan(1.0));
    expect(TelcoHelper.rotatedIconWidthFactor(Telco.Vodafone), greaterThan(1.0));
    final telstra = TelcoHelper.rotatedIconAnchor(Telco.Telstra);
    final vodafone = TelcoHelper.rotatedIconAnchor(Telco.Vodafone);
    expect(telstra.dx, greaterThan(0.7), reason: 'Telstra tip near its right edge');
    expect(vodafone.dx, lessThan(0.3), reason: 'Vodafone tip near its left edge');
    // The tip is the anchor in every case: the pin still plants exactly on the site.
    for (final Offset a in [telstra, vodafone]) {
      expect(a.dy, inInclusiveRange(0.5, 1.0), reason: 'tip in the lower half');
    }
  });
}
