class Secret {
  final String androidAdmobAppId;
  final String androidPortraitAdUnitId;
  final String androidLandscapeAdUnitId;

  final String iOSAdmobAppId;
  final String iOSPortraitAdUnitId;
  final String iOSLandscapeAdUnitId;
  final String terrainAwarenessKey;

  Secret(
      {this.androidAdmobAppId = '',
      this.androidPortraitAdUnitId = '',
      this.androidLandscapeAdUnitId = '',
      this.iOSAdmobAppId = '',
      this.iOSLandscapeAdUnitId = '',
      this.iOSPortraitAdUnitId = '',
      this.terrainAwarenessKey = ''});

  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return new Secret(
      androidAdmobAppId: jsonMap["androidAdmobAppId"],
      androidPortraitAdUnitId: jsonMap["androidPortraitAdUnitId"],
      androidLandscapeAdUnitId: jsonMap["androidLandscapeAdUnitId"],
      iOSAdmobAppId: jsonMap["iOSAdmobAppId"],
      iOSLandscapeAdUnitId: jsonMap["iOSLandscapeAdUnitId"],
      iOSPortraitAdUnitId: jsonMap["iOSPortraitAdUnitId"],
      terrainAwarenessKey: jsonMap["terrain_awareness_key"],
    );
  }
}
