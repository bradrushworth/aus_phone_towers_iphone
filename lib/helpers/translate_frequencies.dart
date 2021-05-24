import 'dart:math' as math;

class TranslateFrequencies {
  static double log2(int n) {
    return (math.log(n) / math.log(2));
  }

  static String formatFrequency(double freq, bool showDecimal) {
    if (freq == null || freq == 0) {
      return "Unknown";
    }
    // Only use e.g. MHz when over 10,000 kHz
    if (freq >= 10 * 1000 * 1000 * 1000)
      return '${(1.0 * freq / 1000 / 1000 / 1000).toStringAsFixed(2)} GHz';
    if (freq >= 10 * 1000 * 1000) {
      if (showDecimal) {
        return '${(1.0 * freq / 1000 / 1000).toStringAsFixed(1)} MHz';
      } else {
        return '${(freq / 1000 / 1000).toStringAsFixed(0)} MHz';
      }
    }
    if (freq >= 10 * 1000) {
      if (showDecimal) {
        return '${(1.0 * freq / 1000).toStringAsFixed(1)} kHz';
      } else {
        return '${(freq / 1000).toStringAsFixed(0)} kHz';
      }
    }
    return '$freq Hz';
  }

  static String formatBandwidth(double freq, bool showDecimal) {
    if (freq == null || freq == 0) {
      return "Unknown";
    }
    // Only use e.g. MHz when over 10,000 kHz
    if (freq >= 10 * 1000 * 1000 * 1000) {
      return '${(1.0 * freq / 1000 / 1000 / 1000).toStringAsFixed(2)} GHz';
    }
    if (showDecimal) {
      return '${(1.0 * freq / 1000 / 1000).toStringAsFixed(1)} MHz';
    } else {
      return '${(freq / 1000 / 1000).toStringAsFixed(0)} MHz';
    }
  }
}
