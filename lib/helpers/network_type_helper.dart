class NetworkTypeHelper {
  late String value;

  static List<int> gsmBars = [-89, -97, -103, -107]; // CellSignalStrengthGsm
  static List<int> umtsBars = [-77, -87,  -97, -107]; // CellSignalStrengthWcdma
  static List<int> lteBars = [-85, -95, -105, -115]; // Setting RSRP numbers, not RSSI, from CellSignalStrengthLte
  static List<int> nrBars = [-65, -80,  -90, -110]; // Setting RSRP numbers, not RSSI, from CellSignalStrengthNr
  static List<int> otherBars = [-77, -87,  -97, -107];

  // Min Max as per the phone's signal strength numbers
  static List<int> gsmMinMax = [-113, -51];
  static List<int> umtsMinMax = [-113, -51];
  static List<int> lteMinMax = [-140, -44]; // Setting RSRP numbers, not RSSI
  static List<int> nrMinMax = [-140, -44]; // Setting RSRP numbers, not RSSI
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

      case NetworkType.NB_IOT:
        {
          return 'LP';
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

  static bool isRsrp(NetworkType nt) {
    return nt == NetworkType.LTE || nt == NetworkType.NR;
  }
}

enum NetworkType {
  UNKNOWN,
  GSM,
  UMTS,
  LTE,
  NR,
  CDMA,
  NB_IOT,
  OTHER,
}

enum SIGNAL_STRENGTH { MAX, STRONG, GOOD, WEAK }
