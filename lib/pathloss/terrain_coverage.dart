/// Distance (km) the bound path-loss model reaches for a given link budget (dB).
typedef DistanceSolver = double Function(double linkBudgetDb);

/// Worst knife-edge diffraction loss between the tower and a point this far out, in dB.
typedef ExcessLoss = double Function(double distanceKm);

/// An uncovered run along the bearing, drawn as a hole in the coverage circle.
class Shadow {
  final double nearKm;
  final double farKm;

  const Shadow(this.nearKm, this.farKm);
}

class TerrainCoverageResult {
  final double outerKm;
  final List<Shadow> shadows;

  TerrainCoverageResult(this.outerKm, List<Shadow> shadows) : shadows = List.unmodifiable(shadows);
}

/// Coverage along one bearing once terrain is taken into account, evaluated at every elevation
/// sample independently.
///
/// The previous approach (issue #56) charged the worst knife-edge loss on the path to ONE
/// distance and re-solved, and the re-solve could only shorten. So coverage that returns on the
/// far slope of a valley - the far ridge sees the tower again - could never be drawn, and a ridge
/// at 7 km walked the answer back to 6 km even when 16-19 km was in the clear. Here each sample
/// point asks its own question: with the obstruction between the tower and ME charged, does the
/// budget still reach me? The answer is a set of intervals: an outer radius plus shadow bands
/// that the map draws as holes (see ShadowHoles).
///
/// Pure: the caller binds the path-loss model ([DistanceSolver]) and the terrain
/// ([ExcessLoss], normally GetLicenceHRP.terrainExcessLossDb for the bearing).
///
/// Ported from the Java `au.com.bitbot.phonetowers.utilities.TerrainCoverage`.
class TerrainCoverage {
  TerrainCoverage._();

  /// Drawn when even the nearest sample is blocked: the mast's immediate surroundings.
  static const double minOuterKm = 0.25;

  /// Bisection steps between the last covered and the first uncovered point.
  static const int refineSteps = 3;

  static TerrainCoverageResult evaluate(
    double linkBudgetDb,
    DistanceSolver solver,
    ExcessLoss loss,
    List<double> sampleDistancesKm,
  ) {
    final flat = solver(linkBudgetDb);
    if (!_usable(flat)) {
      return TerrainCoverageResult(flat, []);
    }
    final points = <double>[
      for (final d in sampleDistancesKm)
        if (d < flat) d,
      flat,
    ];

    final covered = List<bool>.filled(points.length, false);
    int lastCovered = -1;
    for (int i = 0; i < points.length; i++) {
      covered[i] = _covered(points[i], linkBudgetDb, solver, loss);
      if (covered[i]) {
        lastCovered = i;
      }
    }
    if (lastCovered < 0) {
      return TerrainCoverageResult(flat < minOuterKm ? flat : minOuterKm, []);
    }

    double outer = points[lastCovered];
    if (lastCovered + 1 < points.length) {
      double lo = outer;
      double hi = points[lastCovered + 1];
      for (int step = 0; step < refineSteps; step++) {
        final mid = (lo + hi) / 2;
        if (_covered(mid, linkBudgetDb, solver, loss)) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      outer = lo;
    }

    final shadows = <Shadow>[];
    int runStart = -1;
    for (int i = 0; i < lastCovered; i++) {
      if (!covered[i] && runStart < 0) {
        runStart = i;
      }
      if (covered[i] && runStart >= 0) {
        final before = runStart == 0 ? 0.0 : points[runStart - 1];
        final near = (before + points[runStart]) / 2;
        final far = (points[i - 1] + points[i]) / 2;
        shadows.add(Shadow(near, far));
        runStart = -1;
      }
    }
    if (runStart >= 0) {
      final before = runStart == 0 ? 0.0 : points[runStart - 1];
      final near = (before + points[runStart]) / 2;
      final far = (points[lastCovered - 1] + points[lastCovered]) / 2;
      shadows.add(Shadow(near, far));
    }
    return TerrainCoverageResult(outer, shadows);
  }

  static bool _covered(double pointKm, double linkBudgetDb, DistanceSolver solver, ExcessLoss loss) {
    final lossDb = loss(pointKm);
    if (lossDb <= 0) {
      return true;
    }
    final reach = solver(linkBudgetDb - lossDb);
    return _usable(reach) && reach >= pointKm;
  }

  static bool _usable(double distanceKm) => distanceKm.isFinite && distanceKm > 0;
}
