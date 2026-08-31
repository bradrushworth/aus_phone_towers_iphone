import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/export_helper.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/ui/widgets/layers_settings_sheets.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/ui/widgets/support_prompt_screen.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:phonetowers/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phonetowers/model/device_detail.dart';

typedef void ShowSnackBar({
  required String message,
  Duration duration,
  bool isDismissible,
});

/// Top-level overflow items, in the same order as the Android app's `popup_menu.xml`:
/// Refresh Data, Export Data, Settings, User Guide, Report a Problem, Support the App.
///
/// Android's overflow deliberately stays slim — the funnel, Follow GPS, Layers and Search live on
/// the toolbar, and everything that is a *setting* lives in the Layers/Settings sheets. This menu
/// had drifted from that: it still carried Remove Ads and Donate submenus of its own, so the app
/// sold the same five products from three different places (here, the Settings sheet's
/// neighbourhood, and the Support the App screen). Those submenus are gone; `SupportPromptScreen`
/// is now the single place anything is sold, reached from the Support the App row here and from
/// one row in the Settings sheet — matching Android, where `donateSupportPrompt` sits in the
/// overflow and the product lists are backing items owned by the Settings sheet.
///
/// Two deliberate differences from `popup_menu.xml` remain:
///  * `leaderboardMenu` has no entry here because the Flutter app has no leaderboard feature at
///    all — a missing feature, not a missing menu item.
///  * `closeApp` was dropped rather than ported. Android has no such item, and on iOS/Web the
///    platform does not permit an app to exit programmatically, so it existed only to display a
///    snackbar explaining that it does nothing.
///
/// Using an enum (rather than an index into a list) guarantees the label shown always maps to the
/// correct behaviour — fixing the old "labels don't match the action" bug.
enum OptionMenuItem {
  refreshData,
  exportData,
  settings,
  userGuide,
  reportProblem,
  supportTheApp,
}

class OptionsMenu extends StatefulWidget {
  final ShowSnackBar showSnackBar;
  final void Function() onCameraMoveFromLastLocation;
  final void Function() takeScreenshot;

  OptionsMenu(
      {required this.showSnackBar,
      required this.onCameraMoveFromLastLocation,
      required this.takeScreenshot});

  @override
  _OptionsMenuState createState() => _OptionsMenuState();
}

class _OptionsMenuState extends State<OptionsMenu> {
  late Logger logger;
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    logger = Logger();
    _loadSharedPreference();
  }

  void _loadSharedPreference() async {
    prefs = await SharedPreferences.getInstance();
    // Restore persisted preference-driven toggles.
    DeviceDetails.refarmEnabled =
        prefs.getBool(SharedPreferencesHelper.krefarmEnabled) ?? true;
    final int precisionIndex = SharedPreferencesHelper.getInt(
        key: SharedPreferencesHelper.kpolygonPrecision, prefs: prefs);
    PolygonHelper.polygonBearingIncrement = _precisionIncrement(precisionIndex);
    PolygonHelper.multiTowerCoverage =
        prefs.getBool(SharedPreferencesHelper.kmultiTowerCoverage) ?? false;
  }

  static double _precisionIncrement(int index) {
    switch (index) {
      case 0:
        return PolygonHelper.kPolygonPrecisionLow;
      case 2:
        return PolygonHelper.kPolygonPrecisionHigh;
      default:
        return PolygonHelper.kPolygonPrecisionMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<OptionMenuItem>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (BuildContext context) {
        return OptionMenuItem.values.map<PopupMenuItem<OptionMenuItem>>((OptionMenuItem item) {
          return PopupMenuItem<OptionMenuItem>(
            value: item,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(_topLevelTitle(item)),
                if (_hasSubmenu(item)) ...[
                  Icon(Icons.play_arrow, color: Colors.black54, size: 12)
                ]
              ],
            ),
          );
        }).toList();
      },
      onSelected: (OptionMenuItem item) async {
        switch (item) {
          case OptionMenuItem.refreshData:
            {
              SiteHelper().clearMap(
                  onCameraMoveFromLastLocation: widget.onCameraMoveFromLastLocation);
              break;
            }
          case OptionMenuItem.exportData:
            {
              showExportMenu();
              break;
            }
          case OptionMenuItem.settings:
            {
              SettingsSheet.show(context,
                  prefs: prefs,
                  showSnackBar: widget.showSnackBar,
                  onCameraMoveFromLastLocation: widget.onCameraMoveFromLastLocation,
                  takeScreenshot: widget.takeScreenshot);
              break;
            }
          case OptionMenuItem.userGuide:
            {
              Utils.launchURL(kUserGuideUrl);
              break;
            }
          case OptionMenuItem.reportProblem:
            {
              // Android keeps this in the overflow rather than the Settings sheet on purpose: the
              // report screenshots the window as it stands, and fired from inside a sheet it
              // captured the sheet instead of the map (Java app, GitHub issue #48).
              widget.takeScreenshot();
              break;
            }
          case OptionMenuItem.supportTheApp:
            {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SupportPromptScreen()));
              break;
            }
        }
      },
    );
  }

  String _topLevelTitle(OptionMenuItem item) {
    switch (item) {
      case OptionMenuItem.refreshData:
        return Strings.reload_everything;
      case OptionMenuItem.exportData:
        return Strings.export_data;
      case OptionMenuItem.settings:
        return Strings.settings;
      case OptionMenuItem.userGuide:
        return Strings.userGuide;
      case OptionMenuItem.reportProblem:
        return Strings.reportProblem;
      case OptionMenuItem.supportTheApp:
        return Strings.donateSupportPrompt;
    }
  }

  bool _hasSubmenu(OptionMenuItem item) =>
      item == OptionMenuItem.exportData || item == OptionMenuItem.settings;

  // ----- Export Data (mirrors Android: Export Towers GeoJSON/CSV + Export Coverage GeoJSON) -----
  Future showExportMenu() async {
    final List<SingleRowItem> items = <SingleRowItem>[
      SingleRowItem(isTitle: true, title: Strings.export_data, isEnabled: false),
      SingleRowItem(title: Strings.export_towers_geojson, isEnabled: true),
      SingleRowItem(title: Strings.export_towers_csv, isEnabled: true),
      SingleRowItem(title: Strings.export_coverage_geojson, isEnabled: true),
    ];
    final SingleRowItem? chosen = await showSingleRowOptionMenu(items, kExportMenu);
    if (chosen == null) return;
    if (chosen.title == Strings.export_towers_geojson ||
        chosen.title == Strings.export_towers_csv) {
      widget.showSnackBar(message: 'Exporting towers...');
      ExportHelper.exportTowers().then((List<String> paths) {
        _reportExport(paths, 'towers');
      });
    } else if (chosen.title == Strings.export_coverage_geojson) {
      widget.showSnackBar(message: 'Exporting coverage polygons...');
      ExportHelper.exportSignalPolygons().then((List<String> paths) {
        _reportExport(paths, 'coverage polygons');
      });
    }
  }

  void _reportExport(List<String> paths, String what) {
    if (paths.isEmpty) {
      widget.showSnackBar(
          message:
              'There are no $what on the map to export. Load some towers${what == "coverage polygons" ? " and tap one to draw its coverage" : ""} first...');
    } else {
      final StringBuffer message = StringBuffer();
      message.write('Exported ${paths.length} files to the app documents folder:\n');
      for (final String path in paths) {
        message.write('$path\n');
      }
      widget.showSnackBar(message: message.toString(), duration: const Duration(seconds: 10));
    }
  }

  Future<SingleRowItem?> showSingleRowOptionMenu(
      List<SingleRowItem> listSingleRowItem, int menuType) async {
    SingleRowItem? singleRowItem = await showMenu<SingleRowItem>(
      context: context,
      position: RelativeRect.fromLTRB(0.0, 45.0, -1.0, 0.0),
      items: listSingleRowItem
          .map<PopupMenuItem<SingleRowItem>>((SingleRowItem singleRowItem) {
        return PopupMenuItem<SingleRowItem>(
          enabled: singleRowItem.isEnabled,
          value: singleRowItem,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              if (singleRowItem.isTitle) ...[
                Text(
                  singleRowItem.title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ] else ...[
                if (singleRowItem.prefix != null) ...[singleRowItem.prefix!],
                if (singleRowItem.isChecked) ...[
                  Icon(Icons.check_box, color: Colors.black54, size: 14),
                  SizedBox(width: 8),
                ],
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        left: singleRowItem.prefix != null ? 12 : 0),
                    child: Text(
                      singleRowItem.title,
                      maxLines: 2,
                    ),
                  ),
                )
              ]
            ],
          ),
        );
      }).toList(),
    );

    if (singleRowItem == null) return null;
    return singleRowItem;
  }

  Future showRadioOptionMenu() async {
    RadioItem? radioItem = await showMenu<RadioItem>(
      context: context,
      position: RelativeRect.fromLTRB(0.0, 45.0, -1.0, 0.0),
      items: listRadioItem.map<PopupMenuItem<RadioItem>>((RadioItem radioItem) {
        return PopupMenuItem<RadioItem>(
          enabled: !radioItem.isTitle,
          value: radioItem,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              if (radioItem.isTitle) ...[
                Text(
                  radioItem.title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ] else ...[
                Expanded(
                    child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 5),
                  title: Text(radioItem.title),
                  trailing: Radio(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: listRadioItem.indexOf(radioItem),
                    groupValue: MapHelper().mapMode,
                    onChanged: (value) {},
                  ),
                ))
              ]
            ],
          ),
        );
      }).toList(),
    );

    if (radioItem == null) return;
    int selectedOptionItem = listRadioItem.indexOf(radioItem);
    if (selectedOptionItem != -1) {
      MapHelper().setMapMode(selectedOptionItem, prefs);
      PolygonHelper().refreshPolygons(true);
    }
  }
}

//********************** All options ***************************//

//********************** Clear map ***************************//
class SingleRowItem {
  SingleRowItem(
      {this.isTitle = false,
      required this.title,
      this.prefix,
      this.isEnabled = true,
      this.isChecked = false});

  bool isTitle;
  String title;
  final Widget? prefix;
  bool isEnabled;
  bool isChecked;
}

// List<SingleRowItem> listClearMapItem = <SingleRowItem>[
//   SingleRowItem(isTitle: true, title: Strings.clear_map, isEnabled: false),
//   SingleRowItem(title: Strings.clear_polygons, prefix: Icon(Icons.clear)),
//   SingleRowItem(
//       title: Strings.reload_everything, prefix: Icon(Icons.delete_forever))
// ];

// listRemoveAdsItem / listDonateItem lived here. They were top-level globals, so their titles
// were built once at first access — before the store had answered — and then patched in place
// before each show. SupportPromptScreen builds its labels during build() under
// Consumer<PurchaseHelper> instead, so it cannot show a price from before the store replied.

//********************** Radio options ***************************//
class RadioItem {
  RadioItem({this.isTitle = false, required this.title});

  bool isTitle;
  String title;
}

List<RadioItem> listRadioItem = <RadioItem>[
  RadioItem(isTitle: true, title: Strings.map_mode),
  RadioItem(title: Strings.map_mode_terrain),
  RadioItem(title: Strings.map_mode_hybrid),
  RadioItem(title: Strings.map_mode_satellite),
  RadioItem(title: Strings.map_mode_normal),
];
