import 'package:flutter/material.dart';
import 'package:phonetowers/helpers/frequency_range_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/ui/widgets/navigation_menu.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F4 (UI overhaul port): the filter chip sheet, converging on the Android Phase 4 FilterSheet.
/// Replaces the 200 px drawer of tint-selected rows with a full-width bottom sheet of
/// FilterChips — one ChipGroup per category, single-selection Signal Strength, Multiplex under an
/// Advanced expander, and a live "N sites shown" count. Every chip drives exactly the same
/// [NavigationMenu] statics, SharedPreferences keys and [SiteHelper]/[PolygonHelper] mutators the
/// drawer rows used, so filter behaviour and persistence are unchanged.
class FilterSheet {
  /// Number of categories currently restricting results — the toolbar badge count.
  static int activeFilterCount() {
    int count = 0;
    if (!(NavigationMenu.isTelstraVisible &&
        NavigationMenu.isOptusVisible &&
        NavigationMenu.isVodafoneVisible &&
        NavigationMenu.isNBNVisible &&
        NavigationMenu.isOtherVisible)) count++;
    if (!(NavigationMenu.is2GVisible &&
        NavigationMenu.is3GVisible &&
        NavigationMenu.is4GVisible &&
        NavigationMenu.is5GVisible)) count++;
    if (!(NavigationMenu.isLess700Visible &&
        NavigationMenu.isBet700_100Visible &&
        NavigationMenu.isBet1_2Visible &&
        NavigationMenu.isBet2_3Visible &&
        NavigationMenu.isGreater3Visible)) count++;
    if (!(NavigationMenu.isMetroVisible &&
        NavigationMenu.isUrbanVisible &&
        NavigationMenu.isSuburbanVisible &&
        NavigationMenu.isOpenVisible)) count++;
    if (!(NavigationMenu.isNOTLTEVisible &&
        NavigationMenu.isFDLTEVisible &&
        NavigationMenu.isTDLTEVisible)) count++;
    if (!(NavigationMenu.isTelcoVisible)) count++;
    return count;
  }

  static int visibleSiteCount() {
    final Set<String> seen = {};
    int count = 0;
    for (final overlay in SiteHelper.globalListMapOverlay) {
      final site = overlay.site;
      if (site != null && seen.add('${site.siteId}') && site.shouldBeVisible()) {
        count++;
      }
    }
    return count;
  }

  static Future<void> show(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    bool advancedOpen = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (bc) => StatefulBuilder(
        builder: (bc, setSheetState) {
          void refresh() => setSheetState(() {});

          Widget title(String text, {Widget? trailing}) => Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Row(children: [
                  Expanded(
                      child: Text(text.toUpperCase(),
                          style: TextStyle(
                              fontSize: 12,
                              letterSpacing: 0.5,
                              color: Theme.of(bc).colorScheme.onSurfaceVariant))),
                  if (trailing != null) trailing,
                ]),
              );

          Widget chip(String label, bool selected, void Function(bool) onChanged) => FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (v) {
                  onChanged(v);
                  refresh();
                },
              );

          void savePref(String key, bool value) =>
              SharedPreferencesHelper.saveBoolean(key: key, value: value, prefs: prefs);

          void toggleCarrier(Telco telco, String prefsKey, bool newValue,
              void Function(bool) setStatic) {
            setStatic(newValue);
            savePref(prefsKey, newValue);
            SiteHelper().toggleTelcoMarkers(telco, newValue);
            if (newValue) {
              NavigationMenu.isTelcoVisible = true;
              savePref(SharedPreferencesHelper.kisTelcoVisible, true);
            } else if (!NavigationMenu.isTelstraVisible &&
                !NavigationMenu.isOptusVisible &&
                !NavigationMenu.isVodafoneVisible &&
                !NavigationMenu.isDenseAirVisible &&
                !NavigationMenu.isNBNVisible &&
                !NavigationMenu.isOtherVisible) {
              NavigationMenu.isTelcoVisible = false;
              savePref(SharedPreferencesHelper.kisTelcoVisible, false);
            }
          }

          void toggleMultiplex(String prefsKey, bool newValue, void Function(bool) setStatic) {
            setStatic(newValue);
            savePref(prefsKey, newValue);
            SiteHelper().refreshSites();
            PolygonHelper().refreshPolygons(!newValue);
          }

          List<Widget> content = [
            // Carrier
            title('Carrier'),
            Wrap(spacing: 6, runSpacing: 0, children: [
              chip('Telstra', NavigationMenu.isTelstraVisible,
                  (v) => toggleCarrier(Telco.Telstra, SharedPreferencesHelper.kisTelstraVisible, v,
                      (x) => NavigationMenu.isTelstraVisible = x)),
              chip('Optus', NavigationMenu.isOptusVisible,
                  (v) => toggleCarrier(Telco.Optus, SharedPreferencesHelper.kisOptusVisible, v,
                      (x) => NavigationMenu.isOptusVisible = x)),
              chip('Vodafone', NavigationMenu.isVodafoneVisible,
                  (v) => toggleCarrier(Telco.Vodafone, SharedPreferencesHelper.kisVodafoneVisible,
                      v, (x) => NavigationMenu.isVodafoneVisible = x)),
              chip('NBN', NavigationMenu.isNBNVisible,
                  (v) => toggleCarrier(Telco.NBN, SharedPreferencesHelper.kisNBNVisible, v,
                      (x) => NavigationMenu.isNBNVisible = x)),
              chip('Other', NavigationMenu.isOtherVisible,
                  (v) => toggleCarrier(Telco.Other, SharedPreferencesHelper.kisOtherVisible, v,
                      (x) => NavigationMenu.isOtherVisible = x)),
            ]),
            // Generation
            title('Generation'),
            Wrap(spacing: 6, runSpacing: 0, children: [
              chip('2G GSM', NavigationMenu.is2GVisible, (v) {
                NavigationMenu.is2GVisible = v;
                savePref(SharedPreferencesHelper.kis2GVisible, v);
                SiteHelper().toggleTelcoNetwork(NetworkType.GSM, v);
              }),
              chip('3G UMTS', NavigationMenu.is3GVisible, (v) {
                NavigationMenu.is3GVisible = v;
                savePref(SharedPreferencesHelper.kis3GVisible, v);
                SiteHelper().toggleTelcoNetwork(NetworkType.UMTS, v);
              }),
              chip('4G LTE', NavigationMenu.is4GVisible, (v) {
                NavigationMenu.is4GVisible = v;
                savePref(SharedPreferencesHelper.kis4GVisible, v);
                SiteHelper().toggleTelcoNetwork(NetworkType.LTE, v);
              }),
              chip('5G NR', NavigationMenu.is5GVisible, (v) {
                NavigationMenu.is5GVisible = v;
                savePref(SharedPreferencesHelper.kis5GVisible, v);
                SiteHelper().toggleTelcoNetwork(NetworkType.NR, v);
              }),
            ]),
            // Frequency
            title('Frequency'),
            Wrap(spacing: 6, runSpacing: 0, children: [
              chip('< 700 MHz', NavigationMenu.isLess700Visible, (v) {
                NavigationMenu.isLess700Visible = v;
                savePref(SharedPreferencesHelper.kisLess700Visible, v);
                SiteHelper().toggleFrequencyRange(
                    v, FrequencyRangesHelper.getValue(FrequencyRanges.VERY_LOW));
              }),
              chip('700 – 1000 MHz', NavigationMenu.isBet700_100Visible, (v) {
                NavigationMenu.isBet700_100Visible = v;
                savePref(SharedPreferencesHelper.kisBet700_100Visible, v);
                SiteHelper()
                    .toggleFrequencyRange(v, FrequencyRangesHelper.getValue(FrequencyRanges.LOW));
              }),
              chip('1.0 – 2.4 GHz', NavigationMenu.isBet1_2Visible, (v) {
                NavigationMenu.isBet1_2Visible = v;
                savePref(SharedPreferencesHelper.kisBet1_2Visible, v);
                SiteHelper().toggleFrequencyRange(
                    v, FrequencyRangesHelper.getValue(FrequencyRanges.MEDIUM));
              }),
              chip('2.4 – 3.8 GHz', NavigationMenu.isBet2_3Visible, (v) {
                NavigationMenu.isBet2_3Visible = v;
                savePref(SharedPreferencesHelper.kisBet2_3Visible, v);
                SiteHelper()
                    .toggleFrequencyRange(v, FrequencyRangesHelper.getValue(FrequencyRanges.HIGH));
              }),
              chip('>= 3.8 GHz', NavigationMenu.isGreater3Visible, (v) {
                NavigationMenu.isGreater3Visible = v;
                savePref(SharedPreferencesHelper.kisGreater3Visible, v);
                SiteHelper().toggleFrequencyRange(
                    v, FrequencyRangesHelper.getValue(FrequencyRanges.VERY_HIGH));
              }),
            ]),
            // City density
            title('City density'),
            Wrap(spacing: 6, runSpacing: 0, children: [
              chip('Metropolitan', NavigationMenu.isMetroVisible, (v) {
                NavigationMenu.isMetroVisible = v;
                savePref(SharedPreferencesHelper.kisMetroVisible, v);
                SiteHelper().toggleCityDensity(v, CityDensity.METRO);
              }),
              chip('Urban', NavigationMenu.isUrbanVisible, (v) {
                NavigationMenu.isUrbanVisible = v;
                savePref(SharedPreferencesHelper.kisUrbanVisible, v);
                SiteHelper().toggleCityDensity(v, CityDensity.URBAN);
              }),
              chip('Suburban', NavigationMenu.isSuburbanVisible, (v) {
                NavigationMenu.isSuburbanVisible = v;
                savePref(SharedPreferencesHelper.kisSuburbanVisible, v);
                SiteHelper().toggleCityDensity(v, CityDensity.SUBURBAN);
              }),
              chip('Open', NavigationMenu.isOpenVisible, (v) {
                NavigationMenu.isOpenVisible = v;
                savePref(SharedPreferencesHelper.kisOpenVisible, v);
                SiteHelper().toggleCityDensity(v, CityDensity.OPEN);
              }),
            ]),
            // Signal strength — single-select display setting, not a hide filter
            title('Signal strength'),
            Wrap(spacing: 6, runSpacing: 0, children: [
              for (final entry in const [
                ['Maximum', kMaximumSignalStrength],
                ['Strong', kStrongSignalStrength],
                ['Good', kGoodSignalStrength],
                ['Weak', kWeakSignalStrength],
              ])
                ChoiceChip(
                  label: Text(entry[0] as String),
                  selected: NavigationMenu.signalStrengthSelection == entry[1] as int,
                  onSelected: (v) {
                    if (v && NavigationMenu.signalStrengthSelection != entry[1] as int) {
                      NavigationMenu.signalStrengthSelection = entry[1] as int;
                      SharedPreferencesHelper.setInt(
                          key: SharedPreferencesHelper.ksignalStrengthSelection,
                          value: NavigationMenu.signalStrengthSelection,
                          prefs: prefs);
                      SiteHelper().setSignalStrength(entry[1] as int);
                    }
                    refresh();
                  },
                ),
            ]),
            // Transmitter type
            title('Transmitter type'),
            Wrap(spacing: 6, runSpacing: 0, children: [
              chip('Telco', NavigationMenu.isTelcoVisible, (v) {
                NavigationMenu.isTelcoVisible = v;
                savePref(SharedPreferencesHelper.kisTelcoVisible, v);
                if (v) {
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
              }),
              chip('Radio', NavigationMenu.isRadioVisible, (v) {
                NavigationMenu.isRadioVisible = v;
                savePref(SharedPreferencesHelper.kisRadioVisible, v);
                SiteHelper().toggleTelcoMarkers(Telco.Radio, v);
              }),
              chip('TV', NavigationMenu.isTVVisible, (v) {
                NavigationMenu.isTVVisible = v;
                savePref(SharedPreferencesHelper.kisTVVisible, v);
                SiteHelper().toggleTelcoMarkers(Telco.TV, v);
              }),
              chip('Civil', NavigationMenu.isCivilVisible, (v) {
                NavigationMenu.isCivilVisible = v;
                savePref(SharedPreferencesHelper.kisCivilVisible, v);
                SiteHelper().toggleTelcoMarkers(Telco.Civil, v);
              }),
              chip('Pager', NavigationMenu.isPagerVisible, (v) {
                NavigationMenu.isPagerVisible = v;
                savePref(SharedPreferencesHelper.kisPagerVisible, v);
                SiteHelper().toggleTelcoMarkers(Telco.Pager, v);
              }),
              chip('CBRS', NavigationMenu.isCBRSVisible, (v) {
                NavigationMenu.isCBRSVisible = v;
                savePref(SharedPreferencesHelper.kisCBRSVisible, v);
                SiteHelper().toggleTelcoMarkers(Telco.CBRS, v);
              }),
              chip('Aviation', NavigationMenu.isAviationVisible, (v) {
                NavigationMenu.isAviationVisible = v;
                savePref(SharedPreferencesHelper.kisAviationVisible, v);
                SiteHelper().toggleTelcoMarkers(Telco.Aviation, v);
              }),
            ]),
            // Advanced: multiplex
            InkWell(
              onTap: () => setSheetState(() => advancedOpen = !advancedOpen),
              child: title('Advanced  ${advancedOpen ? '▴' : '▾'}'),
            ),
            if (advancedOpen) ...[
              title('Multiplex'),
              Wrap(spacing: 6, runSpacing: 0, children: [
                chip('NOT LTE', NavigationMenu.isNOTLTEVisible, (v) {
                  NavigationMenu.isNOTLTEVisible = v;
                  PolygonHelper.displayNotLteMultiplex = v;
                  toggleMultiplex(SharedPreferencesHelper.kisNOTLTEVisible, v,
                      (x) => NavigationMenu.isNOTLTEVisible = x);
                }),
                chip('FD–LTE', NavigationMenu.isFDLTEVisible, (v) {
                  NavigationMenu.isFDLTEVisible = v;
                  PolygonHelper.displayFdMultiplex = v;
                  toggleMultiplex(SharedPreferencesHelper.kisFDLTEVisible, v,
                      (x) => NavigationMenu.isFDLTEVisible = x);
                }),
                chip('TD–LTE', NavigationMenu.isTDLTEVisible, (v) {
                  NavigationMenu.isTDLTEVisible = v;
                  PolygonHelper.displayTdMultiplex = v;
                  toggleMultiplex(SharedPreferencesHelper.kisTDLTEVisible, v,
                      (x) => NavigationMenu.isTDLTEVisible = x);
                }),
              ]),
            ],
          ];

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(bc).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            constraints:
                BoxConstraints(maxHeight: MediaQuery.of(bc).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(bc).colorScheme.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Text('Filters',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(bc).colorScheme.onSurface)),
                Text('${visibleSiteCount()} sites shown',
                    style: TextStyle(
                        fontSize: 13, color: Theme.of(bc).colorScheme.onSurfaceVariant)),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: content),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
