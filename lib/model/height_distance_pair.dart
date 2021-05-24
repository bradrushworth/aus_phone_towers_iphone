class HeightDistancePair extends Comparable<HeightDistancePair> {
  final double height;
  final double distance;

  HeightDistancePair({this.height, this.distance});

  @override
  bool operator ==(other) {
    return (other is HeightDistancePair) &&
        other.height == height &&
        other.distance == distance;
  }

  @override
  int get hashCode => height.hashCode ^ distance.hashCode;

  @override
  int compareTo(HeightDistancePair other) {
    return height.compareTo(other.height);
  }
}
