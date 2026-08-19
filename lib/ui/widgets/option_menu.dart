import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/export_helper.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/ui/map_common.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:phonetowers/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phonetowers/model/device_detail.dart';

typedef void ShowSnackBar({
  required String message,
  Duration duration,
  bool isDismissible,
});

/// Top-level option-menu items, ordered to mirror the Android app's popup menu
/// (Reload Everything, Follow GPS, Hide Borders, Search, Map Mode, Hiding Menu,
/// Export Data, Polygon Precision, Remove Ads, Donate, Problems Menu, Rate App, Close App).
/// Using an enum (rather than an index into a list) guarantees the label shown always
/// maps to the correct behaviour — fixing the old "labels don't match the action" bug.
enum OptionMenuItem {
  reloadEverything,
  followGPS,
  rotatingMap,
  hideBorders,
  searchSites,
  mapMode,
  hidingMenu,
  exportData,
  polygonPrecision,
  removeAds,
  donate,
  problemsMenu,
  rateApp,
  closeApp,
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

  static int _precisionIndex(double increment) {
    if ((increment - PolygonHelper.kPolygonPrecisionLow).abs() < 1e-9) return 0;
    if ((increment - PolygonHelper.kPolygonPrecisionHigh).abs() < 1e-9) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseHelper>(
      builder: (context, purchaseHelper, child) => PopupMenuButton<OptionMenuItem>(
        icon: Icon(Icons.more_vert),
        itemBuilder: (BuildContext context) {
          return OptionMenuItem.values
              .where((OptionMenuItem item) {
                // Donations are not available on the Web build (no App Store purchases).
                if (item == OptionMenuItem.donate) return !kIsWeb;
                return true;
              })
              .map<PopupMenuItem<OptionMenuItem>>((OptionMenuItem item) {
            return PopupMenuItem<OptionMenuItem>(
              value: item,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(_topLevelTitle(item)),
                  if (_hasSubmenu(item)) ...[
                    Icon(Icons.play_arrow, color: Colors.black54, size: 12)
                  ] else if (item == OptionMenuItem.hideBorders ||
                      item == OptionMenuItem.followGPS) ...[
                    Icon(
                      item == OptionMenuItem.hideBorders
                          ? (PolygonHelper.showPolygonBorders
                              ? Icons.check_box_outline_blank
                              : Icons.check_box)
                          : (MapBodyState.followGPS
                              ? Icons.check_box
                              : Icons.check_box_outline_blank),
                      color: Colors.black54,
                      size: 14,
                    )
                  ]
                ],
              ),
            );
          }).toList();
        },
        onSelected: (OptionMenuItem item) async {
          switch (item) {
            case OptionMenuItem.reloadEverything:
              {
                SiteHelper().clearMap(
                    onCameraMoveFromLastLocation:
                        widget.onCameraMoveFromLastLocation);
                break;
              }
            case OptionMenuItem.followGPS:
              {
                await MapBodyState.toggleFollowGPS();
                break;
              }
            case OptionMenuItem.rotatingMap:
              {
                showRotatingMapMenu();
                break;
              }
            case OptionMenuItem.hideBorders:
              {
                PolygonHelper.showPolygonBorders = !PolygonHelper.showPolygonBorders;
                widget.showSnackBar(
                    message:
                        '${PolygonHelper.showPolygonBorders ? 'Showing' : 'Hiding'} polygon radiation borders!');
                Provider.of<PolygonHelper>(context, listen: false)
                    .refreshPolygons(true);
                SharedPreferencesHelper.saveBoolean(
                    key: SharedPreferencesHelper.kshowPolygonBorders,
                    value: PolygonHelper.showPolygonBorders,
                    prefs: prefs);
                setState(() {});
                break;
              }
            case OptionMenuItem.searchSites:
              {
                logger.d('search sites');
                Provider.of<SearchHelper>(context, listen: false)
                    .setSearchStatus(true);
                break;
              }
            case OptionMenuItem.mapMode:
              {
                showRadioOptionMenu();
                break;
              }
            case OptionMenuItem.hidingMenu:
              {
                showHidingMenu();
                break;
              }
            case OptionMenuItem.exportData:
              {
                showExportMenu();
                break;
              }
            case OptionMenuItem.polygonPrecision:
              {
                showPolygonPrecisionMenu();
                break;
              }
            case OptionMenuItem.removeAds:
              {
                listRemoveAdsItem.elementAt(2)
                  ..title =
                      PurchaseHelper().timeToExpireYearlySubscription.isEmpty
                          ? Strings.remove_ads_year
                          : PurchaseHelper().timeToExpireYearlySubscription
                  ..isEnabled =
                      PurchaseHelper().timeToExpireYearlySubscription.isEmpty;
                listRemoveAdsItem.elementAt(3)
                  ..title = PurchaseHelper().isSubscribedPermanently
                      ? Strings.subscribed_permanently
                      : Strings.remove_ads_permanent
                  ..isEnabled = !PurchaseHelper().isSubscribedPermanently;
                listRemoveAdsItem.elementAt(4)
                  ..isEnabled = !PurchaseHelper().isSubscribed;
                showSingleRowOptionMenu(listRemoveAdsItem, kRemoveAds);
                break;
              }
            case OptionMenuItem.donate:
              {
                listDonateItem.elementAt(2)
                  ..isEnabled = !purchaseHelper.isDonateSmallPurchased;
                listDonateItem.elementAt(3)
                  ..isEnabled = !purchaseHelper.isDonateMediumPurchased;
                listDonateItem.elementAt(4)
                  ..isEnabled = !purchaseHelper.isDonateLargePurchased;
                showSingleRowOptionMenu(listDonateItem, kDonate);
                break;
              }
            case OptionMenuItem.problemsMenu:
              {
                showProblemsMenu();
                break;
              }
            case OptionMenuItem.rateApp:
              {
                final InAppReview inAppReview = InAppReview.instance;
                if (await inAppReview.isAvailable()) {
                  inAppReview.requestReview();
                } else {
                  Utils.launchURL(
                      'https://apps.apple.com/us/app/aus-phone-towers-3g-4g-5g/id1488594332');
                }
                break;
              }
            case OptionMenuItem.closeApp:
              {
                // iOS (and Web) do not permit an app to programmatically exit, so we just
                // inform the user. On Android the equivalent menu item fully exits the app.
                widget.showSnackBar(
                    message:
                        'Close App is not available on this platform — use the device '
                        'switcher / home button to leave the app.');
                break;
              }
          }
        },
      ),
    );
  }

  String _topLevelTitle(OptionMenuItem item) {
    switch (item) {
      case OptionMenuItem.reloadEverything:
        return Strings.reload_everything;
      case OptionMenuItem.followGPS:
        return MapBodyState.followGPS ? Strings.follow_gps_on : Strings.follow_gps_off;
      case OptionMenuItem.rotatingMap:
        return Strings.rotating_map;
      case OptionMenuItem.hideBorders:
        return PolygonHelper.showPolygonBorders ? Strings.hide_border : Strings.show_border;
      case OptionMenuItem.searchSites:
        return Strings.search_sites;
      case OptionMenuItem.mapMode:
        return Strings.map_mode;
      case OptionMenuItem.hidingMenu:
        return Strings.hiding_menu;
      case OptionMenuItem.exportData:
        return Strings.export_data;
      case OptionMenuItem.polygonPrecision:
        return Strings.polygon_precision;
      case OptionMenuItem.removeAds:
        return Strings.remove_ads;
      case OptionMenuItem.donate:
        return Strings.donate;
      case OptionMenuItem.problemsMenu:
        return Strings.problems_menu;
      case OptionMenuItem.rateApp:
        return Strings.rateApp;
      case OptionMenuItem.closeApp:
        return Strings.closeApp;
    }
  }

  bool _hasSubmenu(OptionMenuItem item) =>
      item == OptionMenuItem.rotatingMap ||
      item == OptionMenuItem.mapMode ||
      item == OptionMenuItem.hidingMenu ||
      item == OptionMenuItem.exportData ||
      item == OptionMenuItem.polygonPrecision ||
      item == OptionMenuItem.problemsMenu;

  // ----- Rotating Map (mirrors Android: Travel Direction / Phone Orientation / Disable
  //       Rotation, mutually-exclusive rotatingMapGroup radio group) -----
  Future showRotatingMapMenu() async {
    final SingleRowItem travelDirection = SingleRowItem(
        title: Strings.rotating_map_travel_direction,
        isEnabled: true,
        isChecked: MapBodyState.rotatingMapMode == RotatingMapMode.travelDirection);
    final SingleRowItem phoneOrientation = SingleRowItem(
        title: Strings.rotating_map_phone_orientation,
        isEnabled: true,
        isChecked: MapBodyState.rotatingMapMode == RotatingMapMode.phoneOrientation);
    final SingleRowItem disableRotation = SingleRowItem(
        title: Strings.rotating_map_disable,
        isEnabled: true,
        isChecked: MapBodyState.rotatingMapMode == RotatingMapMode.disableRotation);
    final List<SingleRowItem> items = <SingleRowItem>[
      SingleRowItem(isTitle: true, title: Strings.rotating_map, isEnabled: false),
      travelDirection,
      phoneOrientation,
      disableRotation,
    ];
    final SingleRowItem? chosen = await showSingleRowOptionMenu(items, kRotatingMapMenu);
    if (chosen == null) return;
    if (chosen == travelDirection) {
      await MapBodyState.setRotatingMapMode(RotatingMapMode.travelDirection);
    } else if (chosen == phoneOrientation) {
      await MapBodyState.setRotatingMapMode(RotatingMapMode.phoneOrientation);
    } else if (chosen == disableRotation) {
      await MapBodyState.setRotatingMapMode(RotatingMapMode.disableRotation);
    }
    setState(() {});
  }

  // ----- Hiding Menu (mirrors Android: Hide Radiation on Click + Disable frequency refarming) -----
  Future showHidingMenu() async {
    final SingleRowItem hideRadiation = SingleRowItem(
      title: PolygonHelper.drawPolygonsOnClick
          ? Strings.hiding_menu_hide_radiation
          : Strings.hiding_menu_draw_radiation,
      isEnabled: true,
    );
    final SingleRowItem disableRefarm = SingleRowItem(
      title: Strings.disable_refarming,
      isEnabled: true,
      isChecked: !DeviceDetails.refarmEnabled,
    );
    final List<SingleRowItem> items = <SingleRowItem>[
      SingleRowItem(isTitle: true, title: Strings.hiding_menu, isEnabled: false),
      hideRadiation,
      disableRefarm,
    ];
    final SingleRowItem? chosen = await showSingleRowOptionMenu(items, kHidingMenu);
    if (chosen == null) return;
    if (chosen == hideRadiation) {
      PolygonHelper.drawPolygonsOnClick = !PolygonHelper.drawPolygonsOnClick;
      SharedPreferencesHelper.saveBoolean(
          key: SharedPreferencesHelper.kdrawPolygonsOnClick,
          value: PolygonHelper.drawPolygonsOnClick,
          prefs: prefs);
      if (!PolygonHelper.drawPolygonsOnClick) {
        PolygonHelper().clearSitePatterns(false);
      }
      setState(() {});
    } else if (chosen == disableRefarm) {
      DeviceDetails.refarmEnabled = !DeviceDetails.refarmEnabled;
      SharedPreferencesHelper.saveBoolean(
          key: SharedPreferencesHelper.krefarmEnabled,
          value: DeviceDetails.refarmEnabled,
          prefs: prefs);
      // Re-classify licences: reload sites + polygons with the new refarm setting.
      SiteHelper().clearMap(
          onCameraMoveFromLastLocation: widget.onCameraMoveFromLastLocation);
      setState(() {});
      widget.showSnackBar(
          message: DeviceDetails.refarmEnabled
              ? 'Refarming on: legacy 3G licences in 4G/5G bands shown at their current reuse (4G LTE).'
              : 'Refarming off: showing the literal licence type (e.g. 3G UMTS).');
    }
  }

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

  // ----- Polygon Precision (number of points per ring) -----
  Future showPolygonPrecisionMenu() async {
    final int current = _OptionsMenuState._precisionIndex(PolygonHelper.polygonBearingIncrement);
    final List<SingleRowItem> items = <SingleRowItem>[
      SingleRowItem(isTitle: true, title: Strings.polygon_precision, isEnabled: false),
      SingleRowItem(
          title: Strings.polygon_precision_low,
          isEnabled: true,
          isChecked: current == 0),
      SingleRowItem(
          title: Strings.polygon_precision_medium,
          isEnabled: true,
          isChecked: current == 1),
      SingleRowItem(
          title: Strings.polygon_precision_high,
          isEnabled: true,
          isChecked: current == 2),
    ];
    final SingleRowItem? chosen = await showSingleRowOptionMenu(items, kPolygonPrecision);
    if (chosen == null) return;
    int index;
    if (chosen.title == Strings.polygon_precision_low) {
      index = 0;
    } else if (chosen.title == Strings.polygon_precision_high) {
      index = 2;
    } else {
      index = 1;
    }
    PolygonHelper.polygonBearingIncrement = _precisionIncrement(index);
    SharedPreferencesHelper.setInt(
        key: SharedPreferencesHelper.kpolygonPrecision, value: index, prefs: prefs);
    setState(() {});
    widget.showSnackBar(
        message: 'Polygon precision set to ${_topLevelPrecisionLabel(index)}. '
            'Newly drawn coverage will use this.');
  }

  String _topLevelPrecisionLabel(int index) {
    switch (index) {
      case 0:
        return 'Low';
      case 2:
        return 'High';
      default:
        return 'Medium';
    }
  }

  // ----- Problems Menu (mirrors Android: Developer Mode, User Guide, Report Problem,
  //      plus the Links items — AusPhoneTowers.com.au, iOS App Store, Source Code) -----
  Future showProblemsMenu() async {
    final List<SingleRowItem> items = <SingleRowItem>[
      SingleRowItem(isTitle: true, title: Strings.problems_menu, isEnabled: false),
      SingleRowItem(
          title: MapHelper().developerMode ? Strings.regularMode : Strings.developerMode,
          isEnabled: true),
      SingleRowItem(title: Strings.userGuide, isEnabled: true),
      SingleRowItem(title: Strings.reportProblem, isEnabled: true),
      SingleRowItem(isTitle: true, title: Strings.links, isEnabled: false),
      SingleRowItem(title: Strings.ausphonetowers, isEnabled: true),
      SingleRowItem(title: Strings.iosAppStore, isEnabled: true),
      SingleRowItem(title: Strings.sourceCode, isEnabled: true),
    ];
    final SingleRowItem? chosen = await showSingleRowOptionMenu(items, kProblemsMenu);
    if (chosen == null) return;
    if (chosen.title == Strings.userGuide) {
      Utils.launchURL(kUserGuideUrl);
    } else if (chosen.title == Strings.reportProblem) {
      widget.takeScreenshot();
    } else if (chosen.title == Strings.ausphonetowers) {
      Utils.launchURL('https://ausphonetowers.com.au/');
    } else if (chosen.title == Strings.iosAppStore) {
      Utils.launchURL(
          'https://apps.apple.com/us/app/aus-phone-towers-3g-4g-5g/id1488594332');
    } else if (chosen.title == Strings.sourceCode) {
      Utils.launchURL(
          'https://github.com/bradrushworth/aus_phone_towers_iphone');
    } else {
      MapHelper().developerMode = !MapHelper().developerMode;
      MapHelper().toggleDeveloperMode();
      PolygonHelper().refreshPolygons(false);
      setState(() {});
    }
  }

  Future showSingleRowOptionMenu(
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
      }).where((singleRowItem) {
        int optionItemPosition = listSingleRowItem.indexOf(singleRowItem.value!);
        if (menuType == kRemoveAds) {
          return PurchaseHelper().isSubscribed
              ? true
              : optionItemPosition != 1;
        } else if (menuType == kDonate) {
          return PurchaseHelper().isDonated
              ? true
              : optionItemPosition != 1;
        } else {
          return true;
        }
      }).toList(),
    );

    if (singleRowItem == null) return;
    int selectedOptionItem = listSingleRowItem.indexOf(singleRowItem);
    switch (menuType) {
      // case kClearMenu: //Clear map menu option
      //   {
      //     switch (selectedOptionItem) {
      //       case 1: //Clear polygons
      //         {
      //           SiteHelper().clearPolygons();
      //           break;
      //         }
      //       case 2: //Reload everything
      //         {
      //           SiteHelper().clearMap(
      //               onCameraMoveFromLastLocation:
      //                   widget.onCameraMoveFromLastLocation);
      //           break;
      //         }
      //     }
      //     break;
      //   }
      case kRemoveAds:
        {
          switch (selectedOptionItem) {
            case 2: //Remove ads for one year
              {
                PurchaseHelper().initiatePurchase(
                    sku: PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR);
                break;
              }
            case 3: //Remove ads permanently
              {
                PurchaseHelper().initiatePurchase(
                    sku: PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY);
                break;
              }
            case 4: //Restore purchases
              {
                PurchaseHelper().restorePurchases();
                break;
              }
          }
          break;
        }
      case kDonate:
        {
          switch (selectedOptionItem) {
            case 2: //Donate small
              {
                PurchaseHelper()
                    .initiatePurchase(sku: PurchaseHelper.SKU_DONATION_SMALL);
                break;
              }
            case 3: //Donate medium
              {
                PurchaseHelper()
                    .initiatePurchase(sku: PurchaseHelper.SKU_DONATION_MEDIUM);
                break;
              }
            case 4: //Donate large
              {
                PurchaseHelper()
                    .initiatePurchase(sku: PurchaseHelper.SKU_DONATION_LARGE);
                break;
              }
          }
          break;
        }
    }
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

    int selectedOptionItem = listRadioItem.indexOf(radioItem!);
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

List<SingleRowItem> listRemoveAdsItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.remove_ads, isEnabled: true),
  SingleRowItem(
      isTitle: true,
      title: Strings.remove_ads_subscribe_previous,
      isEnabled: false),
  SingleRowItem(
      title: PurchaseHelper().timeToExpireYearlySubscription.isEmpty
          ? Strings.remove_ads_year
          : PurchaseHelper().timeToExpireYearlySubscription,
      isEnabled: PurchaseHelper().timeToExpireYearlySubscription.isEmpty),
  SingleRowItem(
      title: PurchaseHelper().isSubscribedPermanently
          ? Strings.subscribed_permanently
          : Strings.remove_ads_permanent,
      isEnabled: !PurchaseHelper().isSubscribedPermanently),
  SingleRowItem(
      title: Strings.restore_purchases,
      isEnabled: true),
];

List<SingleRowItem> listDonateItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.donate, isEnabled: true),
  SingleRowItem(title: Strings.donatePrevious, isEnabled: false),
  SingleRowItem(
      title: Strings.donateSmall,
      isEnabled: !PurchaseHelper().isDonateSmallPurchased),
  SingleRowItem(
      title: Strings.donateMedium,
      isEnabled: !PurchaseHelper().isDonateMediumPurchased),
  SingleRowItem(
      title: Strings.donateLarge,
      isEnabled: !PurchaseHelper().isDonateLargePurchased),
];

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
