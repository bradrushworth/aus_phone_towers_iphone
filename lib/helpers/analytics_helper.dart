import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' as Foundation;

class AnalyticsHelper {
  static final AnalyticsHelper _singleton = new AnalyticsHelper._internal();

  factory AnalyticsHelper() {
    return _singleton;
  }

  AnalyticsHelper._internal();

  log(String message) {
    if (!Foundation.kDebugMode) {
      FirebaseCrashlytics.instance.log(message);
    }
  }

  sendCustomAnalyticsEvent(
      {@required String eventName, @required Map eventParameters}) {
    if (!Foundation.kDebugMode) {
      FirebaseAnalytics.instance.logEvent(
        name: 'Flutter_$eventName',
        parameters: eventParameters,
      );
    }
  }
}
