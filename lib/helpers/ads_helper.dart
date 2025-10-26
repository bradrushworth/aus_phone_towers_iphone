import 'package:flutter/foundation.dart' as Foundation;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:phonetowers/helpers/site_helper.dart';

class AdsHelper {
  static final AdsHelper _singleton = new AdsHelper._internal();

  factory AdsHelper() {
    return _singleton;
  }

  AdsHelper._internal();

  BannerAd? bannerAd;
  static String androidAdmobAppId = '';
  static String androidPortraitAdUnitId = '';
  static String androidLandscapeAdUnitId = '';
  static String iOSAdmobAppId = '';
  static String iOSPortraitAdUnitId = '';
  static String iOSLandscapeAdUnitId = '';

  void initialize() {
    MobileAds.instance.initialize();
  }

  void showBannerAd(AdSize bannerAdSize, String adUnitId) {
    // Configure my personal devices so I don't get in trouble with Google
    List<String> testDevices = [];
    testDevices.add("A04D16B625198F3E16D9214B07CCAAD1"); // My Pixel 3 XL (laptop)
    testDevices.add("B51BDAC25EBAECE25CC0F4985D1A8DDE"); // My Pixel 3 XL (desktop)
    testDevices.add("98F0065AD2F5F13DC15FD37B7511DBBD"); // My Pixel 8 Pro
    RequestConfiguration requestConfiguration = RequestConfiguration(
        maxAdContentRating: 'MA', testDeviceIds: testDevices);
    MobileAds.instance.updateRequestConfiguration(requestConfiguration);

    AdRequest adRequestBuilder = new AdRequest();
    adRequestBuilder.keywords!.add("mobile");
    adRequestBuilder.keywords!.add("mobile tower");
    adRequestBuilder.keywords!.add("mobile coverage");
    adRequestBuilder.keywords!.add("telco");
    adRequestBuilder.keywords!.add("telecommunications");
    adRequestBuilder.keywords!.add("phone tower");
    adRequestBuilder.keywords!.add("cell tower");
    adRequestBuilder.keywords!.add("cell site");
    adRequestBuilder.keywords!.add("mobile phone");
    adRequestBuilder.keywords!.add("4G");
    adRequestBuilder.keywords!.add("5G");
    adRequestBuilder.keywords!.add("LTE");
    adRequestBuilder.keywords!.add("NR");
    adRequestBuilder.keywords!.add("spectrum");
    adRequestBuilder.keywords!.add("internet");
    adRequestBuilder.keywords!.add("NBN");
    adRequestBuilder.keywords!.add("broadband");
    adRequestBuilder.keywords!.add("radio");
    adRequestBuilder.keywords!.add("TV");
    adRequestBuilder.keywords!.add("CBRS");
    adRequestBuilder.keywords!.add("aviation");
    adRequestBuilder.keywords!.add("pager");
    adRequestBuilder.keywords!.add("emergency");
    adRequestBuilder.keywords!.add("PMR");
    adRequestBuilder.keywords!.add("satellite");
    adRequestBuilder.keywords!.add("CB radio");
    adRequestBuilder.keywords!.add("amateur radio");
    adRequestBuilder.keywords!.add("scanner");
    adRequestBuilder.keywords!.add("Australia");

    Future.delayed(Duration(seconds: 1), () {
      bannerAd ??= BannerAd(
        adUnitId: adUnitId,
        size: bannerAdSize,
        //targetingInfo: AppConstants.isDebug ? targetingInfo : null,
        // listener: (MobileAdEvent event) {
        //   print("BannerAd event $event");
        // },
        listener: BannerAdListener(),
        request: adRequestBuilder,
      );

      bannerAd?..load();
    });
  }

  void hideBannerAd() async {
    await bannerAd?.dispose();
    bannerAd = null;
  }
}
