/// Effective antenna height: the height above average terrain at a site.
///
/// The "hb" rule (height above the average terrain) adjusts antenna height by the difference
/// between the site's ground elevation and the median terrain elevation in the bearing direction,
/// clamped to [minEffectiveHeightM] and [maxEffectiveHeightM].
///
/// This accounts for hilltop gain (negative median delta) and valley loss (positive delta).
/// The former double count of samples at SAMPLE_DISTANCES has been consolidated into a single
/// 19-element profile per bearing, indexed by that [GetElevation.SAMPLE_DISTANCES] array.
class TerrainHeight {
  static const int bearings = 24;
  static const double bearingStepDegrees = 360 / bearings;
  static const double minEffectiveHeightM = 5;
  static const double maxEffectiveHeightM = 1000;

  static int bearingIndex(double bearingDegrees) {
    double b = bearingDegrees % 360;
    if (b < 0) b += 360;
    return (b / bearingStepDegrees).round() % bearings;
  }

  static double effectiveHeightM(double antennaHeightM, int? groundM, List<int>? bearingMedianM, double bearingDegrees) {
    double h = antennaHeightM;
    if (groundM != null && bearingMedianM != null && bearingMedianM.length == bearings) {
      h += groundM - bearingMedianM[bearingIndex(bearingDegrees)];
    }
    return h.clamp(minEffectiveHeightM, maxEffectiveHeightM).toDouble();
  }

  static List<int>? parseCsv(String? csv, int expectedCount) {
    if (csv == null) return null;
    final parts = csv.trim().split(',');
    if (parts.length != expectedCount) return null;
    final out = <int>[];
    for (final p in parts) {
      final v = int.tryParse(p.trim());
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  static String toCsv(List<int> values) => values.join(',');
}
