import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/ui/map_common.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:phonetowers/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// F5 (UI overhaul port): the Map Layers and Settings sheets, converging on the Android Phase 5
/// design. Map-surface options consolidate into Layers; the long tail of the old overflow moves
/// to Settings. Every control drives exactly the same statics, prefs keys and helper calls the
/// overflow submenus used, so behaviour and persistence are unchanged.

typedef void _ShowSnackBar({required String message, Duration duration, bool isDismissible});

Widget _sheetShell(BuildContext bc, String title, List<Widget> children) {
  return Container(
    decoration: BoxDecoration(
      color: Theme.of(bc).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    ),
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
    constraints: BoxConstraints(maxHeight: MediaQuery.of(bc).size.height * 0.8),
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
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(bc).colorScheme.onSurface)),
        Flexible(
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ),
      ],
    ),
  );
}

Widget _sectionTitle(BuildContext bc, String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.5,
              color: Theme.of(bc).colorScheme.onSurfaceVariant)),
    );

Widget _row(BuildContext bc, String label, String suffix, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style:
                      TextStyle(fontSize: 15, color: Theme.of(bc).colorScheme.onSurface))),
          Text(suffix,
              style:
                  TextStyle(fontSize: 14, color: Theme.of(bc).colorScheme.onSurfaceVariant)),
        ]),
      ),
    );

class LayersSheet {
  static Future<void> show(BuildContext context,
      {required SharedPreferences prefs, required _ShowSnackBar showSnackBar}) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (bc) => StatefulBuilder(
        builder: (bc, setSheetState) {
          void refresh() => setSheetState(() {});

          final int precisionIndex =
              PolygonHelper.polygonBearingIncrement == PolygonHelper.kPolygonPrecisionLow
                  ? 0
                  : PolygonHelper.polygonBearingIncrement ==
                          PolygonHelper.kPolygonPrecisionHigh
                      ? 2
                      : 1;

          return _sheetShell(bc, 'Map layers', [
            _sectionTitle(bc, 'Map mode'),
            Wrap(spacing: 6, children: [
              for (final entry in const [
                ['Terrain', 1],
                ['Hybrid', 2],
                ['Satellite', 3],
                ['Normal', 4],
              ])
                ChoiceChip(
                  label: Text(entry[0] as String),
                  selected: MapHelper().mapMode == entry[1] as int,
                  onSelected: (v) {
                    if (v) {
                      Provider.of<MapHelper>(bc, listen: false)
                          .setMapMode(entry[1] as int, prefs);
                      PolygonHelper().refreshPolygons(true);
                    }
                    refresh();
                  },
                ),
            ]),
            _sectionTitle(bc, 'Overlays'),
            Wrap(spacing: 6, children: [
              FilterChip(
                label: Text('Terrain-aware coverage'),
                selected: PolygonHelper.calculateTerrain,
                onSelected: (v) {
                  PolygonHelper.calculateTerrain = v;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kcalculateTerrain,
                      value: v,
                      prefs: prefs);
                  showSnackBar(
                      message: v
                          ? 'Using terrain data when calculating propagation models! This is more accurate but slower.'
                          : 'Ignoring terrain when calculating propagation models.');
                  PolygonHelper().switchTerrainAwareness();
                  refresh();
                },
              ),
              FilterChip(
                label: Text('Polygon borders'),
                selected: PolygonHelper.showPolygonBorders,
                onSelected: (v) {
                  PolygonHelper.showPolygonBorders = v;
                  showSnackBar(
                      message: '${v ? 'Showing' : 'Hiding'} polygon radiation borders!');
                  PolygonHelper().refreshPolygons(true);
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kshowPolygonBorders,
                      value: v,
                      prefs: prefs);
                  refresh();
                },
              ),
              FilterChip(
                label: Text('Coverage on tap'),
                selected: PolygonHelper.drawPolygonsOnClick,
                onSelected: (v) {
                  PolygonHelper.drawPolygonsOnClick = v;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kdrawPolygonsOnClick,
                      value: v,
                      prefs: prefs);
                  if (!v) PolygonHelper().clearSitePatterns(false);
                  refresh();
                },
              ),
              FilterChip(
                label: Text('Multi-tower coverage'),
                selected: PolygonHelper.multiTowerCoverage,
                onSelected: (v) {
                  PolygonHelper.multiTowerCoverage = v;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.kmultiTowerCoverage,
                      value: v,
                      prefs: prefs);
                  if (!v) PolygonHelper().clearSitePatterns(false);
                  showSnackBar(
                      message: v
                          ? 'Multi-Tower Coverage on: tapping towers adds their coverage to the map.'
                          : 'Multi-Tower Coverage off: tapping a tower replaces the previous coverage.');
                  refresh();
                },
              ),
              FilterChip(
                label: Text('Lock map'),
                selected: MapBodyState.lockMap,
                onSelected: (v) {
                  MapBodyState.lockMap = v;
                  showSnackBar(
                      message: v
                          ? 'Map locked — all camera movement (gestures, my location, Follow GPS, search) disabled for screenshots.'
                          : 'Map unlocked — camera movement enabled again.');
                  MapBodyState.currentInstance?.setState(() {});
                  refresh();
                },
              ),
            ]),
            _sectionTitle(bc, 'Polygon precision'),
            Wrap(spacing: 6, children: [
              for (final entry in const [
                ['Low', 0],
                ['Medium', 1],
                ['High', 2],
              ])
                ChoiceChip(
                  label: Text(entry[0] as String),
                  selected: precisionIndex == entry[1] as int,
                  onSelected: (v) {
                    if (!v) return;
                    final int index = entry[1] as int;
                    PolygonHelper.polygonBearingIncrement = index == 0
                        ? PolygonHelper.kPolygonPrecisionLow
                        : index == 2
                            ? PolygonHelper.kPolygonPrecisionHigh
                            : PolygonHelper.kPolygonPrecisionMedium;
                    SharedPreferencesHelper.setInt(
                        key: SharedPreferencesHelper.kpolygonPrecision,
                        value: index,
                        prefs: prefs);
                    showSnackBar(
                        message:
                            'Polygon precision set to ${entry[0]}. Newly drawn coverage will use this.');
                    refresh();
                  },
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

class SettingsSheet {
  static Future<void> show(BuildContext context,
      {required SharedPreferences prefs,
      required _ShowSnackBar showSnackBar,
      required VoidCallback onCameraMoveFromLastLocation,
      required VoidCallback takeScreenshot}) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (bc) => StatefulBuilder(
        builder: (bc, setSheetState) {
          void refresh() => setSheetState(() {});

          return _sheetShell(bc, 'Settings', [
            if (!kIsWeb) ...[
              _sectionTitle(bc, 'Map rotation while driving'),
              Wrap(spacing: 6, children: [
                for (final entry in [
                  ['Travel direction', RotatingMapMode.travelDirection],
                  ['Phone orientation', RotatingMapMode.phoneOrientation],
                  ['Off', RotatingMapMode.disableRotation],
                ])
                  ChoiceChip(
                    label: Text(entry[0] as String),
                    selected: MapBodyState.rotatingMapMode == entry[1] as RotatingMapMode,
                    onSelected: (v) async {
                      if (v) {
                        await MapBodyState.setRotatingMapMode(entry[1] as RotatingMapMode);
                      }
                      refresh();
                    },
                  ),
              ]),
            ],
            _sectionTitle(bc, 'Data'),
            Wrap(spacing: 6, children: [
              FilterChip(
                label: Text('Frequency refarming'),
                selected: DeviceDetails.refarmEnabled,
                onSelected: (v) {
                  DeviceDetails.refarmEnabled = v;
                  SharedPreferencesHelper.saveBoolean(
                      key: SharedPreferencesHelper.krefarmEnabled, value: v, prefs: prefs);
                  // Re-classify licences: reload sites + polygons with the new setting.
                  SiteHelper()
                      .clearMap(onCameraMoveFromLastLocation: onCameraMoveFromLastLocation);
                  showSnackBar(
                      message: v
                          ? 'Refarming on: legacy 3G licences in 4G/5G bands shown at their current reuse (4G LTE).'
                          : 'Refarming off: showing the literal licence type (e.g. 3G UMTS).');
                  refresh();
                },
              ),
            ]),
            _sectionTitle(bc, 'Advanced'),
            Wrap(spacing: 6, children: [
              FilterChip(
                label: Text('Developer Mode'),
                selected: MapHelper().developerMode,
                onSelected: (v) {
                  MapHelper().developerMode = v;
                  MapHelper().toggleDeveloperMode();
                  PolygonHelper().refreshPolygons(false);
                  refresh();
                },
              ),
            ]),
            _sectionTitle(bc, 'Help'),
            _row(bc, 'User Guide', '›', () => Utils.launchURL(kUserGuideUrl)),
            _row(bc, 'Report a problem', '›', () {
              Navigator.of(bc).pop();
              takeScreenshot();
            }),
            _row(bc, 'ausphonetowers.com.au', '↗',
                () => Utils.launchURL('https://ausphonetowers.com.au/')),
            if (kIsWeb || !Platform.isAndroid)
              _row(bc, Strings.iosAppStore, '↗',
                  () => Utils.launchURL(
                      'https://apps.apple.com/us/app/aus-phone-towers-3g-4g-5g/id1488594332')),
            if (kIsWeb || (!kIsWeb && Platform.isAndroid))
              _row(bc, Strings.androidPlayStore, '↗',
                  () => Utils.launchURL(
                      'https://play.google.com/store/apps/details?id=au.com.bitbot.phonetowers.flutter')),
            _row(bc, 'Source code', '↗',
                () => Utils.launchURL('https://github.com/bradrushworth/aus_phone_towers_iphone')),
            if (!kIsWeb)
              _row(bc, 'Rate the app', '›', () async {
                final InAppReview inAppReview = InAppReview.instance;
                if (await inAppReview.isAvailable()) {
                  inAppReview.requestReview();
                }
                Utils.launchURL(Platform.isAndroid
                    ? 'https://play.google.com/store/apps/details?id=au.com.bitbot.phonetowers.flutter'
                    : 'https://apps.apple.com/us/app/aus-phone-towers-3g-4g-5g/id1488594332');
              }),
          ]);
        },
      ),
    );
  }
}
