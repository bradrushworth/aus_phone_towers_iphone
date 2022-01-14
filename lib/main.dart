import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' as Foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/ui/map_screen.dart';
import 'package:phonetowers/utils/app_constants.dart';
import 'package:phonetowers/utils/secretloader.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';

import 'helpers/ads_helper.dart';
import 'helpers/polygon_helper.dart';
import 'utils/secret.dart';

Future<void> main() async {
  enableFlutterDriverExtension();
  Logger logger = new Logger();

  // Set `enableInDevMode` to true to see reports while in debug mode
  // This is only to be used for confirming that reports are being
  // submitted as expected. It is not intended to be used for everyday
  // development.
  await WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  if (!kIsWeb) {
    // Mobile version gets them from GoogleService-Info.plist or google-services.json
    await Firebase.initializeApp();
  } else {
    // Web version needs the parameters sent though here
    await Firebase.initializeApp(
      // Replace with actual values
        options: FirebaseOptions(
            apiKey: "AIzaSyDSjVeI6yRIbl_VtihyNEe-JgxEl_LCupA",
            authDomain: "aus-phone-towers-7d175.firebaseapp.com",
            databaseURL: "https://aus-phone-towers-7d175.firebaseio.com",
            projectId: "aus-phone-towers-7d175",
            storageBucket: "aus-phone-towers-7d175.appspot.com",
            messagingSenderId: "742739090143",
            appId: "1:742739090143:web:a7d35db594855884b2a76a",
            measurementId: "G-WT4TEP3Z7X"));
  }

  // Initialise Crashlytics
  if (!kIsWeb) {
    if (AppConstants.isDebug || AppConstants.isMock || Foundation.kDebugMode || Platform.environment.containsKey('FLUTTER_TEST')) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }
  }

  // Initialize In App Purchase (No longer required?)
  //InAppPurchaseConnection.enablePendingPurchases();

  //Load secrets
  Secret secret =
  await SecretLoader(secretPath: 'assets/json/secrets.json').load();
  AdsHelper.androidAdmobAppId = secret.androidAdmobAppId;
  AdsHelper.androidPortraitAdUnitId = secret.androidPortraitAdUnitId;
  AdsHelper.androidLandscapeAdUnitId = secret.androidLandscapeAdUnitId;
  AdsHelper.iOSAdmobAppId = secret.iOSAdmobAppId;
  AdsHelper.iOSPortraitAdUnitId = secret.iOSPortraitAdUnitId;
  AdsHelper.iOSLandscapeAdUnitId = secret.iOSLandscapeAdUnitId;
  PolygonHelper.terrainAwarenessKey = secret.terrainAwarenessKey;
  //print("iOSLandscapeAdUnitId is ${secret.iOSLandscapeAdUnitId}");

  if (!kIsWeb) {
    // Initialize admob
    MobileAds.instance.initialize();

    // Pass all uncaught errors to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  }

  /*
  * runZoned Provides monitoring on whole app and reporting to the FireBase.
  *
  *
  *
  * MultiProvider(https://pub.dev/packages/provider):  It uses dependency provider.
  * Actively communicate with below screens:
  * PolygonHelper(), SiteHelper(), SearchHelper(), MapHelper(). PurchaseHelper().
  *
  *
  *  */
  runZoned<Future<void>>(() async {
    runApp(MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => PolygonHelper(),
        ),
        ChangeNotifierProvider(
          create: (context) => SiteHelper(),
        ),
        ChangeNotifierProvider(
          create: (context) => SearchHelper(),
        ),
        ChangeNotifierProvider(
          create: (context) => MapHelper(),
        ),
        ChangeNotifierProvider(
          create: (context) => PurchaseHelper(),
        ),
      ],
      child: AusPhoneTowers(),
    ));
  },
      onError:
      kIsWeb ? (exception) {} : FirebaseCrashlytics.instance.recordError);
}

class AusPhoneTowers extends StatelessWidget {
  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark));

    return MaterialApp(
      title: Strings.app_title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          appBarTheme: AppBarTheme(
              iconTheme: new IconThemeData(color: Colors.grey, size: 32),
              elevation: 0.0,
              color: Colors.white.withOpacity(0.7)),
          textTheme: TextTheme(
              bodyText1: TextStyle(
                  fontFamily: 'RobotoMono',
                  color: Colors.grey[700],
                  fontSize: 10),
              button: TextStyle(color: Colors.grey[600])),
          inputDecorationTheme: InputDecorationTheme(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[600])),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[600])),
          )),
      home: MapScreen(),
    );
  }
}
