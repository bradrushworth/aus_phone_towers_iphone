import 'package:phonetowers/utils/app_constants.dart';

typedef void TowerInfoChanged({required String message});

class NavigationMenu {
  static bool isTelstraVisible = true;
  static bool isOptusVisible = true;
  static bool isVodafoneVisible = true;
  static bool isNBNVisible = true;
  static bool isDenseAirVisible = true;
  static bool isOtherVisible = true;

  static bool is2GVisible = true;
  static bool is3GVisible = true;
  static bool is4GVisible = true;
  static bool is5GVisible = true;

  static bool isNOTLTEVisible = true;
  static bool isFDLTEVisible = true;
  static bool isTDLTEVisible = true;

  static bool isLess700Visible = true;
  static bool isBet700_100Visible = true;
  static bool isBet1_2Visible = true;
  static bool isBet2_3Visible = true;
  static bool isGreater3Visible = true;

  static bool isMetroVisible = true;
  static bool isUrbanVisible = true;
  static bool isSuburbanVisible = true;
  static bool isOpenVisible = true;

  static int signalStrengthSelection = kGoodSignalStrength;

  static bool isTelcoVisible = true;
  static bool isRadioVisible = false;
  static bool isTVVisible = false;
  static bool isCivilVisible = false;
  static bool isPagerVisible = false;
  static bool isCBRSVisible = false;
  static bool isAviationVisible = false;
}
