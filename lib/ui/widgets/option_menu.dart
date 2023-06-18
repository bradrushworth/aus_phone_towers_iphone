import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/shared_pref_helper.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:phonetowers/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef void ShowSnackBar({String message});

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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchaseHelper>(
      builder: (context, purchaseHelper, child) => PopupMenuButton<OptionItem>(
        icon: Icon(Icons.more_vert),
        itemBuilder: (BuildContext context) {
          return listOptionItem
              .map<PopupMenuItem<OptionItem>>((OptionItem optionItem) {
            return PopupMenuItem<OptionItem>(
              value: optionItem,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(optionItem.title),
                  if (optionItem.trailing) ...[
                    Icon(
                      Icons.play_arrow,
                      color: Colors.black54,
                      size: 12,
                    )
                  ]
                ],
              ),
            );
          }).where((optionItem) {
            int optionItemPosition = listOptionItem.indexOf(optionItem.value!);
            if (!kIsWeb && Platform.isAndroid) {
              return SearchHelper.calculatingSearchResults
                  ? optionItemPosition != 1
                  : true;
            } else {
              // Remove below code when IAP is implemented for iOS.
              if (optionItemPosition == 1) {
                return !SearchHelper.calculatingSearchResults;
              } else if (optionItemPosition == 5 || optionItemPosition == 6) {
                return false;
              } else {
                return true;
              }
            }
          }).toList();
        },
        onSelected: (optionItem) async {
          int selectedOptionItem = listOptionItem.indexOf(optionItem);
          switch (selectedOptionItem) {
            case 0: //Show / Hide border
              {
                PolygonHelper.showPolygonBorders =
                    !PolygonHelper.showPolygonBorders;
                optionItem.title = PolygonHelper.showPolygonBorders
                    ? Strings.hide_border
                    : Strings.show_border;
                widget.showSnackBar(
                    message:
                        '${PolygonHelper.showPolygonBorders ? 'Showing' : 'Hiding'} polygon radiation borders!');
                //Make UI changes
                Provider.of<PolygonHelper>(context, listen: false)
                    .refreshPolygons(true);
                //Saving in shared pref
                SharedPreferencesHelper.saveBoolean(
                    key: SharedPreferencesHelper.kshowPolygonBorders,
                    value: PolygonHelper.showPolygonBorders,
                    prefs: prefs);
                break;
              }
            case 1: //Search sites
              {
                logger.d('search sites');
                Provider.of<SearchHelper>(context, listen: false)
                    .setSearchStatus(true);
                break;
              }
            case 2: //Clear everything
              {
                SiteHelper().clearMap(
                    onCameraMoveFromLastLocation:
                        widget.onCameraMoveFromLastLocation);
                break;
              }
            case 3: //Map mode
              {
                showRadioOptionMenu();
                break;
              }
            case 4: //Hiding menu
              {
                showSingleRowOptionMenu(listHidingMenuItem, kHidingMenu);
                break;
              }
            case 5: //Remove ads
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
                showSingleRowOptionMenu(listRemoveAdsItem, kRemoveAds);
                break;
              }
            case 6: //Donate
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
            case 7: //Developer or Regular mode
              {
                MapHelper().developerMode = !MapHelper().developerMode;
                optionItem.title = MapHelper().developerMode
                    ? Strings.regularMode
                    : Strings.developerMode;
                MapHelper().toggleDeveloperMode();
                PolygonHelper().refreshPolygons(false);
                break;
              }
            case 8: //Report problem
              {
                widget.takeScreenshot();
                break;
              }
            case 9: //Source code
              {
                showSingleRowOptionMenu(listLinksItem, kLinks);
                break;
              }
          }
        },
      ),
    );
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
          return PurchaseHelper().isShowSubscribePreviousMenuItem
              ? true
              : optionItemPosition != 1;
        } else if (menuType == kDonate) {
          return PurchaseHelper().isShowDonatePreviousMenuItem
              ? true
              : optionItemPosition != 1;
        } else {
          return true;
        }
      }).toList(),
    );

    int selectedOptionItem = listSingleRowItem.indexOf(singleRowItem!);
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
      case kHidingMenu: //Hiding menu
        {
          switch (selectedOptionItem) {
            case 1: //Hide/ Show radiation on click
              {
                PolygonHelper.drawPolygonsOnClick =
                    !PolygonHelper.drawPolygonsOnClick;
                singleRowItem.title = PolygonHelper.drawPolygonsOnClick
                    ? Strings.hiding_menu_hide_radiation
                    : Strings.hiding_menu_draw_radiation;
                setState(() {});
                if (!PolygonHelper.drawPolygonsOnClick) {
                  PolygonHelper().clearSitePatterns(false);
                  SiteHelper().clearPolygons();
                  //disableFollowGPS(); TODO
                }
                //Saving in shared pref
                SharedPreferencesHelper.saveBoolean(
                    key: SharedPreferencesHelper.kdrawPolygonsOnClick,
                    value: PolygonHelper.drawPolygonsOnClick,
                    prefs: prefs);
                break;
              }
          }
          break;
        }
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
      case kLinks:
        {
          switch (selectedOptionItem) {
            case 1: //Rate App TODO Not relevant for web!
              {
                final InAppReview inAppReview = InAppReview.instance;

                if (await inAppReview.isAvailable()) {
                  inAppReview.requestReview();
                }

                // This package also has in app review, but it should not be used on a direct button tab.
                // inAppReview.openStoreListing(appStoreId: kAppleId

                break;
              }

            case 2: //AusPhoneTowers.com.au
              {
                Utils.launchURL('https://ausphonetowers.com.au/');
                break;
              }
            case 3: //iOS App Store
              {
                Utils.launchURL(
                    'https://apps.apple.com/us/app/aus-phone-towers-3g-4g-5g/id1488594332');
                break;
              }
            case 4: //Source Code
              {
                Utils.launchURL(
                    'https://github.com/bradrushworth/aus_phone_towers_iphone');
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
                  contentPadding: EdgeInsets.all(0),
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
class OptionItem {
  OptionItem({required this.title, this.trailing = false});

  String title;
  final bool trailing;
}

List<OptionItem> listOptionItem = <OptionItem>[
  OptionItem(
      title: PolygonHelper.showPolygonBorders
          ? Strings.hide_border
          : Strings.show_border),
  OptionItem(title: Strings.search_sites),
  OptionItem(title: Strings.reload_everything),
  OptionItem(title: Strings.map_mode, trailing: true),
  OptionItem(title: Strings.hiding_menu, trailing: true),
  OptionItem(title: Strings.remove_ads, trailing: true),
  OptionItem(title: Strings.donate, trailing: true),
  OptionItem(
      title: MapHelper().developerMode
          ? Strings.regularMode
          : Strings.developerMode),
  OptionItem(title: Strings.reportProblem),
  OptionItem(title: Strings.links, trailing: true),
];

//********************** Clear map ***************************//
class SingleRowItem {
  SingleRowItem(
      {this.isTitle = false, required this.title, this.prefix, this.isEnabled = true});

  bool isTitle;
  String title;
  final Widget? prefix;
  bool isEnabled;
}

// List<SingleRowItem> listClearMapItem = <SingleRowItem>[
//   SingleRowItem(isTitle: true, title: Strings.clear_map, isEnabled: false),
//   SingleRowItem(title: Strings.clear_polygons, prefix: Icon(Icons.clear)),
//   SingleRowItem(
//       title: Strings.reload_everything, prefix: Icon(Icons.delete_forever))
// ];

List<SingleRowItem> listHidingMenuItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.hiding_menu, isEnabled: false),
  SingleRowItem(
      title: PolygonHelper.drawPolygonsOnClick
          ? Strings.hiding_menu_hide_radiation
          : Strings.hiding_menu_draw_radiation),
];

List<SingleRowItem> listRemoveAdsItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.remove_ads, isEnabled: false),
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
];

List<SingleRowItem> listDonateItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.donate, isEnabled: false),
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

List<SingleRowItem> listLinksItem = <SingleRowItem>[
  SingleRowItem(isTitle: true, title: Strings.links),
  SingleRowItem(title: Strings.rateApp),
  SingleRowItem(title: Strings.ausphonetowers),
  SingleRowItem(title: Strings.iosAppStore),
  SingleRowItem(title: Strings.sourceCode),
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
