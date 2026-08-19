import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsHelper {
  static final AdsHelper _singleton = new AdsHelper._internal();

  factory AdsHelper() {
    return _singleton;
  }

  AdsHelper._internal();

  BannerAd? bannerAd;

  // Inline adaptive banner sizes (used for [showBannerAd]) always report
  // height 0 on [BannerAd.size] — the real height is only known once the ad
  // has loaded, via [BannerAd.getPlatformAdSize]. Widgets must size
  // themselves from this field instead of `bannerAd!.size`, or the loaded ad
  // renders into a zero-height container and never appears on screen.
  AdSize? loadedAdSize;

  static String androidAdmobAppId = 'ca-app-pub-6156750794650893~5795736618';
  static String androidPortraitAdUnitId = 'ca-app-pub-6156750794650893/7272469813';
  static String androidLandscapeAdUnitId = 'ca-app-pub-6156750794650893/2424837889';
  static String iOSAdmobAppId = 'ca-app-pub-6156750794650893~6040337543';
  static String iOSPortraitAdUnitId = 'ca-app-pub-6156750794650893/6818248500';
  static String iOSLandscapeAdUnitId = 'ca-app-pub-6156750794650893/9444411844';

  void initialize() {
    MobileAds.instance.initialize()
        .then((initializationStatus) {
      initializationStatus.adapterStatuses.forEach((key, value) {
        debugPrint('Adapter status for $key: ${value.description}');
      });
    });
  }

  void showBannerAd(AdSize bannerAdSize, String adUnitId,
      {void Function()? onAdLoaded}) {
    // Configure my personal devices so I don't get in trouble with Google
    List<String> testDevices = [];
    testDevices.add("A04D16B625198F3E16D9214B07CCAAD1"); // My Pixel 3 XL (laptop)
    testDevices.add("B51BDAC25EBAECE25CC0F4985D1A8DDE"); // My Pixel 3 XL (desktop)
    testDevices.add("98F0065AD2F5F13DC15FD37B7511DBBD"); // My Pixel 8 Pro
    testDevices.add("965EC0108F9D63C0E64858EE030729B9"); // My Pixel 8 Pro
    RequestConfiguration requestConfiguration = RequestConfiguration(
        maxAdContentRating: 'MA', testDeviceIds: testDevices);
    MobileAds.instance.updateRequestConfiguration(requestConfiguration);

    AdRequest adRequestBuilder = new AdRequest(keywords: []);
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

    BannerAd(
      adUnitId: adUnitId,
      request: adRequestBuilder,
      size: bannerAdSize,
      listener: BannerAdListener(
        onAdLoaded: (ad) async {
          // Called when an ad is successfully received.
          debugPrint("Ads was loaded.");
          bannerAd = ad as BannerAd;
          // For inline adaptive sizes, `ad.size` is always the requested
          // placeholder (height 0) — fetch the real rendered size so the
          // widget knows how tall to draw itself.
          loadedAdSize = await bannerAd!.getPlatformAdSize() ?? bannerAd!.size;
          onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, err) {
          // Called when an ad request failed.
          debugPrint("Ads failed to load with error: $err");
          ad.dispose();
        },
      ),
    ).load();
  }

  void hideBannerAd() async {
    await bannerAd?.dispose();
    bannerAd = null;
    loadedAdSize = null;
    debugPrint("Ads: hideBannerAd()");
  }
}
