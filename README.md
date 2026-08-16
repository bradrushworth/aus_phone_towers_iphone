# Aus Phone Towers (iPhone)

## User Guide

For end users, a full **[User Guide](docs/USER_GUIDE.md)** is available covering the main
features, what the map's colours and symbols mean (tower marker icons, coverage polygons,
and the location dot), the toolbar menu, the navigation-drawer filters and important
behaviours.

The app also links to this guide from the toolbar menu (**⋯ → User Guide**). Because this
repository is public, the link opens the GitHub-rendered page directly.

Have you ever wondered where your nearest mobile phone tower was? What services does it support?
How fast are the 4G Internet speeds in your area? How far does the signal reach? Which is the best phone provider for you?
Is 5G available in your area?

If so, this app is for you!

Updated weekly with the latest tower information from the Australian Communications and Media Authority (ACMA),
this app presents all you ever wanted to know about your local mobile phone towers in a fun and interactive format.

The app includes details of Telstra, Optus, Vodafone, NBN, TPG, TV, pagers, government, CBRS and aviation transmitters!

## Connected tower feature

The Android version can identify which towers your phone is using. This is not available on iOS
because Apple's public APIs do not expose the required cell-tower data.

On Android, `TelephonyManager.getAllCellInfo()` can read the serving and neighbouring cells,
including cell ID, LAC/TAC, MCC/MNC, signal strength, ARFCN and timing advance. The app then looks
those cells up against ACMA / OpenCellID data and shows the connected tower on the map.

On iOS, `CoreTelephony` / `CTTelephonyNetworkInfo` only exposes the carrier name, MCC/MNC,
country code and current radio access technology (e.g. 4G or 5G). It does **not** provide the
connected cell tower ID, signal strength, ARFCN, timing advance or neighbour cell data. Richer
cell data would require private APIs or restricted entitlements that Apple does not allow in
App Store apps.

For that reason, the iOS app shows nearby towers based on your GPS location, but it cannot
currently display the specific tower your phone is connected to.

## Feature comparison with the Android app

The Android app (`au.com.bitbot.phonetowers`) has several features that have not been ported to
iOS. The table below lists each one and whether it can be brought to iOS.

| Android feature | iOS status | Feasible on iOS? |
| --- | --- | --- |
| Connected-cell info bar + tower lookup (`CellIdentity`, `CalculateConnectedTower`) | Not available (CoreTelephony only exposes carrier / MCC-MNC / radio type) | No |
| Crowd-sourced cell observation upload (`PostObservedLocation`, OpenCellID) | Not available | Partial (GPS-only, no auto cell detection) |
| Export towers / coverage as GeoJSON, CSV or KML (`ExportHelper`) | Available (GeoJSON / CSV / KMZ) | Yes (GeoJSON / CSV / KML) |
| User ranking / gamification (`GetUserRanking`) | Not available | Yes (pure API) |
| Mozilla Location Service geolocation (`PostMlsGeolocate`) | Not available | Yes (network only) |
| Follow-GPS map centring + heading rotation (`RotationVectorSensorEventListener`) | TODO in code | Yes (sensors plugin) |
| Tower / contact list views (`ListsActivity`) | Not available (map only) | Yes |
| Link-speed estimate (`LinkSpeedEstimator`) | Not available | No (Android-only API) |
| Background tower service + notifications (`TowerService`) | Not available | No (iOS background limits) |
| Coverage polygons (`PolygonHelper`, `GetLicenceHRP`) | Available | Yes (see note below) |
| In-app purchases — Remove Ads (1 year / permanent) & Donations | Available (Google Play) | Yes (App Store) |

### In-app purchases

Both apps use the platform store for entitlements:

- **Remove Ads — 1 Year**: a non-consumable purchase that grants ad-free for 365 days. It is
  restored automatically on launch (via `restorePurchases()`); after 12 months it expires, ads
  return, and the user may buy it again.
- **Remove Ads — Permanent**: a non-consumable purchase that removes ads forever and is restored
  on every launch.
- **Donations** (small / medium / large): one-off consumable purchases that support development.
  They are repeatable and do **not** remove ads.

A banner advertisement is shown to non-subscribed users only after an ad has actually loaded; the
"Advertisement" label is hidden until then (and whenever ads are not shown).

### Signal-propagation math consistency

The coverage-polygon math was checked against the Android implementation and is now consistent:

- Both apps use the same Okumura-Hata / COST-231-Hata path-loss model (`calculateDistance`), the
  same terrain-loss (`calculateTerrainLosses`), the same spherical `travel` destination-point
  formula, and the same ring generation (`BEARING_START = 1.25`, `BEARING_INCREMENT = 2.5`,
  10 m tower-height floor, 100 km distance cap).
- **Fix applied:** the iOS app previously hard-coded the radiation model to `SUBURBAN` for every
  polygon. It now reads the per-device radiation model (`device.getRadiationModel()`) exactly as
  Android does, so METRO / URBAN / OPEN etc. sites draw with the correct path loss.
- Polygon border styling was aligned to match Android (`lineAlpha = 30 + alpha`, `strokeWidth = 6`).
- Visual text overlays (frequency / network-technology labels on each coverage ring) are now drawn
  on iOS using a small centroid marker per polygon. They are a cosmetic aid only and do not affect
  the propagation calculation.

### Path loss algorithm (learned coefficients)

The path-loss model has been ported from the Java Android app to this Flutter app. The algorithm
estimates the distance a radio signal travels given a measured path-loss in dB, using learned
coefficients fetched from the REST API at
`https://api.bitbot.com.au/api/towers/pathloss_coefficients/`.

**How it works:**

1. On app startup, `PathLossModelProvider` fetches trained coefficients from the REST API (the
   Java Android app trains these server-side from crowd-sourced signal observations and writes
   them to the MySQL `pathloss_coefficients` table).
2. The learned model (`LearnedPathLossModel`) uses one of three functional forms:
   - **log-distance** (legacy): `level = b0 + b1·log10(d) + b2·log10(f) + b3·log10(h)`
   - **hata-correction**: `level = hataIntercept + b0 + b1·hataSlope·log10(d)`
   - **hata-calibration** (current): `log10(d) = b0 + b1·log10(hataDistance)`
3. Coefficients are looked up by composite key (telco MNC + network type + frequency band + city
   density), falling back to density-only, then to the analytic Hata/COST-231 model if no trained
   coefficients exist.
4. For 5G NR, the 3GPP TR 38.901 model is used as the anchor instead of Hata.
5. If the REST fetch fails or hasn't completed yet, the analytic model is used — the app behaves
   exactly as before until training data is available.

This means the iPhone app now draws the same polygon shapes and distances as the Android app,
using the same trained coefficients. See `AGENTS.md` for full architecture details.

Some relevant links:

* [This repository](https://github.com/bradrushworth/aus_phone_towers_iphone)
* [Apple App Store listing](https://apps.apple.com/au/app/aus-phone-towers-3g-4g-5g/id1488594332)
* [Sister app written in native Java code](https://play.google.com/store/apps/details?id=au.com.bitbot.phonetowers&hl=en_AU&gl=US)
  This code is not yet open-sourced but will be soon.

Pull requests are very welcome!

## Getting Started

Here are some random commands:

```
flutter clean
flutter pub get
flutter run
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/better_test.dart
```

I've been testing the app on Windows/Android Studio using the Android version and an Android
simulator.

This is primarily a iOS app, so you might require XCode from time to time. I use CodeMagic as my build
pipeline and they allow you to VNC (or SSH) into your build machine for 20 minutes. I've been pretty
much able to avoid using XCode at all, other than to enrol the app with the Apple App Store.
I don't claim to be an expert with Apple, but I think using CodeMagic I can avoid needing access to
XCode mostly, since it only runs on a Mac. There are Mac cloud providers though relatively cheap.

## Web Version

If you encounter issues with Chrome complaining about CORS while you are testing, the following
solution fixed my issue. This should no longer be relevant because I allow http://localhost in my
CORS configuration now.

[How to solve flutter web api cors error only with dart code?](https://stackoverflow.com/questions/65630743/how-to-solve-flutter-web-api-cors-error-only-with-dart-code)

[flutter_cors](https://pub.dev/packages/flutter_cors)

```
dart pub global activate flutter_cors
fluttercors disable
fluttercors enable
```
