enum LteType {
  NOT_LTE,
  FD_LTE,
  TD_LTE,
}

class LteTypeHelper {
  static String getName(LteType lteType) {
    return lteType.toString().split('.').last;
  }

  static String getFirstTwoChars(LteType lteType) {
    if (lteType == LteType.NOT_LTE) return "  ";
    return getName(lteType).substring(0, 2);
  }
}
