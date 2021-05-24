import 'package:dart_numerics/dart_numerics.dart';

enum FrequencyRanges { VERY_LOW, LOW, MEDIUM, HIGH, VERY_HIGH }

class FrequencyRangesHelper {
  static List<int> getValue(FrequencyRanges frequencyRanges) {
    List<int> range = List<int>();
    if (frequencyRanges == FrequencyRanges.VERY_LOW) {
      range = [0, 699];
    }
    if (frequencyRanges == FrequencyRanges.LOW) {
      range = [700, 999];
    }
    if (frequencyRanges == FrequencyRanges.MEDIUM) {
      range = [1000, 2399];
    }
    if (frequencyRanges == FrequencyRanges.HIGH) {
      range = [2400, 3799];
    }
    if (frequencyRanges == FrequencyRanges.VERY_HIGH) {
      range = [3800, int64MaxValue];
    }
    return range;
  }
}
