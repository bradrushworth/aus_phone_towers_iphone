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

    // Commercial-intent keywords only, mirroring the Android (Java) app's tuned
    // buildAdKeywords head: terms telcos and ISPs actually bid on (plans, SIMs, data,
    // home internet) plus the app's own coverage/tower vocabulary and the road-trip
    // audience. The old hobbyist tail (pager, PMR, CB radio, amateur radio, scanner,
    // TV, CBRS, aviation) had near-zero advertiser demand and diluted the list.
    AdRequest adRequestBuilder = new AdRequest(keywords: [
      "mobile phone", "mobile plan", "SIM only", "prepaid", "unlimited data",
      "home internet", "internet plan", "NBN", "broadband",
      "mobile coverage", "coverage map", "signal booster",
      "mobile tower", "phone tower", "cell tower",
      "5G", "4G", "wireless internet",
      "GPS navigation", "road trip", "camping",
      "satellite phone", "Australia",
    ]);

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
