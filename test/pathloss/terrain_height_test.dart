import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/pathloss/terrain_height.dart';

List<int> medians(int v) => List<int>.filled(TerrainHeight.bearings, v);

void main() {
  test('bearingIndex rounds to the nearest 15 degrees', () {
    expect(TerrainHeight.bearingIndex(0), 0);
    expect(TerrainHeight.bearingIndex(7.4), 0);
    expect(TerrainHeight.bearingIndex(7.6), 1);
    expect(TerrainHeight.bearingIndex(345), 23);
    expect(TerrainHeight.bearingIndex(359), 0);
    expect(TerrainHeight.bearingIndex(360), 0);
    expect(TerrainHeight.bearingIndex(-15), 23);
  });
  test('hilltop site gains its height above the median terrain', () {
    expect(TerrainHeight.effectiveHeightM(30, 800, medians(600), 90), 230.0);
  });
  test('valley site loses height but never below the floor', () {
    expect(TerrainHeight.effectiveHeightM(30, 580, medians(600), 0), 10.0);
    expect(TerrainHeight.effectiveHeightM(30, 500, medians(600), 0), TerrainHeight.minEffectiveHeightM);
  });
  test('ceiling applies to extreme summits', () {
    expect(TerrainHeight.effectiveHeightM(30, 2000, medians(400), 0), TerrainHeight.maxEffectiveHeightM);
  });
  test('without terrain the antenna height is used, clamped', () {
    expect(TerrainHeight.effectiveHeightM(30, null, null, 0), 30.0);
    expect(TerrainHeight.effectiveHeightM(30, 800, null, 0), 30.0);
    expect(TerrainHeight.effectiveHeightM(0, null, null, 0), TerrainHeight.minEffectiveHeightM);
  });
  test('per-bearing median is picked by bearing', () {
    final m = medians(600)..[6] = 700;
    expect(TerrainHeight.effectiveHeightM(30, 800, m, 90), 130.0);
    expect(TerrainHeight.effectiveHeightM(30, 800, m, 180), 230.0);
  });
  test('csv round-trips and rejects the wrong length', () {
    final m = medians(12)..[3] = -4;
    expect(TerrainHeight.parseCsv(TerrainHeight.toCsv(m), TerrainHeight.bearings), m);
    expect(TerrainHeight.parseCsv('1,2,3', TerrainHeight.bearings), isNull);
    expect(TerrainHeight.parseCsv('a,b', 2), isNull);
    expect(TerrainHeight.parseCsv(null, 2), isNull);
  });
}
