import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';

class AnalyticsHelper {
  static final AnalyticsHelper _singleton = new AnalyticsHelper._internal();
  factory AnalyticsHelper() {
    return _singleton;
  }
  AnalyticsHelper._internal();

  final FirebaseAnalytics analytics = FirebaseAnalytics();

  sendCustomAnalyticsEvent(
      {@required String eventName, @required Map eventParameters}) {
    analytics.logEvent(
      name: 'Flutter_$eventName',
      parameters: eventParameters,
    );
  }
}
