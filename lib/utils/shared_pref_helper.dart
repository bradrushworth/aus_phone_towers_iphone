import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_constants.dart';

class SharedPreferencesHelper {
  static final String kisTelstraVisible = 'isTelstraVisible';
  static final String kisOptusVisible = 'isOptusVisible';
  static final String kisVodafoneVisible = 'isVodafoneVisible';
  static final String kisDenseAirVisible = 'isNBNVisible';
  static final String kisNBNVisible = 'isNBNVisible';
  static final String kisOtherVisible = 'isOtherVisible';

  static final String kis2GVisible = 'is2GVisible';
  static final String kis3GVisible = 'is3GVisible';
  static final String kis4GVisible = 'is4GVisible';
  static final String kis5GVisible = 'is5GVisible';

  static final String kisNOTLTEVisible = 'isNOTLTEVisible';
  static final String kisFDLTEVisible = 'isFDLTEVisible';
  static final String kisTDLTEVisible = 'isTDLTEVisible';

  static final String kisLess700Visible = 'isLess700Visible';
  static final String kisBet700_100Visible = 'isBet700_100Visible';
  static final String kisBet1_2Visible = 'isBet1_2Visible';
  static final String kisBet2_3Visible = 'isBet2_3Visible';
  static final String kisGreater3Visible = 'isGreater3Visible';

  static final String kisMetroVisible = 'isMetroVisible';
  static final String kisUrbanVisible = 'isUrbanVisible';
  static final String kisSuburbanVisible = 'isSuburbanVisible';
  static final String kisOpenVisible = 'isOpenVisible';

  static final String ksignalStrengthSelection = 'signalStrenghtSelection';

  static final String kisTelcoVisible = 'isTelcoVisible';
  static final String kisRadioVisible = 'isRadioVisible';
  static final String kisTVVisible = 'isTVVisible';
  static final String kisCivilVisible = 'isCivilVisible';
  static final String kisPagerVisible = 'isPagerVisible';
  static final String kisCBRSVisible = 'isCBRSVisible';
  static final String kisAviationVisible = 'isAviationVisible';

  static final String kshowPolygonBorders = 'showPolygonBorders';
  static final String kMapMode = 'mapMode';
  static final String kdrawPolygonsOnClick = 'drawPolygonsOnClick';
  static final String kcalculateTerrain = 'calculateTerrain';

  static final String betaLaunchPopup = 'betaLaunchPopup';

  ///-------------------------
  ///Dedicated methods
  ///------------------------
  static bool getMenuStatus(
      {required String key, required SharedPreferences prefs}) {
    return prefs.containsKey(key) ? prefs.getBool(key)! : true;
  }

  static bool getMenuStatusOtherThanTelco(
      {required String key, required SharedPreferences prefs}) {
    return prefs.containsKey(key) ? prefs.getBool(key)! : false;
  }

  static int getRadiationModel({required String key, required SharedPreferences prefs}) {
    //return prefs.getInt(key ?? kSuburbanRadiationModel);
    return prefs.containsKey(key)
        ? prefs.getInt(key)!
        : kSuburbanRadiationModel;
  }

  static int getSignalStrength({required String key, required SharedPreferences prefs}) {
    //return prefs.getInt(key ?? kSuburbanRadiationModel);
    return prefs.containsKey(key)
        ? prefs.getInt(key)!
        : kWeakSignalStrength;
  }

  static int getMapMode({required String key, required SharedPreferences prefs}) {
    //return prefs.getInt(key ?? kSuburbanRadiationModel);
    return prefs.containsKey(key)
        ? prefs.getInt(key)!
        : kMapModeTerrain;
  }

  ///-----------------
  ///Save boolean values
  ///------------------
  static bool getBoolean(String key, SharedPreferences prefs) {
    return prefs.containsKey(key) ? prefs.getBool(key)! : false;
  }

  static Future<bool> saveBoolean(
      {required String key,
      required bool value,
      required SharedPreferences prefs}) {
    return prefs.setBool(key, value);
  }

  ///--------------------------
  /// SAVE STRINGS
  ///--------------------------
  static String getString(String key, SharedPreferences prefs) {
    return prefs.getString(key) ?? '';
  }

  static Future<bool> setString(
      String key, String value, SharedPreferences prefs) {
    return prefs.setString(key, value);
  }

  ///--------------------------
  /// SAVE INTEGERS
  ///--------------------------
  static int getInt({required String key, required SharedPreferences prefs}) {
    return prefs.getInt(key) ?? 0;
  }

  static Future<bool> setInt({required String key, required int value, required SharedPreferences prefs}) {
    return prefs.setInt(key, value);
  }

  ///--------------------------
  /// SAVE DOUBLE
  ///--------------------------
  static double getDouble(String key, SharedPreferences prefs) {
    return prefs.getDouble(key) ?? 0.0;
  }

  static Future<bool> setDouble(
      String key, double value, SharedPreferences prefs) {
    return prefs.setDouble(key, value);
  }
}
