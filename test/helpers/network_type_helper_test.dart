import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';

// The Android side of these numbers is
// aus_phone_towers_java app/src/main/java/au/com/bitbot/phonetowers/utilities/NetworkType.java
// (gsmBars, umtsBars, lteBars, nrBars). The rule is "keep it one definition", so
// if either side changes, change the other in the same release.
void main() {
  test('GSM bars match Android NetworkType.gsmBars', () {
    expect(NetworkTypeHelper.gsmBars, [-89, -97, -103, -107]);
  });

  test('UMTS bars match Android NetworkType.umtsBars', () {
    expect(NetworkTypeHelper.umtsBars, [-77, -87, -97, -107]);
  });

  test('LTE bars match Android NetworkType.lteBars', () {
    expect(NetworkTypeHelper.lteBars, [-85, -95, -105, -115]);
  });

  test('NR bars match Android NetworkType.nrBars (retuned 2026-08-23)', () {
    expect(NetworkTypeHelper.nrBars, [-80, -90, -100, -110]);
  });
}
