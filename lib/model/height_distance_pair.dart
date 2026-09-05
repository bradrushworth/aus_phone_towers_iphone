class HeightDistancePair implements Comparable<HeightDistancePair> {
  final double height;
  final double distance;

  HeightDistancePair({required this.height, required this.distance});

  @override
  bool operator ==(other) {
    return (other is HeightDistancePair) &&
        other.height == height &&
        other.distance == distance;
  }

  @override
  int get hashCode => height.hashCode ^ distance.hashCode;

  /// Ordered by distance from the site, then height. A bearing's profile has one sample per
  /// distance, so distance is the natural key; ordering by height alone (the original code) made
  /// callers that sort by [compareTo] treat the tallest samples as if they were the nearest,
  /// which is only true by coincidence.
  @override
  int compareTo(HeightDistancePair other) {
    final byDistance = distance.compareTo(other.distance);
    return byDistance != 0 ? byDistance : height.compareTo(other.height);
  }
}
