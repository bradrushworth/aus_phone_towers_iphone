import 'dart:io';

import 'package:firebase_admob/firebase_admob.dart';
import 'package:phonetowers/utils/app_constants.dart';

class AdsHelper {
  static final AdsHelper _singleton = new AdsHelper._internal();
  factory AdsHelper() {
    return _singleton;
  }
  AdsHelper._internal();

  BannerAd _bannerAd;
  static String androidAdmobAppId = '';
  static String androidPortraitAdUnitId = '';
  static String androidLandscapeAdUnitId = '';
  static String iOSAdmobAppId = '';
  static String iOSPortraitAdUnitId = '';
  static String iOSLandscapeAdUnitId = '';

  MobileAdTargetingInfo targetingInfo = MobileAdTargetingInfo(
    testDevices: <String>[
      'B5BD02099B12769D58DBD05B64D1DFAF',
      'FD6126EE250BB0AA9187FFE30B3C9EE1',
      'B51BDAC25EBAECE25CC0F4985D1A8DDE', //Brad's Pixel device
      'A04D16B625198F3E16D9214B07CCAAD1', //Brad's Pixel device
      '8BC2F1BE6EB20545CF043C876600C5AB',
      'Simulator', 'a5e1ca2639fd4e667d54aef8a97596db',
      '4de629f9b10e172f3eaf81e029c4bf8c',
      '92FEAF2ECD4341E45333F23BDC864907'
    ],
  );

  void initialize() {
    FirebaseAdMob.instance.initialize(
        appId: Platform.isAndroid ? androidAdmobAppId : iOSAdmobAppId);
  }

  void showBannerAd(AdSize bannerAdSize, String adUnitId) {
    Future.delayed(Duration(seconds: 1), () {
      _bannerAd ??= BannerAd(
        adUnitId: adUnitId,
        size: bannerAdSize,
        targetingInfo: AppConstants.isDebug ? targetingInfo : null,
        listener: (MobileAdEvent event) {
          print("BannerAd event $event");
        },
      )
        ..load()
        ..show();
    });
  }

  void hideBannerAd() async {
    await _bannerAd?.dispose();
    _bannerAd = null;
  }
}
