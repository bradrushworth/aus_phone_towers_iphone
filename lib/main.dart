import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' as Foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/ui/map_common.dart';
import 'package:phonetowers/utils/secretloader.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';

import 'helpers/ads_helper.dart';
import 'helpers/polygon_helper.dart';
import 'utils/secret.dart';

Logger logger = new Logger();

Future<void> main() async {
  // Set `enableInDevMode` to true to see reports while in debug mode
  // This is only to be used for confirming that reports are being
  // submitted as expected. It is not intended to be used for everyday
  // development.

  runZoned<Future<void>>(() async {
    await WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    if (!kIsWeb) {
      if (!Foundation.kDebugMode) {
        // Mobile version gets them from GoogleService-Info.plist or google-services.json
        //await Firebase.initializeApp(); // TODO
      }
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
      if (!Foundation.kDebugMode) {
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false); // TODO

        // Pass all uncaught errors to Crashlytics.
        //FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError; // TODO
      }

      if (Platform.isIOS) {
        // Show tracking authorization dialog and ask for permission
        final status = await AppTrackingTransparency.requestTrackingAuthorization();
      }

      // Initialize admob
      AdsHelper().initialize();

      // Initialize In App Purchase (No longer required?)
      //InAppPurchaseConnection.enablePendingPurchases();
    }

    //Load secrets
    Secret secret = await SecretLoader(secretPath: 'assets/json/secrets.json').load();
    AdsHelper.androidAdmobAppId = secret.androidAdmobAppId;
    AdsHelper.androidPortraitAdUnitId = secret.androidPortraitAdUnitId;
    AdsHelper.androidLandscapeAdUnitId = secret.androidLandscapeAdUnitId;
    AdsHelper.iOSAdmobAppId = secret.iOSAdmobAppId;
    AdsHelper.iOSPortraitAdUnitId = secret.iOSPortraitAdUnitId;
    AdsHelper.iOSLandscapeAdUnitId = secret.iOSLandscapeAdUnitId;
    PolygonHelper.terrainAwarenessKey = secret.terrainAwarenessKey;
    //print("iOSLandscapeAdUnitId is ${secret.iOSLandscapeAdUnitId}");

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
      // onError: kIsWeb || Foundation.kDebugMode // TODO
      //     ? (exception, stack) {}
      //     : await FirebaseCrashlytics.instance.recordError
  );
}

class AusPhoneTowers extends StatelessWidget {
  // This widget is the root of the application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark
        .copyWith(statusBarColor: Colors.white, statusBarIconBrightness: Brightness.dark));

    return MaterialApp(
      title: Strings.app_title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          appBarTheme: AppBarTheme(
              iconTheme: new IconThemeData(color: Colors.grey, size: 32),
              elevation: 0.0,
              color: Colors.white.withOpacity(0.85)),
          textTheme: TextTheme(
              bodyText1: TextStyle(fontFamily: 'RobotoMono', color: Colors.grey[800], fontSize: 10),
              button: TextStyle(color: Colors.grey[700])),
          inputDecorationTheme: InputDecorationTheme(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
          )),
      home: MapScreen(),
    );
  }
}
