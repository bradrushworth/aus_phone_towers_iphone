# Audit of the iPhone (Flutter) app against the Android app, 2026-11-12

App 1.16.3+164, branch `claude/audit-2026-11-12` (= `origin/main`). Reference: the Android app at
7.11.1 (359) with its fixes of 2026-11-12. Read-only: no code was changed, no tests or builds were
run, no network was touched. Paths are relative to this repository unless they start with
`android-repo:`.

## Summary

The shared logic that must stay in lockstep mostly is. The network-type classifier matches the
Android one arm for arm, including the September dual 4G/5G arms. The bundled path-loss table and
the shared test vectors are byte-identical in both repositories. The ads keyword head and the Map
Layers labels match.

Three things are wrong on the map itself:

- 5G rings are drawn at different signal levels from Android (I1).
- A site with no active transmitter never appears after its details load (I2).
- A failed tower download leaves that area empty until Refresh Data, with no message (I3).

The export, which exists for search and rescue, cannot leave the phone and does not carry the
height and elevation fields the Android export does (I4, I5).

On compliance, the app has no privacy-policy link and no app-level privacy manifest, and the
Android build of this project can only be installed on Android 14 or later because of a swapped
variable (I10 to I12).

## Findings, ranked by user impact

| id | area | severity | status | claim |
|----|------|----------|--------|-------|
| I1 | Parity: coverage | P1 | CONFIRMED | 5G rings use -65/-80/-90/-110 dBm; Android has used -80/-90/-100/-110 since 2026-08-23. |
| I2 | Defect: map | P1 | CONFIRMED in code (device check) | A site whose transmitters are all inactive stays invisible after its details load. |
| I3 | Defect: map | P1 | CONFIRMED | A failed tower download marks the area as done; the area stays empty and nothing is shown. |
| I4 | Parity: export | P1 | CONFIRMED | Exported files are written where the user cannot reach them; each menu choice writes more than it says; web shows "Exporting" and then nothing. |
| I5 | Parity: export | P1 | CONFIRMED | Export has no ground elevation or antenna-top elevation, floors heights under 10 m to 10 m, includes towers hidden by filters, and uses different field names from Android. |
| I6 | Defect: filters | P2 | CONFIRMED | At launch the "Other" carrier switch takes the Optus switch's value. |
| I7 | Defect: camera | P2 | CONFIRMED in code (device check) | The map moves back to where it was at the last backgrounding whenever the app becomes active without having been backgrounded. |
| I8 | Defect: search | P2 | CONFIRMED | With no connection, search reports "No sites match" instead of a connection error. |
| I9 | Defect: support | P2 | CONFIRMED | Report a Problem takes a screenshot and never attaches it; without Apple Mail set up it is a dead end. |
| I10 | Compliance | P2 | CONFIRMED absent | No privacy-policy link anywhere in the app or guide. |
| I11 | Compliance | P2 | CONFIRMED absent (effect PLAUSIBLE) | No app-level `PrivacyInfo.xcprivacy`, though the app asks for tracking permission. |
| I12 | Android build | P2 | CONFIRMED | `minSdkVersion` is set from the target-SDK variable: minimum is Android 14, not Android 7. |
| I13 | Compliance | P2 | PLAUSIBLE | `AppDelegate` reads the window's root view controller at launch; this breaks under the UIScene life cycle Apple is moving to. |
| I14 | Parity: ads | P3 | CONFIRMED | Ad requests carry only the fixed keyword head; Android adds suburb, state, postcode and carrier terms. |
| I15 | Defect: settings | P3 | CONFIRMED | Map rotation mode is not saved between launches. |
| I16 | Defect: search | P3 | CONFIRMED | Any four digits anywhere in a query turn the whole query into a postcode search. |
| I17 | Defect: filters | P3 | CONFIRMED | Dense Air and NBN share one preference key. |
| I18 | Compliance | P3 | CONFIRMED in file (effect PLAUSIBLE) | "Always" location strings with no background use; the export-compliance key is a string; tracking permission is requested from two places. |
| I19 | Compliance | P3 | PLAUSIBLE | No consent flow for users in Europe or the UK. |
| I20 | Build | P3 | CONFIRMED | Flutter, Xcode and CocoaPods versions float between builds; two dependencies are unused. |
| I21 | Android build | P3 | PLAUSIBLE | Back while the search field is open leaves the app instead of closing the field. |
| I22 | Docs | P3 | CONFIRMED | AGENTS.md, CLAUDE.md and README.md describe things that no longer exist. |

---

## Parity gaps (Android has it or differs)

### I1. 5G rings are drawn at different signal levels (P1, CONFIRMED)

**Evidence.** `lib/helpers/network_type_helper.dart:7` has `nrBars = [-65, -80, -90, -110]`.
`android-repo:app/src/main/java/au/com/bitbot/phonetowers/utilities/NetworkType.java:25-29` has
`{-80, -90, -100, -110}`, with a comment that it was retuned on 2026-08-23 from the values this
app still carries. Both drawing paths read the array (`lib/restful/get_licenceHRP.dart:240-241`,
`lib/helpers/polygon_helper.dart:755`).

**Effect.** With the default filter (Good), the outer 5G ring on iPhone is the -90 dBm line and on
Android the -100 dBm line. The same tower looks smaller on iPhone. The Maximum ring (-65 dBm) is a
few tens of metres wide and tells the user nothing. Model v2 was calibrated for the Android rungs.

**Fix brief (haiku; no owner decision, the Android rule is "keep it one definition").**
- `lib/helpers/network_type_helper.dart:7`: set `nrBars` to `[-80, -90, -100, -110]`; copy the
  Android comment.
- New `test/helpers/network_type_helper_test.dart`: assert the four arrays for GSM, UMTS, LTE and
  NR equal the Android values, with a comment naming `NetworkType.java` as the other side.
- Search `test/` for expectations built on -65 and update them.
- CHANGELOG: "5G rings now mark the same signal levels as the Android app; 5G shapes get larger."

### I4. Exported files cannot leave the phone (P1, CONFIRMED)

**Evidence.**
- `lib/helpers/export_helper.dart:45` and `:90` write to `getApplicationDocumentsDirectory()`.
  `ios/Runner/Info.plist` has neither `UIFileSharingEnabled` nor
  `LSSupportsOpeningDocumentsInPlace`, and there is no share call, so the folder is invisible to
  the Files app.
- `lib/ui/widgets/option_menu.dart:211-224` shows the sandbox path in a snackbar for ten seconds.
- `option_menu.dart:197-208`: "Export Towers (GeoJSON)" and "Export Towers (CSV)" both write both
  files; "Export Coverage (GeoJSON)" writes GeoJSON, CSV and KML.
- On web the menu still offers Export Data, and `ExportHelper` uses `dart:io`, so the future
  fails and the "Exporting towers..." message is the last thing shown.

The user guide already lists the iPhone limit as known. It is ranked P1 because the guide also
says this feature exists for search and rescue.

**Fix brief, step 1 (haiku; state the Info.plist change before making it).**
- `ios/Runner/Info.plist`: add `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`,
  both `<true/>`. The app writes nothing else to Documents (screenshots go to the temporary
  directory, `lib/helpers/screenshot_controller.dart:32`), so nothing else is exposed.
- `export_helper.dart`: write into a `Exports` subfolder; delete files older than 30 days first.
- `option_menu.dart:_reportExport`: message "Saved to Files → On My iPhone → Aus Phone Towers →
  Exports" on iOS; file names only, not full paths.
- `option_menu.dart`: do not show Export Data when `kIsWeb` until step 2.
- Update section 9 of `docs/user-guide.html` and the README table.

**Fix brief, step 2 (sonnet; owner decision: adds the `share_plus` dependency).**
- After writing, open the share sheet with the files (`SharePlus.instance.share` with `XFile`s and
  a `sharePositionOrigin` for iPad). On web, download through a Blob link in a web-only file,
  following the `user_guide_view_web.dart` pattern.
- Make each menu row write only the format it names.
- Test: move the "which files for which choice" rule into a pure
  `ExportHelper.formatsFor(ExportChoice)` and test it in `test/helpers/export_helper_test.dart`.

### I5. The export does not carry the fields search and rescue needs (P1, CONFIRMED)

**Evidence.** `lib/helpers/export_helper.dart:107-123` writes `name, operatorName, siteId,
networkType, lteType, frequency, bandwidth, emission, eirp, azimuth, towerHeight, latitude,
longitude`, one row per band. Against the Android contract
(`android-repo:app/src/main/java/au/com/bitbot/phonetowers/helper/ExportHelper.java:94-99`,
`:317-336`):

- No `ground_elevation_m` and no `antenna_top_elevation_m`, the two viewshed inputs. The site's
  ACMA elevation (`Site.elevation`) and the terrain-model ground height (`Site.terrainGroundM`)
  are both in memory.
- `towerHeight` is `DeviceDetails.getTowerHeight()` (`lib/model/device_detail.dart:564-572`),
  which returns 10 for any height under 10 m, including unknown. A 4 m small cell exports as
  10 m. Android exports the real maximum, average and minimum, and omits unknowns.
- One row per band keeps one arbitrary sector's azimuth, power and height
  (`Site.getDeviceDetailsMobileBands`, `lib/model/site.dart:284-312`).
- `export_helper.dart:80-86` exports every site ever loaded, including those hidden by the
  filters. Android exports visible markers only.
- CSV: a null `eirp` or `azimuth` is written as the text `null`.
- Field names differ, so an agency's CalTopo or ArcGIS template for the Android file does not
  load the iPhone file.

The site sheet has the same height problem: "Tower Height" is the average of the floored values
(`lib/ui/map_common.dart:2000-2007`).

**Fix brief (sonnet; owner decision: field names in a safety-critical export, and whether to add
the terrain-model fields the Android audit proposed as A16; ship both apps in one release).**
- New pure `lib/helpers/export_feature.dart`: `TowerExportRow.fromSite(siteId, name, telco, lat,
  lng, acmaElevationText, demGroundM, deviceHeights, technologies, frequenciesMhz, state,
  postcode, cityDensity, active)` producing the Android columns in the Android order: `site_id,
  name, telco, latitude, longitude, ground_elevation_m, antenna_height_max_m,
  antenna_height_avg_m, antenna_height_min_m, antenna_top_elevation_m, technologies,
  frequencies_mhz, transmitter_count, state, postcode, city_density, active`.
- Heights use the raw `DeviceDetails.height`, ignoring values of 0 or less. Never call
  `getTowerHeight()` here.
- `ground_elevation_m` is the parsed ACMA text, null when blank or not a number.
  `antenna_top_elevation_m` is ground plus maximum height, null when either is null.
- If the owner approves the A16 fields, add `ground_elevation_dem_m`, `elevation_check` (`ok`,
  `differs` over 30 m, `unverified`) and `antenna_height_all_max_m` with the same names as Android.
- One feature per site. Export only sites whose marker is visible. Write nulls as empty CSV cells.
- Coverage export: rename to the Android names (`frequency_mhz`, `bandwidth_mhz`, `eirp_w`,
  `azimuth_deg`, `antenna_height_m`, `signal_ring`, `signal_dbm`, `signal_measure`,
  `terrain_aware`).
- Site sheet: show "Antenna height" as the raw minimum to maximum, or omit the row when unknown.
- Tests in `test/helpers/export_feature_test.dart`: a 4 m antenna exports 4; unknown height gives
  empty height and empty antenna-top; blank ACMA elevation gives empty ground; the CSV header
  equals the Android column list.

### I14. Ad requests lack the local keywords Android sends (P3, CONFIRMED)

**Evidence.** `lib/helpers/ads_helper.dart:69-77` sends the 23-term head only. It matches the
Android head exactly. Android then adds postcode, state (short and full name), suburb words and
carrier terms from the loaded sites, up to 40 keywords
(`android-repo:app/src/main/java/au/com/bitbot/phonetowers/MapsActivity.java:2313` onward).

**Fix brief (haiku; no owner decision).**
- New pure `lib/helpers/ad_keywords.dart`: `List<String> build(Iterable<({String? state, String?
  postcode, String? name})> sites)`: the head, then postcode, state and full state name, then
  name words not in the Android stop-word list; de-duplicated, capped at 40.
- `AdsHelper.showBannerAd`: build from `SiteHelper.globalListMapOverlay`.
- Test `test/helpers/ad_keywords_test.dart`: the head is first and unchanged; the cap holds; "NSW"
  adds "New South Wales"; stop words are dropped.

---

## iPhone-only defects

### I2. Sites with no active transmitter never appear (P1, CONFIRMED in code)

**Evidence.** A marker is created invisible because `Site.shouldBeVisible()` returns false until
the site's transmitters are loaded (`lib/model/site.dart:181-184`). When they arrive,
`lib/restful/get_devices.dart:136-146` does this:

```dart
final Marker? marker = SiteHelper.globalListMapOverlay[i].marker;
SiteHelper.globalListMapOverlay[i].marker = marker!.copyWith(visibleParam: site.shouldBeVisible());
if (!site.active) {
  SiteHelper.globalListMapOverlay[i].marker = marker.copyWith(alphaParam: marker.alpha / 2);
}
```

The second assignment copies the original, still-invisible marker, so for an inactive site the
visibility update is thrown away. Android shows these sites as half-transparent pins. Here they
stay hidden until something calls `SiteHelper.refreshSites()` (any filter change). A site whose
transmitters span two result pages would also be halved twice.

**Device check.** Find a pin Android draws half-transparent; look at the same place on iPhone
after a fresh launch; then toggle any filter chip and look again.

**Fix brief (haiku; no owner decision).**
- `lib/restful/get_devices.dart`: add `static Marker markerAfterDevices(Marker m, {required bool
  visible, required bool active, required double baseAlpha})` returning `m.copyWith(visibleParam:
  visible, alphaParam: active ? baseAlpha : baseAlpha / 2)`. Use it in the loop with
  `baseAlpha: site.alpha`.
- Test `test/restful/get_devices_marker_test.dart`: an inactive, visible site gives
  `visible == true` and half alpha; calling it twice does not halve again.

### I3. A failed tower download leaves the area empty for the session (P1, CONFIRMED)

**Evidence.**
- `SiteHelper.downloadedGeohashAlready` (`lib/helpers/site_helper.dart:76-88`) records the area as
  downloaded at the moment it is asked, before any request is made. `getNeighbourRing`
  (`lib/ui/map_common.dart:1554`) does the same for the surrounding ring.
- `Api.getMarkerData` returns null on any network error or bad status (`lib/networking/api.dart`).
- `downloadTowersForSingleTelco` then evaluates `rawResponse!.restify` (`map_common.dart:1349`),
  which throws. The error goes to Crashlytics as a non-fatal; the user sees nothing.

So a timeout in poor coverage, which is where this app is used, leaves that area blank for that
carrier until Refresh Data. A failed later page loses the rest of the area the same way.

**Fix brief (sonnet; no owner decision).**
- `SiteHelper`: add `static void forgetGeohashes(Iterable<String> geohashes, Telco telco)`.
- `downloadTowersForSingleTelco`: add a parameter `List<String> requestedGeohashes` (the single
  hash, or the ring's hashes; make `getNeighbourRing` return the list as well as the filter).
  When `rawResponse == null`, call `forgetGeohashes`, show one snackbar "Server is unreachable!"
  (the Android wording) at most once every 30 seconds, and return.
- A response with zero rows is a real answer; keep it marked.
- Test in `test/site_helper_test.dart`: mark, forget, and `downloadedGeohashAlready` is false
  again for that carrier only.

### I6. "Other" carriers follow the Optus switch at launch (P2, CONFIRMED)

**Evidence.** `lib/helpers/site_helper.dart:207`:
`toggleTelcoMarkers(Telco.Other, NavigationMenu.isOptusVisible);`. `enableTelcoInUse(true)` runs at
every launch from `_loadNavigationSavedState` (`lib/ui/map_common.dart:919-926`). With Optus hidden
and Other shown, Other is hidden and never downloaded while its chip reads on; the reverse shows
Other with its chip off.

**Fix brief (haiku).** Use `NavigationMenu.isOtherVisible`. Test in `test/site_helper_test.dart`:
set Optus false and Other true, call `enableTelcoInUse(true)`, expect `hideTelco` to contain
Optus and not Other.

### I7. The map jumps back when the app becomes active again (P2, CONFIRMED in code)

**Evidence.** `didChangeAppLifecycleState` (`lib/ui/map_common.dart:641-661`) saves the camera on
`paused` and restores it on every `resumed`. iOS sends `inactive` then `resumed`, with no `paused`,
when Notification Centre or Control Centre is pulled down, when the purchase sheet or a permission
dialog closes, and after a glance at the app switcher. The stored position is then the one from
the last real backgrounding, possibly a previous session. After a real backgrounding the saved and
current positions are the same, so the restore does nothing useful; the cold-start case is already
handled in `onMapCreated` (`:1027`).

**Device check.** Launch, pan a few kilometres, pull Notification Centre down and release.

**Fix brief (haiku; no owner decision).** Remove the `resumed` branch. Make
`_restoreCameraIfAvailable` return null when preferences are not yet loaded (it reads a `late`
field). Keep `test/camera_restore_helper_test.dart` passing; no new pure logic.

### I8. Search with no connection says "No sites match" (P2, CONFIRMED)

**Evidence.** `Api.getSearchedData` (`lib/networking/api.dart:102-117`) catches the error and
returns null. `SearchHelper.getSearch` (`lib/helpers/search_helper.dart:98-100`) reads null as
zero rows, so its own "Could not reach the tower database" branch (`:121-128`) cannot run for a
network failure.

**Fix brief (haiku).** In `getSearch`, treat a null response as a failure and take the existing
error branch. Extract `static bool searchFailed(SiteResponse? r) => r == null` and test it in
`test/helpers/search_helper_test.dart`.

### I9. Report a Problem does not attach the screenshot (P2, CONFIRMED)

**Evidence.** Dart captures a PNG and sends its name (`lib/ui/map_common.dart:2237-2251`).
`ios/Runner/AppDelegate.swift:44-60` opens a mail composer with the text "Please attach your
screenshot" and returns; the code that would attach the image is commented out below the
`return`. If Apple Mail has no account the user gets "Can't send mail / Please configure mail
app". The Android side of this project attaches the file.

**Fix brief (sonnet; no owner decision; needs a Mac build to verify).**
- `AppDelegate.shareFile`: read the PNG from the temporary directory by the name passed in
  `path`. If `MFMailComposeViewController.canSendMail()`, attach it with `addAttachmentData`.
  Otherwise present a `UIActivityViewController` with the image and the subject text, with
  `popoverPresentationController.sourceView` set for iPad.
- Change the body text to "Describe the problem...".
- Update the Help section of `docs/user-guide.html`.

### I15. Map rotation mode is not saved (P3, CONFIRMED)

**Evidence.** `MapBodyState.rotatingMapMode` is a static with a default
(`lib/ui/map_common.dart:296`); `lib/utils/shared_pref_helper.dart` has no key for it. Android
saves it. Lock Map being session-only is a recorded difference and is not reported.

**Fix brief (haiku).** Add `krotatingMapMode`, write the enum index in the Settings chip handler
(`lib/ui/widgets/layers_settings_sheets.dart:270-287`), read it in `_loadNavigationSavedState`.
For a saved Phone orientation, start the compass only when Follow GPS is turned on, not at launch,
so no permission prompt appears at start-up. Pure `RotatingMapMode fromIndex(int?)` with a test.

### I16. Four digits anywhere make a postcode search (P3, CONFIRMED)

**Evidence.** `lib/helpers/search_helper.dart:78-82`: `RegExp(r'\d{4}').hasMatch(query)` is not
anchored, so "Lot 1234 Smith Rd" sends the whole text as a postcode and finds nothing. The
postcode value is also placed in the filter unencoded.

**Fix brief (haiku).** Use `RegExp(r'^\d{4}$')` on the trimmed query; encode the value. Extract
`static String buildFilter(String query)` and test: "2600" gives a postcode filter, "Lot 1234
Smith Rd" a name filter.

### I17. Dense Air and NBN share a preference key (P3, CONFIRMED)

**Evidence.** `lib/utils/shared_pref_helper.dart:9`: `kisDenseAirVisible = 'isNBNVisible'`. Dense
Air is not downloaded today (`lib/ui/map_common.dart:1298`), so the effect is small.

**Fix brief (haiku).** Change the value to `'isDenseAirVisible'`. No migration needed.

---

## Compliance and build

Checked and in order: Restore Purchases exists and is user-reachable
(`lib/ui/widgets/layers_settings_sheets.dart:333-339`); there is no auto-renewing subscription, so
in-app subscription terms and EULA links are not required; prices come from the store;
`NSUserTrackingUsageDescription`, `SKAdNetworkItems` and `GADApplicationIdentifier` are present;
there are no background modes; the Android target API is 36; all sheets are modal routes, so Back
and predictive back close them without extra code.

### I10. No privacy-policy link in the app (P2, CONFIRMED absent)

**Evidence.** A search of `lib/` and `docs/user-guide.html` for "privacy" finds no link. The app
shows personalised ads, asks for tracking permission and uses location. App Review guideline
5.1.1(i) asks for the policy to be reachable inside the app, and Google's ads policy asks the same.

**Fix brief (haiku; owner decision: the URL).** Add a "Privacy policy" row to the Help section of
`SettingsSheet` (`lib/ui/widgets/layers_settings_sheets.dart:341` onward) and a line in the guide.
The guide may not link out (`test/docs/user_guide_html_test.dart`), so print the address there as
text. Check that App Store Connect and the Play listing carry the same URL.

### I11. No app-level privacy manifest (P2, CONFIRMED absent; effect PLAUSIBLE)

**Evidence.** There is no `ios/Runner/PrivacyInfo.xcprivacy` and none is referenced in
`ios/Runner.xcodeproj/project.pbxproj`. Plugins ship their own manifests, but the app is the one
that declares tracking (`ios/Runner/Info.plist:68`, `lib/main.dart:45-49`).

**Check.** After the next upload, read the App Store Connect email for ITMS-91053 or ITMS-91061
warnings, and generate the privacy report from the Xcode archive.

**Fix brief (sonnet; owner decision: the declared data types must match the App Privacy answers in
App Store Connect; state the xcodeproj change before making it).** Add `PrivacyInfo.xcprivacy` to
the Runner target with `NSPrivacyTracking` true, the tracking domains Google documents for the
Mobile Ads SDK, `NSPrivacyCollectedDataTypes` for precise location (app functionality), device ID
(third-party advertising) and crash data, and an empty `NSPrivacyAccessedAPITypes` unless the
report lists an API used by the app's own Swift code.

### I12. The Android build needs Android 14 (P2, CONFIRMED)

**Evidence.** `android/app/build.gradle:66-67`:

```
minSdkVersion rootProject.ext.targetSdkVersion      // 34
targetSdkVersion rootProject.ext.compileSdkVersion  // 36
```

`android/build.gradle:6-7` defines `minSdkVersion = 24` and `targetSdkVersion = 34`; the commit
that introduced this says "minSdk=24, targetSdk=34". Target 36 is what Play needs, so only the
minimum is wrong.

**Fix brief (haiku; state the build.gradle change first).** Line 66 becomes
`minSdkVersion rootProject.ext.minSdkVersion`. Set `targetSdkVersion = 36` in
`android/build.gradle` and read that variable on line 67, so the names mean what they say. Check
with `flutter build apk --debug` and `aapt dump badging`.

### I13. Launch code will not survive the UIScene life cycle (P2, PLAUSIBLE)

**Evidence.** `ios/Runner/AppDelegate.swift:19` force-casts `self.window?.rootViewController` in
`didFinishLaunchingWithOptions` to set up the screenshot channel. `Info.plist` has no
`UIApplicationSceneManifest`. Under a scene-based life cycle the window does not exist at that
point, and the force-cast crashes at launch. Apple has said the scene life cycle becomes mandatory
for apps built with the SDK after iOS 26.

**Check.** Read Flutter's "UIScene migration" page for the Flutter version Codemagic's `stable`
resolves to, and Apple's technote on the scene-based life cycle, for the date.

**Fix brief (sonnet; needs a Mac build).** Follow Flutter's migration: register the channel in the
engine-initialised callback using the plugin registry's messenger instead of the window's view
controller, present from the key window's root view controller at call time, then add the scene
manifest. Until then, replace the force-cast with `guard let` so a nil window cannot crash.

### I18. Info.plist details (P3, CONFIRMED in file; effect PLAUSIBLE)

- `Info.plist:33-38` carries `NSLocationAlwaysUsageDescription` and
  `NSLocationAlwaysAndWhenInUseUsageDescription`. The app has no background mode and only uses
  location while open. The text also says the app will "provide directions", which it hands to
  another app. **Check:** remove the two Always keys on a branch, run on a device, confirm the
  location prompt and Follow GPS still work with the `location` plugin.
- `Info.plist:66-67`: `ITSAppUsesNonExemptEncryption` is `<string>NO</string>`. Apple documents a
  Boolean. **Check:** whether new TestFlight builds show "Missing Compliance". Fix: `<false/>`.
- Tracking permission is requested in `lib/main.dart:45-49`, awaited before the first frame, and
  again in `lib/ui/map_common.dart:113-139`. `AdsHelper().initialize()` is also called twice
  (`main.dart:86`, `map_common.dart:369`). Keep one request (the post-first-frame one), started
  before ads initialise, and skip it for users already ad-free. Sonnet; device check on a fresh
  install that the prompt still appears once.
- `io.flutter.embedded_views_preview` is obsolete and can go.

### I19. No consent flow for Europe and the UK (P3, PLAUSIBLE)

No use of the Google consent (UMP) API in `lib/`. Google requires a certified consent platform to
serve ads to users in the EEA, UK and Switzerland. **Check:** the territories selected in App
Store Connect and Play. If only Australia and New Zealand, nothing to do; record that here.
Otherwise add the UMP flow before `MobileAds.initialize` (sonnet; owner decision).

### I20. Builds are not reproducible (P3, CONFIRMED)

- `codemagic.yaml:44-46`: `flutter: stable`, `xcode: latest`, `cocoapods: default`.
- `ios/Podfile.lock` is not in git, so the native Google Maps, Ads and Firebase versions are
  chosen at build time.
- `permission_handler` and `html_unescape` are in `pubspec.yaml` and imported nowhere in `lib/`.

**Fix brief (haiku; owner approval for pubspec and codemagic changes).** Pin Flutter to the
version that built 1.16.3, commit `ios/Podfile.lock` from a Codemagic build, remove the two unused
packages. Keep `xcode: latest` if the owner prefers Apple's SDK deadlines to be met automatically,
and say so in a comment.

### I21. Back in search mode leaves the app on Android (P3, PLAUSIBLE)

The search field replaces the title without pushing a route (`lib/ui/map_common.dart:434-477`), so
system Back has nothing to pop. **Check:** Android build, tap Search, press Back.
**Fix brief (haiku).** Wrap `MapBody` in `PopScope(canPop: !SearchHelper.calculatingSearchResults,
onPopInvokedWithResult: ...)` that calls `setSearchStatus(false)`. Widget test in
`test/ui/search_back_test.dart`.

### I22. Developer docs that no longer match (P3, CONFIRMED)

- `AGENTS.md:64-69` gives a Flutter path from another machine.
- `AGENTS.md` "Top-level option menu ordering" lists thirteen items; `option_menu.dart` has six.
- `AGENTS.md:292` says Support the App is the last item of a Donate submenu
  (`listDonateItem`), which was removed.
- `AGENTS.md:275` says everything below 3 GHz is 4G or old 3G; the classifier has nine dual 4G/5G
  arms below 3 GHz.
- `CLAUDE.md` ends with unfilled template sections.
- `README.md` describes the legacy path-loss fetch as the current model in "Path loss algorithm".
- `lib/helpers/cell_identity.dart` is 1,200 lines of commented-out Java.

Haiku, one commit, no behaviour change.

---

## Not applicable on iOS

| Android item | Why it does not apply here |
|---|---|
| A2 to A5, A12 to A14 (upload accuracy, dual SIM, NSA mapping) | This app does not read cells or upload. iOS has no public API for it. |
| A6 (null 5G frequency crash), A15 (far tower), A18 (shared match labels) | No on-device tower matching. |
| A17 (unmeasured signal shown as 0) | No observation markers. |
| A7 (basemap reverts) | The map mode is saved when it is chosen (`MapHelper.setMapMode`); nothing replays it. |
| A8 (Developer Mode flips off) | The chip sets the value directly; it is session-only by design. |
| A9 (timing-advance scale chips) | No timing advance on iOS. No label to mirror. |
| A10 (Driving Mode refuses to start; new message) | Follow GPS is started by hand and does not depend on Coverage on tap. Automatic start is a recorded non-port (2026-08-26). The new Android message has no place here. |
| A11 (menu replay side effects) | Settings are read once at start; there is no menu replay. |
| Back closes sheets on Android 16 | Every sheet is a modal route. See I21 for the one exception. |
| Leaderboard call signs, cell-mapping selection, eNodeB siblings | Features not present. |
| A16 (elevation cross-check in export) | Applies; see I5. |
| A1 | Reported to the owner privately. |

Verified in lockstep: classifier arms and refarming rules (`lib/model/device_detail.dart:253-526`
against `DeviceDetails.java:438-661`); `assets/pathloss/pathloss_v2.json` and
`test/pathloss/test_vectors.json` (same SHA-256 as the Android copies); ads keyword head; Map
Layers chip labels.

## Needs a device or account check

| finding | check |
|---|---|
| I2 | A pin Android draws half-transparent: is it on the iPhone map before any filter is touched? |
| I7 | Pan away, pull Notification Centre down and release. |
| I9 | Report a Problem with and without an Apple Mail account. |
| I11 | App Store Connect upload email; Xcode privacy report. |
| I13 | Flutter UIScene migration page; Apple's date. |
| I18 | TestFlight "Missing Compliance"; location prompt after removing the Always keys. |
| I19 | Territories in App Store Connect and Play. |
| I21 | Android build: Search, then Back. |
| Billing | App Store Connect: is `yearly_adfree_pass` approved, and is `yearly_adfree` removed from sale? |

## What was not audited

Terrain mode and the legacy path-loss classes beyond their wiring; `purchase_helper.dart` beyond
the restore entry point; the web build beyond export; the macOS target; the integration tests.
