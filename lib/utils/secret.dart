class Secret {
  final String admob_app_id;
  final String androidAdmobAppId;
  final String androidPortraitAdUnitId;
  final String androidLandscapeAdUnitId;

  final String iOSAdmobAppId;
  final String iOSPortraitAdUnitId;
  final String iOSLandscapeAdUnitId;
  final String terrainAwarenessKey;

  Secret(
      {this.admob_app_id = "",
      this.androidAdmobAppId = '',
      this.androidPortraitAdUnitId = '',
      this.androidLandscapeAdUnitId = '',
      this.iOSAdmobAppId = '',
      this.iOSLandscapeAdUnitId = '',
      this.iOSPortraitAdUnitId = '',
      this.terrainAwarenessKey = ''});

  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return new Secret(
      admob_app_id: jsonMap["admob_app_id"],
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
