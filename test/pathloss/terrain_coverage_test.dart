import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/pathloss/terrain_coverage.dart';

const List<double> _samples = [
  0.50, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 3, 3.5, 4, 4.5, 5.5, 7, 8.5, 10, 13, 16,
];

/// Free-space-like model: budget of 100 dB reaches 10 km, 20 dB per decade.
double _solver(double budget) => 10.0 * math.pow(10, (budget - 100) / 20.0).toDouble();

void main() {
  test('clear path keeps the flat distance', () {
    final r = TerrainCoverage.evaluate(100, _solver, (d) => 0, _samples);
    expect(r.outerKm, closeTo(10.0, 1e-9));
    expect(r.shadows, isEmpty);
  });

  test('ridge shadows the valley but the far slope is drawn', () {
    // Ridge at 3 km: everything from 3.5 to 8.5 km is behind it (30 dB), the far slope at
    // 10 km sees the tower again. Budget 100 dB reaches 10 km on a clear path.
    double loss(double d) => (d >= 3.5 && d <= 8.5) ? 30 : 0;
    final r = TerrainCoverage.evaluate(100, _solver, loss, _samples);
    expect(r.outerKm, closeTo(10.0, 1e-9));
    expect(r.shadows.length, 1);
    expect(r.shadows[0].nearKm, closeTo((3.0 + 3.5) / 2, 1e-9));
    expect(r.shadows[0].farKm, closeTo((8.5 + 10.0) / 2, 1e-9));
  });

  test('mild obstruction is paid for, not cut off', () {
    // 10 dB beyond 5 km: the budget left (90 dB) still reaches 3.16 km, less than 5.5, so
    // those points are uncovered; nothing beyond is covered either -> outer refines between
    // 4.5 and 5.5.
    double loss(double d) => d > 5 ? 10 : 0;
    final r = TerrainCoverage.evaluate(100, _solver, loss, _samples);
    expect(r.outerKm, greaterThanOrEqualTo(4.5));
    expect(r.outerKm, lessThanOrEqualTo(5.5));
    expect(r.shadows, isEmpty);
  });

  test('weaker threshold reaches further through the same terrain', () {
    double loss(double d) => d > 2 ? 12 : 0;
    final strong = TerrainCoverage.evaluate(90, _solver, loss, _samples).outerKm;
    final weak = TerrainCoverage.evaluate(110, _solver, loss, _samples).outerKm;
    expect(weak, greaterThan(strong));
  });

  test('everything blocked falls back to the minimum', () {
    final r = TerrainCoverage.evaluate(100, _solver, (d) => 200, _samples);
    expect(r.outerKm, closeTo(TerrainCoverage.minOuterKm, 1e-9));
    expect(r.shadows, isEmpty);
  });

  test('unusable solver answer is passed through', () {
    final r = TerrainCoverage.evaluate(100, (budget) => double.nan, (d) => 0, _samples);
    expect(r.outerKm.isNaN, isTrue);
    expect(r.shadows, isEmpty);
  });
}
