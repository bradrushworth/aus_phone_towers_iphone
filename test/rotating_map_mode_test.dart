import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/ui/map_common.dart';

void main() {
  test('fromIndex round-trips every mode', () {
    for (final m in RotatingMapMode.values) {
      expect(RotatingMapMode.fromIndex(m.index), m);
    }
  });

  test('fromIndex falls back to Travel direction for missing or bad values', () {
    expect(RotatingMapMode.fromIndex(null), RotatingMapMode.travelDirection);
    expect(RotatingMapMode.fromIndex(-1), RotatingMapMode.travelDirection);
    expect(RotatingMapMode.fromIndex(99), RotatingMapMode.travelDirection);
  });
}
