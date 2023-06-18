import 'package:google_mobile_ads/google_mobile_ads.dart';

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
    testDevices.add('B5BD02099B12769D58DBD05B64D1DFAF');
    testDevices.add('FD6126EE250BB0AA9187FFE30B3C9EE1');
    testDevices.add('B51BDAC25EBAECE25CC0F4985D1A8DDE'); //Brad's Pixel device
    testDevices.add('A04D16B625198F3E16D9214B07CCAAD1'); //Brad's Pixel device
    testDevices.add('8BC2F1BE6EB20545CF043C876600C5AB');
    testDevices.add('Simulator');
    testDevices.add('a5e1ca2639fd4e667d54aef8a97596db');
    testDevices.add('4de629f9b10e172f3eaf81e029c4bf8c');
    testDevices.add('92FEAF2ECD4341E45333F23BDC864907');
    testDevices
        .add("A04D16B625198F3E16D9214B07CCAAD1"); // My Pixel 3 XL (laptop)
    testDevices
        .add("B51BDAC25EBAECE25CC0F4985D1A8DDE"); // My Pixel 3 XL (desktop)
    testDevices.add("E2205354A906F833537939B2DED80DBB"); // My Pixel 6 Pro
    RequestConfiguration requestConfiguration = RequestConfiguration(
        maxAdContentRating: 'T', testDeviceIds: testDevices);
    MobileAds.instance.updateRequestConfiguration(requestConfiguration);

    Future.delayed(Duration(seconds: 1), () {
      bannerAd ??= BannerAd(
        adUnitId: adUnitId,
        size: bannerAdSize,
        //targetingInfo: AppConstants.isDebug ? targetingInfo : null,
        // listener: (MobileAdEvent event) {
        //   print("BannerAd event $event");
        // },
        listener: BannerAdListener(),
        request: AdRequest(),
      );
      bannerAd?..load();
    });
  }

  void hideBannerAd() async {
    await bannerAd?.dispose();
    bannerAd = null;
  }
}
