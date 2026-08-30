import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/export_helper.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/ui/map_common.dart';
import 'package:phonetowers/ui/widgets/layers_settings_sheets.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/ui/widgets/support_prompt_screen.dart';
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

/// Top-level option-menu items, ordered to mirror the Android app's popup menu (Reload
/// Everything, Follow GPS, Hide Borders, Search, Map Mode, Hiding Menu, Export Data, Remove
/// Ads, Donate, Problems Menu, Rate App, Close App). `lockMap` and `polygonPrecision` have no
/// Android equivalent (iOS-only features) and are placed next to their closest thematic
/// neighbour (rotatingMap, exportData) rather than breaking the shared ordering.
/// Using an enum (rather than an index into a list) guarantees the label shown always
/// maps to the correct behaviour — fixing the old "labels don't match the action" bug.
/// F5 (UI overhaul port): the overflow slims to match the Android Phase 5 bar — Follow GPS,
/// Search and the funnel live on the toolbar; map-surface options moved to the Layers sheet;
/// rotation, refarming, Developer Mode, help links and Rate App moved to the Settings sheet.
/// Declaration order is on-screen order (kept aligned with the Java app's popup_menu.xml).
enum OptionMenuItem {
  reloadEverything,
  exportData,
  settings,
  removeAds,
  donate,
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
                // Remove Ads is the same store-purchase machinery — also absent on Web.
                if (item == OptionMenuItem.removeAds) return !kIsWeb;
                // Only Android permits an app to programmatically exit -- iOS and Web have no
                // equivalent, so the menu item is irrelevant there rather than just a no-op.
                if (item == OptionMenuItem.closeApp) {
                  return !kIsWeb && Platform.isAndroid;
                }
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
            case OptionMenuItem.removeAds:
              {
                listRemoveAdsItem.elementAt(2)
                  ..title =
                      PurchaseHelper().timeToExpireYearlySubscription.isEmpty
                          ? PurchaseHelper().priceLabel(
                              sku: PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR,
                              name: Strings.remove_ads_year_name,
                              fallback: Strings.remove_ads_year)
                          : PurchaseHelper().timeToExpireYearlySubscription
                  ..isEnabled =
                      PurchaseHelper().timeToExpireYearlySubscription.isEmpty;
                listRemoveAdsItem.elementAt(3)
                  ..title = PurchaseHelper().isSubscribedPermanently
                      ? Strings.subscribed_permanently
                      : PurchaseHelper().priceLabel(
                          sku: PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY,
                          name: Strings.remove_ads_permanent_name,
                          fallback: Strings.remove_ads_permanent)
                  ..isEnabled = !PurchaseHelper().isSubscribedPermanently;
                listRemoveAdsItem.elementAt(4)
                  ..isEnabled = !PurchaseHelper().isSubscribed;
                showSingleRowOptionMenu(listRemoveAdsItem, kRemoveAds);
                break;
              }
            case OptionMenuItem.donate:
              {
                listDonateItem.elementAt(2)
                  ..title = PurchaseHelper().priceLabel(
                      sku: PurchaseHelper.SKU_DONATION_SMALL,
                      name: Strings.donateSmallName,
                      fallback: Strings.donateSmall)
                  ..isEnabled = !purchaseHelper.isDonateSmallPurchased;
                listDonateItem.elementAt(3)
                  ..title = PurchaseHelper().priceLabel(
                      sku: PurchaseHelper.SKU_DONATION_MEDIUM,
                      name: Strings.donateMediumName,
                      fallback: Strings.donateMedium)
                  ..isEnabled = !purchaseHelper.isDonateMediumPurchased;
                listDonateItem.elementAt(4)
                  ..title = PurchaseHelper().priceLabel(
                      sku: PurchaseHelper.SKU_DONATION_LARGE,
                      name: Strings.donateLargeName,
                      fallback: Strings.donateLarge)
                  ..isEnabled = !purchaseHelper.isDonateLargePurchased;
                showSingleRowOptionMenu(listDonateItem, kDonate);
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
      case OptionMenuItem.exportData:
        return Strings.export_data;
      case OptionMenuItem.settings:
        return 'Settings';
      case OptionMenuItem.removeAds:
        return Strings.remove_ads;
      case OptionMenuItem.donate:
        return Strings.donate;
      case OptionMenuItem.closeApp:
        return Strings.closeApp;
    }
  }

  bool _hasSubmenu(OptionMenuItem item) =>
      item == OptionMenuItem.exportData ||
      item == OptionMenuItem.settings ||
      item == OptionMenuItem.removeAds ||
      item == OptionMenuItem.donate;

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

    if (singleRowItem == null) return null;
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
                PurchaseHelper().restorePurchases(userInitiated: true);
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
            case 5: //Support the App
              {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SupportPromptScreen()));
                break;
              }
          }
          break;
        }
    }
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

List<SingleRowItem> listRemoveAdsItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.remove_ads, isEnabled: true),
  SingleRowItem(
      isTitle: true,
      title: Strings.remove_ads_subscribe_previous,
      isEnabled: false),
  SingleRowItem(
      title: PurchaseHelper().timeToExpireYearlySubscription.isEmpty
          ? PurchaseHelper().priceLabel(
              sku: PurchaseHelper.SKU_SUBSCRIBE_ONE_YEAR,
              name: Strings.remove_ads_year_name,
              fallback: Strings.remove_ads_year)
          : PurchaseHelper().timeToExpireYearlySubscription,
      isEnabled: PurchaseHelper().timeToExpireYearlySubscription.isEmpty),
  SingleRowItem(
      title: PurchaseHelper().isSubscribedPermanently
          ? Strings.subscribed_permanently
          : PurchaseHelper().priceLabel(
              sku: PurchaseHelper.SKU_SUBSCRIBE_PERMANENTLY,
              name: Strings.remove_ads_permanent_name,
              fallback: Strings.remove_ads_permanent),
      isEnabled: !PurchaseHelper().isSubscribedPermanently),
  SingleRowItem(
      title: Strings.restore_purchases,
      isEnabled: true),
];

List<SingleRowItem> listDonateItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.donate, isEnabled: true),
  SingleRowItem(title: Strings.donatePrevious, isEnabled: false),
  SingleRowItem(
      title: PurchaseHelper().priceLabel(
          sku: PurchaseHelper.SKU_DONATION_SMALL,
          name: Strings.donateSmallName,
          fallback: Strings.donateSmall),
      isEnabled: !PurchaseHelper().isDonateSmallPurchased),
  SingleRowItem(
      title: PurchaseHelper().priceLabel(
          sku: PurchaseHelper.SKU_DONATION_MEDIUM,
          name: Strings.donateMediumName,
          fallback: Strings.donateMedium),
      isEnabled: !PurchaseHelper().isDonateMediumPurchased),
  SingleRowItem(
      title: PurchaseHelper().priceLabel(
          sku: PurchaseHelper.SKU_DONATION_LARGE,
          name: Strings.donateLargeName,
          fallback: Strings.donateLarge),
      isEnabled: !PurchaseHelper().isDonateLargePurchased),
  SingleRowItem(title: Strings.donateSupportPrompt, isEnabled: true),
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
