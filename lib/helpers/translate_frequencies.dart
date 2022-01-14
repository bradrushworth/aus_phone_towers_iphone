import 'dart:math';

double log2(int n) => (log(n) / log(2));
double log10(num x) => log(x) / ln10;
double logBase(num x, num base) => log(x) / log(base);

class TranslateFrequencies {

  static String formatFrequency(double freq, bool showDecimal) {
    if (freq == null || freq == 0) {
      return "Unknown";
    }
    // Only use e.g. MHz when over 10,000 kHz
    if (freq >= 10 * 1000 * 1000 * 1000)
      if (showDecimal) {
        return '${(1.0 * freq / 1000 / 1000 / 1000).toStringAsFixed(1)} GHz';
    } else {
        return '${(freq / 1000 / 1000 / 1000).toStringAsFixed(0)} GHz';
      }
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

  /**
   * https://arimas.com/2017/11/06/lte-rsrp-rsrq-rssi-calculator/
   * @param bandwidth in Hz
   * @return N = Number of RBs as per Channel Bandwidth for LTE
   */
  static int numberOfRbsPerLteChannel(int bandwidth) {
    switch (bandwidth) {
      case 1400000:
        return 6;
      case 3000000:
        return 15;
      case 5000000:
        return 25;
      case 10000000:
        return 50;
      case 15000000:
        return 75;
      case 20000000:
        return 100;
      default:
      // I'm guessing this is a fair assumption
        return 100;
    }
  }

  /**
   * https://arimas.com/2017/11/06/lte-rsrp-rsrq-rssi-calculator/
   * @param bandwidth in Hz
   * @return RSSI adjustment value
   */
  static int convertLteRsrpToRssi(num bandwidth) {
    int N = numberOfRbsPerLteChannel(bandwidth.toInt());
    if (N > 0) {
      return (10 * log10(12 * N)).toInt();
    } else {
      return 0;
    }
  }
}
