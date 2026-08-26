import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' as Foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/purchase_helper.dart';
import 'package:phonetowers/helpers/search_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/pathloss/path_loss_model_provider.dart';
import 'package:phonetowers/ui/map_common.dart';
import 'package:phonetowers/utils/secretloader.dart';
import 'package:phonetowers/utils/strings.dart';
import 'package:provider/provider.dart';

import 'helpers/ads_helper.dart';
import 'helpers/polygon_helper.dart';
import 'utils/secret.dart';
import 'utils/screenshot_mode.dart';

Logger logger = new Logger();
final bool useFirebase = (kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

Future<void> main() async {
  // Set `enableInDevMode` to true to see reports while in debug mode
  // This is only to be used for confirming that reports are being
  // submitted as expected. It is not intended to be used for everyday
  // development.

  runZonedGuarded(() async {
    await WidgetsFlutterBinding.ensureInitialized();

    if (kScreenshotMode) debugPrint('SCREENSHOT_MODE: binding ready, skipping ATT');

    // Never prompt during the screenshot run — see [kScreenshotMode]. There is nobody to
    // answer the dialog, and awaiting it deadlocks startup before runApp().
    if (!kIsWeb && Platform.isIOS && !kScreenshotMode) {
      // Show tracking authorization dialog and ask for permission
      await AppTrackingTransparency.requestTrackingAuthorization();
      await AppTrackingTransparency.getAdvertisingIdentifier();
    }

    // Initialize Firebase
    if (useFirebase) {
      if (!kIsWeb) {
        if (!Foundation.kDebugMode) {
          // Mobile version gets them from GoogleService-Info.plist or google-services.json
          await Firebase.initializeApp();
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
    }

    // Initialise Crashlytics and ads
    if (!kIsWeb) {
      if (useFirebase) {
        if (!Foundation.kDebugMode) {
          await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

          // Pass all uncaught errors to Crashlytics.
          FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
        }
      }

      // Initialize admob
      AdsHelper().initialize();

      // Initialize In App Purchase (No longer required?)
      //InAppPurchaseConnection.enablePendingPurchases();
    }

    if (kScreenshotMode) debugPrint('SCREENSHOT_MODE: past Firebase, loading secrets');

    //Load secrets
    Secret secret = await SecretLoader(secretPath: 'assets/json/secrets.json').load();
    AdsHelper.androidAdmobAppId = secret.androidAdmobAppId;
    AdsHelper.androidPortraitAdUnitId = secret.androidPortraitAdUnitId;
    AdsHelper.androidLandscapeAdUnitId = secret.androidLandscapeAdUnitId;
    AdsHelper.iOSAdmobAppId = secret.iOSAdmobAppId;
    AdsHelper.iOSPortraitAdUnitId = secret.iOSPortraitAdUnitId;
    AdsHelper.iOSLandscapeAdUnitId = secret.iOSLandscapeAdUnitId;
    PolygonHelper.terrainAwarenessKey = secret.terrainAwarenessKey;
    PolygonHelper.terrainAwarenessKeyIos = secret.terrainAwarenessKeyIos;
    PolygonHelper.terrainAwarenessKeyAndroid = secret.terrainAwarenessKeyAndroid;
    //print("iOSLandscapeAdUnitId is ${secret.iOSLandscapeAdUnitId}");

    // Fetch learned path-loss coefficients from the server (fire-and-forget). The app
    // continues with the analytic Hata/COST-231 fallback until the fetch completes, then
    // the learned model is swapped in — matching the Android app's behaviour.
    PathLossModelProvider.initProvider();

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
    if (kScreenshotMode) debugPrint('SCREENSHOT_MODE: calling runApp');

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
  }, (error, stackTrace) {
    if (useFirebase && !Foundation.kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace);
    } else {
      throw error;
    }
  });
}

class AusPhoneTowers extends StatelessWidget {
  // F0 (UI overhaul port): light + dark themes seeded from the same purple accent the Android
  // app's Material 3 components use, following the system setting. The status bar follows the
  // theme instead of being hard-forced light.
  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final bool isDark = brightness == Brightness.dark;
    // statusBarColor and statusBarIconBrightness are ANDROID-ONLY; iOS reads statusBarBrightness,
    // and reads it as the brightness of the BACKGROUND behind the bar (dark background => iOS
    // draws light glyphs). Setting only the Android pair left the iPhone status bar unmanaged, so
    // dark mode kept dark glyphs over a dark map (reported on iOS 1.14.4). Set both families.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    ));

    return MaterialApp(
      title: Strings.app_title,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: MapScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final ColorScheme scheme =
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4), brightness: brightness);
    return ThemeData(
        colorScheme: scheme,
        appBarTheme: AppBarTheme(
            iconTheme: IconThemeData(color: dark ? Colors.grey[400] : Colors.grey, size: 32),
            elevation: 0.0,
            backgroundColor:
                (dark ? const Color(0xFF1D1B23) : Colors.white).withValues(alpha: 0.85)),
        textTheme: TextTheme(
            // bodySmall is the cell-info row along the bottom of the map (map_common.dart
            // ~1690-1760). 10 sp of monospace was hard to read at a glance, which is the one
            // moment it has to be read — while driving. Nudged to 11.5; kept modest because those
            // rows are fixed-width and monospace, so a large jump risks clipping rather than
            // wrapping.
            bodySmall: TextStyle(
                fontFamily: 'RobotoMono',
                color: dark ? Colors.grey[300] : Colors.grey[800],
                fontSize: 11.5),
            labelLarge: TextStyle(color: dark ? Colors.grey[300] : Colors.grey[700])),
        inputDecorationTheme: InputDecorationTheme(
          enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: dark ? Colors.grey[400]! : Colors.grey[700]!)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: dark ? Colors.grey[400]! : Colors.grey[700]!)),
        ),
        // map_common.dart references elevatedButtonTheme.style, which previously resolved to
        // null because no theme ever defined it.
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer)));
  }
}
