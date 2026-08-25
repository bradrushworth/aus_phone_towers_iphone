import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/utils/geohash_cell.dart';

void main() {
  group('geohashEncode', () {
    test('agrees with the Android app character for character', () {
      // These exact literals are asserted by the Android suite's GeohashCellTest too. Both apps
      // must return the same density for the same coordinate, which starts here. Do not update one
      // side without the other - that is the whole point of duplicating them.
      expect(geohashEncode(-33.8568, 151.2153, 7), 'r3gx2ux'); // Sydney Opera House
      expect(geohashEncode(-37.8136, 144.9631, 7), 'r1r0fsn'); // Melbourne
      expect(geohashEncode(-25.3444, 131.0369, 7), 'qgmpvf4'); // Uluru
    });

    test('prefixes nest, which is what makes longest-prefix lookup work', () {
      final String g7 = geohashEncode(-33.8568, 151.2153, 7);
      expect(g7.length, 7);
      expect(g7.startsWith(geohashEncode(-33.8568, 151.2153, 4)), isTrue);
    });
  });
}
