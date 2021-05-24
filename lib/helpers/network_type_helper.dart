class NetworkTypeHelper {
  String value;
  static List<int> gsmBars = [-79, -89, -99, -105];
  static List<int> umtsBars = [-81, -91, -101, -107];
  static List<int> lteBars = [
    -72,
    -79,
    -89,
    -104
  ]; // Setting RSSI numbers, not RSRP
  static List<int> nrBars = [
    -72,
    -79,
    -89,
    -104
  ]; // Setting RSSI numbers, not RSRP
  static List<int> otherBars = [-74, -84, -94, -104];

  // Min Max as per the phone's signal strength numbers
  static List<int> gsmMinMax = [-113, -51];
  static List<int> umtsMinMax = [-113, -51];
  static List<int> lteMinMax = [-111, -35]; // Setting RSSI numbers, not RSRP
  static List<int> nrMinMax = [-111, -35]; // Setting RSSI numbers, not RSRP
  static List<int> otherMinMax = [-113, -51];

  static List<int> getNetworkBars(NetworkType networkType) {
    if (networkType == NetworkType.GSM) {
      return gsmBars;
    }
    if (networkType == NetworkType.UMTS) {
      return umtsBars;
    }
    if (networkType == NetworkType.LTE) {
      return lteBars;
    }
    if (networkType == NetworkType.NR) {
      return nrBars;
    }
    return otherBars;
  }

  int getMinSignal(NetworkType networkType) {
    if (networkType == NetworkType.GSM) {
      return gsmMinMax[0];
    }
    if (networkType == NetworkType.UMTS) {
      return umtsMinMax[0];
    }
    if (networkType == NetworkType.LTE) {
      return lteMinMax[0];
    }
    if (networkType == NetworkType.NR) {
      return nrMinMax[0];
    }
    return otherMinMax[0];
  }

  int getMaxSignal(NetworkType networkType) {
    if (networkType == NetworkType.GSM) {
      return gsmMinMax[1];
    }
    if (networkType == NetworkType.UMTS) {
      return umtsMinMax[1];
    }
    if (networkType == NetworkType.LTE) {
      return lteMinMax[1];
    }
    if (networkType == NetworkType.NR) {
      return nrMinMax[1];
    }
    return otherMinMax[1];
  }

  static String resolveNetworkToName(NetworkType networkType) {
    switch (networkType) {
      case NetworkType.UNKNOWN:
        {
          return '??';
        }
        break;

      case NetworkType.GSM:
        {
          return '2G';
        }
        break;

      case NetworkType.UMTS:
        {
          return '3G';
        }
        break;

      case NetworkType.LTE:
        {
          return '4G';
        }
        break;

      case NetworkType.NR:
        {
          return '5G';
        }
        break;

      case NetworkType.CDMA:
        {
          return 'CD';
        }
        break;

      case NetworkType.OTHER:
        {
          return 'OT';
        }
        break;

      default:
        {
          return '??';
        }
        break;
    }
  }
}

enum NetworkType {
  UNKNOWN,
  GSM,
  UMTS,
  LTE,
  NR,
  CDMA,
  OTHER,
}

enum SIGNAL_STRENGTH { MAX, STRONG, GOOD, WEAK }
