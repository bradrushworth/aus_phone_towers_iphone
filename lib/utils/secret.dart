class Secret {
  final String androidAdmobAppId;
  final String androidPortraitAdUnitId;
  final String androidLandscapeAdUnitId;

  final String iOSAdmobAppId;
  final String iOSPortraitAdUnitId;
  final String iOSLandscapeAdUnitId;
  final String terrainAwarenessKey;

  /// The iOS-restricted Maps key for the Elevation API (see GetElevation). Optional so a
  /// secrets file that predates it still loads; iOS then falls back to the legacy key.
  final String terrainAwarenessKeyIos;

  /// The Android-restricted Maps key for the Elevation API (see GetElevation). Optional;
  /// while empty, Android uses the legacy key with the site-Referer arrangement.
  final String terrainAwarenessKeyAndroid;

  Secret(
      {this.androidAdmobAppId = '',
      this.androidPortraitAdUnitId = '',
      this.androidLandscapeAdUnitId = '',
      this.iOSAdmobAppId = '',
      this.iOSLandscapeAdUnitId = '',
      this.iOSPortraitAdUnitId = '',
      this.terrainAwarenessKey = '',
      this.terrainAwarenessKeyIos = '',
      this.terrainAwarenessKeyAndroid = ''});

  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return new Secret(
      androidAdmobAppId: jsonMap["androidAdmobAppId"],
      androidPortraitAdUnitId: jsonMap["androidPortraitAdUnitId"],
      androidLandscapeAdUnitId: jsonMap["androidLandscapeAdUnitId"],
      iOSAdmobAppId: jsonMap["iOSAdmobAppId"],
      iOSLandscapeAdUnitId: jsonMap["iOSLandscapeAdUnitId"],
      iOSPortraitAdUnitId: jsonMap["iOSPortraitAdUnitId"],
      terrainAwarenessKey: jsonMap["terrainAwarenessKey"],
      terrainAwarenessKeyIos: jsonMap["terrainAwarenessKeyIos"] ?? '',
      terrainAwarenessKeyAndroid: jsonMap["terrainAwarenessKeyAndroid"] ?? '',
    );
  }
}
