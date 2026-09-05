import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/model/height_distance_pair.dart';

void main() {
  test('sorting a profile orders by distance, not height', () {
    final pairs = [
      HeightDistancePair(height: 700, distance: 3.0),
      HeightDistancePair(height: 500, distance: 1.0),
      HeightDistancePair(height: 900, distance: 2.0),
    ]..sort();
    expect(pairs.map((p) => p.distance).toList(), [1.0, 2.0, 3.0]);
  });

  test('equal heights at different distances are distinct set members', () {
    final set = <HeightDistancePair>{};
    for (double d = 0.5; d <= 16; d += 0.5) {
      set.add(HeightDistancePair(height: 600, distance: d));
    }
    expect(set.length, 32);
  });
}
