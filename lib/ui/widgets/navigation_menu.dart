import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:phonetowers/helpers/frequency_range_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/hex_color.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef void TowerInfoChanged({required String message});
typedef void MenuItemChanged({required bool itemChanged});

class NavigationMenu extends StatefulWidget {
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

  static int signalStrengthSelection = kWeakSignalStrength;

  static bool isTelcoVisible = true;
  static bool isRadioVisible = false;
  static bool isTVVisible = false;
  static bool isCivilVisible = false;
  static bool isPagerVisible = false;
  static bool isCBRSVisible = false;
  static bool isAviationVisible = false;

  @override
  _NavigationMenuState createState() => _NavigationMenuState();

  NavigationMenu();
}

class _NavigationMenuState extends State<NavigationMenu> {
  double screenWidth = 0.0;
  double screenheight = 0.0;

  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    _loadSharedPreference();
  }

  void _loadSharedPreference() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {}); //To give filled value of share pref to children of this widget.
  }

  @override
  Widget build(BuildContext context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenheight = MediaQuery.of(context).size.height;

    return SizedBox(
      width: 200,
      child: Drawer(
        child: ListView(
          children: <Widget>[
            //Licencess
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 10,
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: ListTile(
                title: Text(
                  'Licencees',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            LicenceesMenuItem(
              valueName: Strings.telstra,
              telco: Telco.Telstra,
              isValueVisible: NavigationMenu.isTelstraVisible,
              prefsKey: SharedPreferencesHelper.kisTelstraVisible,
              prefs: prefs!,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isTelstraVisible = itemChanged;
                setTelecomOption();
              },
            ),
            LicenceesMenuItem(
              valueName: Strings.optus,
              telco: Telco.Optus,
              isValueVisible: NavigationMenu.isOptusVisible,
              prefsKey: SharedPreferencesHelper.kisOptusVisible,
              prefs: prefs!,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isOptusVisible = itemChanged;
                setTelecomOption();
              },
            ),
            LicenceesMenuItem(
              valueName: Strings.vodafone,
              telco: Telco.Vodafone,
              isValueVisible: NavigationMenu.isVodafoneVisible,
              prefsKey: SharedPreferencesHelper.kisVodafoneVisible,
              prefs: prefs!,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isVodafoneVisible = itemChanged;
                setTelecomOption();
              },
            ),
            // LicenceesMenuItem( // TODO
            //   valueName: Strings.dense_air,
            //   telco: Telco.Dense_Air,
            //   isValueVisible: NavigationMenu.isDenseAirVisible,
            //   prefsKey: SharedPreferencesHelper.kisDenseAirVisible,
            //   prefs: prefs!,
            //   onMenuItemChanged: ({bool itemChanged}) {
            //     NavigationMenu.isDenseAirVisible = itemChanged;
            //     setTelecomOption();
            //   },
            // ),
            LicenceesMenuItem(
              valueName: Strings.nbn,
              telco: Telco.NBN,
              isValueVisible: NavigationMenu.isNBNVisible,
              prefsKey: SharedPreferencesHelper.kisNBNVisible,
              prefs: prefs!,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isNBNVisible = itemChanged;
                setTelecomOption();
              },
            ),
            LicenceesMenuItem(
              valueName: Strings.other,
              telco: Telco.Other,
              isValueVisible: NavigationMenu.isOtherVisible,
              prefsKey: SharedPreferencesHelper.kisOtherVisible,
              prefs: prefs!,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isOtherVisible = itemChanged;
                setTelecomOption();
              },
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 10,
              ),
            ),

            //2G/3G/4G/5G
            Divider(
              height: 0,
              color: Colors.grey[300],
              thickness: 1.3,
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: ListTile(
                title: Text(
                  '2G/3G/4G/5G',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            NetworkTypeMenu(
              valueName: Strings.twoG_GSM,
              isValueVisible: NavigationMenu.is2GVisible,
              networkType: NetworkType.GSM,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kis2GVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.is2GVisible = itemChanged;
              },
            ),
            NetworkTypeMenu(
              valueName: Strings.threeG_UMTS,
              isValueVisible: NavigationMenu.is3GVisible,
              networkType: NetworkType.UMTS,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kis3GVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.is3GVisible = itemChanged;
              },
            ),
            NetworkTypeMenu(
              valueName: Strings.fourG_LTE,
              isValueVisible: NavigationMenu.is4GVisible,
              networkType: NetworkType.LTE,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kis4GVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.is4GVisible = itemChanged;
              },
            ),
            NetworkTypeMenu(
              valueName: Strings.fiveG_NR,
              isValueVisible: NavigationMenu.is5GVisible,
              networkType: NetworkType.NR,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kis5GVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.is5GVisible = itemChanged;
              },
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 10,
              ),
            ),

            //Multiplex type
            Divider(
              height: 0,
              color: Colors.grey[300],
              thickness: 1.3,
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: ListTile(
                title: Text(
                  Strings.multiplex_type,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            MultiplexTypeMenu(
              valueName: Strings.not_lte,
              isValueVisible: NavigationMenu.isNOTLTEVisible,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisNOTLTEVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isNOTLTEVisible = itemChanged;
                PolygonHelper.displayNotLteMultiplex = itemChanged;
              },
            ),
            MultiplexTypeMenu(
              valueName: Strings.fd_lte,
              isValueVisible: NavigationMenu.isFDLTEVisible,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisFDLTEVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isFDLTEVisible = itemChanged;
                PolygonHelper.displayFdMultiplex = itemChanged;
              },
            ),
            MultiplexTypeMenu(
              valueName: Strings.td_lte,
              isValueVisible: NavigationMenu.isTDLTEVisible,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisTDLTEVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isTDLTEVisible = itemChanged;
                PolygonHelper.displayTdMultiplex = itemChanged;
              },
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 10,
              ),
            ),

            //Frequencies
            Divider(
              height: 0,
              color: Colors.grey[300],
              thickness: 1.3,
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: ListTile(
                title: Text(
                  Strings.frequencies,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            FrequencyTypeMenu(
              valueName: Strings.less_700,
              isValueVisible: NavigationMenu.isLess700Visible,
              frequencyRanges: FrequencyRanges.VERY_LOW,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisLess700Visible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isLess700Visible = itemChanged;
              },
            ),
            FrequencyTypeMenu(
              valueName: Strings.between700_1000,
              isValueVisible: NavigationMenu.isBet700_100Visible,
              frequencyRanges: FrequencyRanges.LOW,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisBet700_100Visible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isBet700_100Visible = itemChanged;
              },
            ),
            FrequencyTypeMenu(
              valueName: Strings.between1_2,
              isValueVisible: NavigationMenu.isBet1_2Visible,
              frequencyRanges: FrequencyRanges.MEDIUM,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisBet1_2Visible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isBet1_2Visible = itemChanged;
              },
            ),
            FrequencyTypeMenu(
              valueName: Strings.between2_3,
              isValueVisible: NavigationMenu.isBet2_3Visible,
              frequencyRanges: FrequencyRanges.HIGH,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisBet2_3Visible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isBet2_3Visible = itemChanged;
              },
            ),
            FrequencyTypeMenu(
              valueName: Strings.greater_than_3,
              isValueVisible: NavigationMenu.isGreater3Visible,
              frequencyRanges: FrequencyRanges.VERY_HIGH,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisGreater3Visible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isGreater3Visible = itemChanged;
              },
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 10,
              ),
            ),

            //Radiation models
            Divider(
              height: 0,
              color: Colors.grey[300],
              thickness: 1.3,
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: ListTile(
                title: Text(
                  Strings.radiation_models,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            RadiationModelTypeMenu(
              valueName: Strings.metropolitan,
              isValueVisible: NavigationMenu.isMetroVisible,
              modelSelection: CityDensity.METRO,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisMetroVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isMetroVisible = itemChanged;
              },
            ),
            RadiationModelTypeMenu(
              valueName: Strings.urban,
              isValueVisible: NavigationMenu.isUrbanVisible,
              modelSelection: CityDensity.URBAN,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisUrbanVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isUrbanVisible = itemChanged;
              },
            ),
            RadiationModelTypeMenu(
              valueName: Strings.suburban,
              isValueVisible: NavigationMenu.isSuburbanVisible,
              modelSelection: CityDensity.SUBURBAN,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisSuburbanVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isSuburbanVisible = itemChanged;
              },
            ),
            RadiationModelTypeMenu(
              valueName: Strings.open,
              isValueVisible: NavigationMenu.isOpenVisible,
              modelSelection: CityDensity.OPEN,
              prefs: prefs!,
              prefsKey: SharedPreferencesHelper.kisOpenVisible,
              onMenuItemChanged: ({required bool itemChanged}) {
                NavigationMenu.isOpenVisible = itemChanged;
              },
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 10,
              ),
            ),

            //Signal strength
            Divider(
              height: 0,
              color: Colors.grey[300],
              thickness: 1.3,
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: ListTile(
                title: Text(
                  Strings.signal_strength,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            Ink(
              color: NavigationMenu.signalStrengthSelection == kMaximumSignalStrength
                  ? Colors.grey[300]
                  : Colors.white,
              child: ListTile(
                title: Text(Strings.maximum_signal,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.signalStrengthSelection == kMaximumSignalStrength
                            ? HexColor('3F51B5')
                            : Colors.black)),
                onTap: () {
                  if (NavigationMenu.signalStrengthSelection != kMaximumSignalStrength) {
                    NavigationMenu.signalStrengthSelection = kMaximumSignalStrength;
                    SharedPreferencesHelper.setInt(
                        key: SharedPreferencesHelper.ksignalStrengthSelection,
                        value: NavigationMenu.signalStrengthSelection,
                        prefs: prefs!);
                    Provider.of<SiteHelper>(context, listen: false)
                        .setSignalStrength(kMaximumSignalStrength);
                  }
                },
              ),
            ),
            Ink(
              color: NavigationMenu.signalStrengthSelection == kStrongSignalStrength
                  ? Colors.grey[300]
                  : Colors.white,
              child: ListTile(
                title: Text(Strings.strong_signal,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.signalStrengthSelection == kStrongSignalStrength
                            ? HexColor('3F51B5')
                            : Colors.black)),
                onTap: () {
                  if (NavigationMenu.signalStrengthSelection != kStrongSignalStrength) {
                    NavigationMenu.signalStrengthSelection = kStrongSignalStrength;
                    SharedPreferencesHelper.setInt(
                        key: SharedPreferencesHelper.ksignalStrengthSelection,
                        value: NavigationMenu.signalStrengthSelection,
                        prefs: prefs!);
                    Provider.of<SiteHelper>(context, listen: false)
                        .setSignalStrength(kStrongSignalStrength);
                  }
                },
              ),
            ),
            Ink(
              color: NavigationMenu.signalStrengthSelection == kGoodSignalStrength
                  ? Colors.grey[300]
                  : Colors.white,
              child: ListTile(
                title: Text(Strings.good_signal,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.signalStrengthSelection == kGoodSignalStrength
                            ? HexColor('3F51B5')
                            : Colors.black)),
                onTap: () {
                  if (NavigationMenu.signalStrengthSelection != kGoodSignalStrength) {
                    NavigationMenu.signalStrengthSelection = kGoodSignalStrength;
                    SharedPreferencesHelper.setInt(
                        key: SharedPreferencesHelper.ksignalStrengthSelection,
                        value: NavigationMenu.signalStrengthSelection,
                        prefs: prefs!);
                    Provider.of<SiteHelper>(context, listen: false)
                        .setSignalStrength(kGoodSignalStrength);
                  }
                },
              ),
            ),
            Ink(
              color: NavigationMenu.signalStrengthSelection == kWeakSignalStrength
                  ? Colors.grey[300]
                  : Colors.white,
              child: ListTile(
                title: Text(Strings.weak_signal,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.signalStrengthSelection == kWeakSignalStrength
                            ? HexColor('3F51B5')
                            : Colors.black)),
                onTap: () {
                  if (NavigationMenu.signalStrengthSelection != kWeakSignalStrength) {
                    NavigationMenu.signalStrengthSelection = kWeakSignalStrength;
                    SharedPreferencesHelper.setInt(
                        key: SharedPreferencesHelper.ksignalStrengthSelection,
                        value: NavigationMenu.signalStrengthSelection,
                        prefs: prefs!);
                    Provider.of<SiteHelper>(context, listen: false)
                        .setSignalStrength(kWeakSignalStrength);
                  }
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 10,
              ),
            ),

            //Transmitter Type
            Divider(
              height: 0,
              color: Colors.grey[300],
              thickness: 1.3,
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: ListTile(
                title: Text(
                  Strings.transmitter_type,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            Ink(
              color: NavigationMenu.isTelcoVisible ? Colors.grey[300] : Colors.white,
              child: ListTile(
                title: Text(Strings.transmitter_type_telecommunication,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.isTelcoVisible ? HexColor('3F51B5') : Colors.black)),
                onTap: () {
                  NavigationMenu.isTelcoVisible = !NavigationMenu.isTelcoVisible;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kisTelcoVisible,
                      value: NavigationMenu.isTelcoVisible,
                      prefs: prefs!);
                  if (NavigationMenu.isTelcoVisible) {
                    NavigationMenu.isTelstraVisible = true;
                    NavigationMenu.isOptusVisible = true;
                    NavigationMenu.isVodafoneVisible = true;
                    NavigationMenu.isDenseAirVisible = true;
                    NavigationMenu.isNBNVisible = true;
                    NavigationMenu.isOtherVisible = true;
                    SiteHelper().enableTelcoInUse(true);
                  } else {
                    NavigationMenu.isTelstraVisible = false;
                    NavigationMenu.isOptusVisible = false;
                    NavigationMenu.isVodafoneVisible = false;
                    NavigationMenu.isDenseAirVisible = false;
                    NavigationMenu.isNBNVisible = false;
                    NavigationMenu.isOtherVisible = false;
                    SiteHelper().disableTelcos();
                  }
                },
              ),
            ),
            Ink(
              color: NavigationMenu.isRadioVisible ? Colors.grey[300] : Colors.white,
              child: ListTile(
                title: Text(Strings.transmitter_type_radio,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.isRadioVisible ? HexColor('3F51B5') : Colors.black)),
                onTap: () {
                  NavigationMenu.isRadioVisible = !NavigationMenu.isRadioVisible;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kisRadioVisible,
                      value: NavigationMenu.isRadioVisible,
                      prefs: prefs!);
                  Provider.of<SiteHelper>(context, listen: false)
                      .toggleTelcoMarkers(Telco.Radio, NavigationMenu.isRadioVisible);
                },
              ),
            ),
            Ink(
              color: NavigationMenu.isTVVisible ? Colors.grey[300] : Colors.white,
              child: ListTile(
                title: Text(Strings.transmitter_type_tv,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.isTVVisible ? HexColor('3F51B5') : Colors.black)),
                onTap: () {
                  NavigationMenu.isTVVisible = !NavigationMenu.isTVVisible;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kisTVVisible,
                      value: NavigationMenu.isTVVisible,
                      prefs: prefs!);
                  Provider.of<SiteHelper>(context, listen: false)
                      .toggleTelcoMarkers(Telco.TV, NavigationMenu.isTVVisible);
                },
              ),
            ),
            Ink(
              color: NavigationMenu.isCivilVisible ? Colors.grey[300] : Colors.white,
              child: ListTile(
                title: Text(Strings.transmitter_type_civil,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.isCivilVisible ? HexColor('3F51B5') : Colors.black)),
                onTap: () {
                  NavigationMenu.isCivilVisible = !NavigationMenu.isCivilVisible;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kisCivilVisible,
                      value: NavigationMenu.isCivilVisible,
                      prefs: prefs!);
                  Provider.of<SiteHelper>(context, listen: false)
                      .toggleTelcoMarkers(Telco.Civil, NavigationMenu.isCivilVisible);
                },
              ),
            ),
            Ink(
              color: NavigationMenu.isPagerVisible ? Colors.grey[300] : Colors.white,
              child: ListTile(
                title: Text(Strings.transmitter_type_pager,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.isPagerVisible ? HexColor('3F51B5') : Colors.black)),
                onTap: () {
                  NavigationMenu.isPagerVisible = !NavigationMenu.isPagerVisible;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kisPagerVisible,
                      value: NavigationMenu.isPagerVisible,
                      prefs: prefs!);
                  Provider.of<SiteHelper>(context, listen: false)
                      .toggleTelcoMarkers(Telco.Pager, NavigationMenu.isPagerVisible);
                },
              ),
            ),
            Ink(
              color: NavigationMenu.isCBRSVisible ? Colors.grey[300] : Colors.white,
              child: ListTile(
                title: Text(Strings.transmitter_type_CBRS,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: NavigationMenu.isCBRSVisible ? HexColor('3F51B5') : Colors.black)),
                onTap: () {
                  NavigationMenu.isCBRSVisible = !NavigationMenu.isCBRSVisible;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kisCBRSVisible,
                      value: NavigationMenu.isCBRSVisible,
                      prefs: prefs!);
                  Provider.of<SiteHelper>(context, listen: false)
                      .toggleTelcoMarkers(Telco.CBRS, NavigationMenu.isCBRSVisible);
                },
              ),
            ),
            Ink(
              color: NavigationMenu.isAviationVisible ? Colors.grey[300] : Colors.white,
              child: ListTile(
                title: Text(Strings.transmitter_type_aviation,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color:
                            NavigationMenu.isAviationVisible ? HexColor('3F51B5') : Colors.black)),
                onTap: () {
                  NavigationMenu.isAviationVisible = !NavigationMenu.isAviationVisible;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kisAviationVisible,
                      value: NavigationMenu.isAviationVisible,
                      prefs: prefs!);
                  Provider.of<SiteHelper>(context, listen: false)
                      .toggleTelcoMarkers(Telco.Aviation, NavigationMenu.isAviationVisible);
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: SizedBox(
                height: 50,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void setTelecomOption() {
    if (NavigationMenu.isTelstraVisible == false &&
        NavigationMenu.isOptusVisible == false &&
        NavigationMenu.isVodafoneVisible == false &&
        NavigationMenu.isDenseAirVisible == false &&
        NavigationMenu.isNBNVisible == false &&
        NavigationMenu.isOtherVisible == false) {
      NavigationMenu.isTelcoVisible = false;
      SharedPreferencesHelper.saveBoolean(
          key: SharedPreferencesHelper.kisTelcoVisible,
          value: NavigationMenu.isTelcoVisible,
          prefs: prefs!);
    }
  }
}

class LicenceesMenuItem extends StatelessWidget {
  String valueName;
  Telco telco;
  bool isValueVisible;
  MenuItemChanged onMenuItemChanged;
  String prefsKey;
  SharedPreferences? prefs;

  LicenceesMenuItem(
      {required this.valueName,
      required this.telco,
      required this.isValueVisible,
      required this.prefsKey,
      required this.prefs,
      required this.onMenuItemChanged});

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: isValueVisible ? Colors.grey[300] : Colors.white,
      child: ListTile(
        title: Text(valueName,
            style: Theme.of(context)
                .textTheme
                .labelLarge!
                .copyWith(color: isValueVisible ? HexColor('3F51B5') : Colors.black)),
        onTap: () {
          isValueVisible = !isValueVisible;
          onMenuItemChanged(itemChanged: isValueVisible);
          SharedPreferencesHelper.saveBoolean(key: prefsKey, value: isValueVisible, prefs: prefs!);
          Provider.of<SiteHelper>(context, listen: false).toggleTelcoMarkers(telco, isValueVisible);

          if (isValueVisible) {
            //If any of telco is selected, Make Telecommunication option as selected in Transmitter type.
            NavigationMenu.isTelcoVisible = true;
            SharedPreferencesHelper.saveBoolean(
                key: SharedPreferencesHelper.kisTelcoVisible,
                value: NavigationMenu.isTelcoVisible,
                prefs: prefs!);
          }
        },
      ),
    );
  }
}

class NetworkTypeMenu extends StatelessWidget {
  String valueName;
  NetworkType networkType;
  bool isValueVisible;
  MenuItemChanged onMenuItemChanged;
  String prefsKey;
  SharedPreferences prefs;

  NetworkTypeMenu(
      {required this.valueName,
      required this.networkType,
      required this.isValueVisible,
      required this.prefsKey,
      required this.prefs,
      required this.onMenuItemChanged});

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: isValueVisible ? Colors.grey[300] : Colors.white,
      child: ListTile(
        title: Text(valueName,
            style: Theme.of(context)
                .textTheme
                .labelLarge!
                .copyWith(color: isValueVisible ? HexColor('3F51B5') : Colors.black)),
        onTap: () {
          isValueVisible = !isValueVisible;
          onMenuItemChanged(itemChanged: isValueVisible);
          SharedPreferencesHelper.saveBoolean(key: prefsKey, value: isValueVisible, prefs: prefs);
          Provider.of<SiteHelper>(context, listen: false)
              .toggleTelcoNetwork(networkType, isValueVisible);
        },
      ),
    );
  }
}

class MultiplexTypeMenu extends StatelessWidget {
  String valueName;
  //NetworkType networkType;
  bool isValueVisible;
  MenuItemChanged onMenuItemChanged;
  String prefsKey;
  SharedPreferences prefs;

  MultiplexTypeMenu(
      {required this.valueName,
      required this.isValueVisible,
      required this.prefsKey,
      required this.prefs,
      required this.onMenuItemChanged});

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: isValueVisible ? Colors.grey[300] : Colors.white,
      child: ListTile(
        title: Text(valueName,
            style: Theme.of(context)
                .textTheme
                .labelLarge!
                .copyWith(color: isValueVisible ? HexColor('3F51B5') : Colors.black)),
        onTap: () {
          isValueVisible = !isValueVisible;
          onMenuItemChanged(itemChanged: isValueVisible);
          SharedPreferencesHelper.saveBoolean(key: prefsKey, value: isValueVisible, prefs: prefs);
          SiteHelper().refreshSites();
          PolygonHelper().refreshPolygons(!isValueVisible);
        },
      ),
    );
  }
}

class FrequencyTypeMenu extends StatelessWidget {
  String valueName;
  FrequencyRanges frequencyRanges;
  bool isValueVisible;
  MenuItemChanged onMenuItemChanged;
  String prefsKey;
  SharedPreferences prefs;

  FrequencyTypeMenu(
      {required this.valueName,
      required this.frequencyRanges,
      required this.isValueVisible,
      required this.prefsKey,
      required this.prefs,
      required this.onMenuItemChanged});

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: isValueVisible ? Colors.grey[300] : Colors.white,
      child: ListTile(
        title: Text(valueName,
            style: Theme.of(context)
                .textTheme
                .labelLarge!
                .copyWith(color: isValueVisible ? HexColor('3F51B5') : Colors.black)),
        onTap: () {
          isValueVisible = !isValueVisible;
          onMenuItemChanged(itemChanged: isValueVisible);
          SharedPreferencesHelper.saveBoolean(key: prefsKey, value: isValueVisible, prefs: prefs);
          Provider.of<SiteHelper>(context, listen: false).toggleFrequencyRange(
              isValueVisible, FrequencyRangesHelper.getValue(frequencyRanges));
        },
      ),
    );
  }
}

class RadiationModelTypeMenu extends StatelessWidget {
  String valueName;
  CityDensity modelSelection;
  bool isValueVisible;
  MenuItemChanged onMenuItemChanged;
  String prefsKey;
  SharedPreferences prefs;

  RadiationModelTypeMenu(
      {required this.valueName,
      required this.modelSelection,
      required this.isValueVisible,
      required this.prefsKey,
      required this.prefs,
      required this.onMenuItemChanged});

  @override
  Widget build(BuildContext context) {
    return Ink(
      color: isValueVisible ? Colors.grey[300] : Colors.white,
      child: ListTile(
        title: Text(valueName,
            style: Theme.of(context)
                .textTheme
                .labelLarge!
                .copyWith(color: isValueVisible ? HexColor('3F51B5') : Colors.black)),
        onTap: () {
          isValueVisible = !isValueVisible;
          onMenuItemChanged(itemChanged: isValueVisible);
          SharedPreferencesHelper.saveBoolean(key: prefsKey, value: isValueVisible, prefs: prefs);
          Provider.of<SiteHelper>(context, listen: false)
              .toggleCityDensity(isValueVisible, modelSelection);
        },
      ),
    );
  }
}
