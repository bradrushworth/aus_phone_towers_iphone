# Changelog

All notable changes to the Australian Phone Towers iPhone (Flutter) app are documented in this
file. The format is based on [Keep a Changelog](https://keepachangelog.com/). Versions are
`versionName+versionBuild` (`build-name`+`build-number` in `pubspec.yaml`, matching
`CFBundleShortVersionString`+`CFBundleVersion` on iOS and `versionName`+`versionCode` on Android).
See the sibling [`aus_phone_towers_java`](https://github.com/bradrushworth/aus_phone_towers_java)
repo's own `CHANGELOG.md` for the Android app's parallel history — the two apps share most
features and bugs are frequently fixed in both.

## [1.13.8+123] — 2026-08-20

### Fixed
- **Phantom/duplicate 5G rows on some towers** — `getNetworkTypeStatic` still had the Java app's
  now-removed hardcoded `antenna_id` override sets (`antennas3G4G`, `antennas3G4G5G`, `antennas4G`,
  `antennas4G5G`, `antennas5G`, `antennas3G5G`), which forced `LTE`/`NR` regardless of the real
  carrier. Confirmed live (debug build 1.13.6, Pixel 8 Pro): the Lyneham Vodafone CMTS site showed
  both a "4G 873 MHz" and a spurious "5G 873 MHz" row for the same carrier, with the sub-1-GHz "5G"
  claiming 935 Mbps — because antenna 13198 was hardcoded into both `antennas4G` and
  `antennas4G5G`. The sets are deleted; classification is now derived purely from
  `(emission, frequency, bandwidth, telco)` via a per-telco frequency table ported line-for-line
  from the Java Android app's `DeviceDetails.networkTypesForEmission` (dual `[LTE, NR]` for Optus
  n1 2100 MHz `'D'`, Vodafone n28 700 MHz `'D'`, and Telstra `"14M9G7W"` 700/850 MHz `'D'`; NR-only
  for 3.3–3.8 GHz `'W'`; TD-LTE-only for B40 2300–2400 MHz `'W'`).
- **While porting, found and fixed the same Telstra `"14M9G7W"` dead-code bug in the Java app**
  (its dual-tech check lived in the wrong `switch` arm and could never run — see the Java app's
  `CHANGELOG.md` v7.7.20) and ported the fix here too.

### Added
- `test/network_type_classification_test.dart` and `test/christmas_island_classification_test.dart`,
  mirroring the Java app's `DeviceDetailsTest` licence tests and `ChristmasIslandClassificationTest`,
  so the two apps' classifiers can no longer silently drift apart.

## [1.13.7+122] — 2026-08-20

### Changed
- **Default Signal Strength changed from Strong to Good** — the ring drawn on first launch (and
  whenever no stored preference exists) now defaults to the "Good" signal-strength band instead of
  "Strong". Fixed in the one place that actually governs this at runtime
  (`SharedPreferencesHelper.getSignalStrength`'s fallback), plus the two dead-but-misleading static
  field initializers that get overwritten by it on startup (`PolygonHelper.polygonSignalStrengthPos`
  previously defaulted to Strong, `NavigationMenu.signalStrengthSelection` previously defaulted to
  Weak — the two disagreed with each other and with the real runtime default). `docs/USER_GUIDE.md`
  updated to match.

## [1.13.6+121] — 2026-08-20

### Fixed
- **"ACMA Website" link opened the wrong page** — ACMA retired the old RRL lookup URL
  (`web.acma.gov.au/rrl/site_search.site_lookup?pSITE_ID=...`) on 2026-06-29. It now 302-redirects
  to a new React SPA landing page (`acma.gov.au/register-radiocommunication-licences-rrl`), but
  since that SPA routes client-side via `HashRouter`, the `pSITE_ID` query string was silently
  dropped on redirect — every tap landed on the generic RRL info page instead of the tapped
  tower's record. Verified against the live `backend.acma.gov.au/rrl/v1/Sites/{id}` API that the
  numeric site ID scheme is unchanged and the SPA's `/sites/:id` route fetches `Sites/{id}`
  directly, so `launchURL()` now points at `.../register-radiocommunication-licences-rrl#/sites/$siteId`.
  Same fix applied to the Java Android app.

## [1.13.5+120] — 2026-08-20

### Fixed
- **Rate App did nothing on TestFlight** — `requestReview()`'s `isAvailable()` gate only reports
  whether the StoreKit API exists, not whether the native prompt will actually appear. Apple
  silently disables the prompt entirely outside a real App Store install (TestFlight, sandbox,
  debug builds), so tapping Rate App did nothing for testers. It now always also opens the App
  Store listing directly as a guaranteed fallback, alongside the best-effort native prompt
  attempt.
- **Close App shown where it can't work** — hidden from the menu on iOS/Web instead of showing an
  "unavailable" message, since neither platform permits an app to exit itself. The item is only
  relevant on Android.

## [1.13.4+119] — 2026-08-20

### Fixed
- **Coverage labels floating away from their polygon** — labels were anchored 300 m outside the
  outer ring, leaving them clear of the shaded polygon. The outward nudge is now 30 m, so the
  label sits right on the polygon's outer line instead of drifting away from it.

## [1.13.3+118] — 2026-08-20

### Fixed
- **Right-hand menu submenu selections silently ignored** — `showSingleRowOptionMenu()` never
  returned the item the user tapped (a missing `return` left the function's untyped `Future`
  implicitly resolving to `null` on every call). Every caller does `if (chosen == null) return;`,
  so this silently no-op'd every selection in the second-level popups it powers: Rotating Map,
  Hiding Menu (hide radiation / disable refarm / multi-tower coverage), Export Data, Polygon
  Precision, and the Problems Menu. Donate/Remove Ads were unaffected since their handling lives
  earlier in the same function.
- Hardened `showRadioOptionMenu()` (Map Mode): it force-unwrapped the `showMenu()` result, which
  threw if the menu was dismissed without a selection (tap outside/back) instead of returning.

## [1.13.2+117] — 2026-08-20

### Fixed
- **Lock Map didn't actually lock the map** — toggling it from the right-hand menu flipped the
  static flag and rebuilt only the `OptionsMenu` widget, not `MapBodyState` — so the `GoogleMap`'s
  gesture-enabled flags (which read `MapBodyState.lockMap` at build time) never picked up the
  change until something else happened to rebuild the map. Now also rebuilds `MapBodyState` via
  its `currentInstance`, matching how Follow GPS and Rotating Map already do it.

## [1.13.1+116] — 2026-08-20

### Changed
- **Live store pricing for Remove Ads / Donate / Support the App** — menu and screen labels for
  all five in-app-purchase products (donation small/medium/large, remove-ads yearly/permanent)
  previously showed a hardcoded `$X.XX` price baked into `Strings`. Store prices vary by
  storefront/locale and can change without an app update, so these now show the store's own
  localized `ProductDetails.price` via a new `PriceLabelHelper` (pure, unit-tested) and
  `PurchaseHelper.priceFor`/`priceLabel` wrappers. The hardcoded strings remain only as the
  fallback shown before the store query resolves (or if it fails). `_getProducts()` now also
  calls `notifyListeners()` once products load, so already-open `Consumer<PurchaseHelper>` UI
  (e.g. `SupportPromptScreen`) picks up live pricing without waiting for an unrelated purchase
  event.

## [1.13.0+115] — 2026-08-19

### Added
- **"Support the App" prompt**, ported from the Java app's `SupportPromptActivity`: a full-screen
  prompt with the cost-transparency message, the three donation buttons, and (unless already
  ad-free) the two ad-free purchase buttons, plus a "Maybe later" dismiss button. Reachable as the
  last item of the Donate submenu and shown automatically about once a week via a ported, pure,
  unit-tested decision function (`SupportPromptHelper.decide`). The Java screen's "Watch an ad
  instead" rewarded-ad button was deliberately not ported — no rewarded/interstitial ad unit is
  configured in this app (banner ads only).
- Top-level option menu reordered to match the Java app's `popup_menu.xml` for every item shared
  between platforms: Reload Everything, Follow GPS, Hide Borders, Search Sites, Map Mode, Rotating
  Map, Hiding Menu, Export Data, Remove Ads, Donate, Problems Menu, Rate App, Close App. The two
  iOS-only items (Lock Map, Polygon Precision) sit next to their closest thematic neighbour rather
  than breaking that shared sequence.

## [1.12.2+114] — 2026-08-19

### Fixed
- **Polygon Precision setting had no effect on real towers** — the Low/Medium/High menu only ever
  changed `PolygonHelper.createBasicPolygon`, the circular fallback estimate used when a device
  has no registration identifier. The primary ring-drawing path for real towers with licence data,
  `GetLicenceHRP.getLicenceHRPData`, hardcoded a server-row sampling step of 2 and never looked at
  the setting — so for the vast majority of towers, changing precision visibly did nothing.
  `GetLicenceHRP.rowStepForBearingIncrement` (a pure, unit-tested function) now scales the
  row-sampling step from `PolygonHelper.polygonBearingIncrement`, preserving exact prior behaviour
  at Medium.

## [1.12.1+113] — 2026-08-19

### Fixed
- **Ads not displaying** — inline adaptive banners request an `AdSize` that always reports height
  0 by design; the loaded-ad container sized itself from that placeholder instead of the real
  rendered size, so a successfully loaded banner never became visible. `AdsHelper` now fetches the
  actual size via `BannerAd.getPlatformAdSize()` after load, with the sizing logic extracted into
  a testable `AdBannerContainer` widget.
- **iOS ad-free purchases not recognised** — `entitlement_evaluator` parsed
  `PurchaseDetails.transactionDate` with `int.tryParse` only, assuming epoch milliseconds. Older
  `in_app_purchase_storekit` StoreKit2 builds reported a local-time `"yyyy-MM-dd HH:mm:ss"` string
  instead, so `yearly_adfree` purchases were silently never recognised as active on iOS. Now
  parses both formats (the upstream plugin bump also fixes this at the source).

## [1.12.0+112] — 2026-08-19

### Added
- **Rotating Map** (Travel Direction / Phone Orientation / Disable Rotation), matching the Android
  app's Rotating Map submenu.
- **Multi-Tower Coverage** toggle: accumulate multiple towers' polygons instead of clearing on
  each tap.
- **Lock Map**: freeze all camera movement for screenshotting.
- Increased coverage polygon visibility on all map types.

### Fixed
- Camera position now correctly persists and restores across app backgrounding/cold restart.
- Polygon download race condition that required "wiggling the map to recover".
- 5G filter bypass when re-enabling a hidden telco.
- `CityDensity` thresholds now match the Android app's calibrated values, correcting
  propagation-distance estimates.

## [1.11.6+111] — 2026-08-19

### Added
- Ported Android features: menu regroup (enum-based option-menu items so labels always match
  behaviour — this also fixed a broken "User Guide" label/action mismatch), frequency-refarming
  classification (`DeviceDetails.refarmEnabled` + `getNetworkTypeForLicence`, with a "Disable
  frequency refarming" toggle in the Hiding Menu), Polygon Precision control (Low/Med/High),
  Follow GPS "drive mode" toggle, and Export Towers (GeoJSON/CSV) alongside Export Coverage.

### Fixed
- Coverage frequency/technology labels now anchor to the point on the outer signal-strength ring
  furthest from the tower (instead of a random ring point), then push further outward into clear
  space — stopping labels from bunching around the site marker or sitting on the shaded fill.

## [1.11.5+110] — 2026-08-16

### Added
- **Path loss algorithm ported from the Java Android app**: estimates distance from signal
  path-loss using learned coefficients fetched from the REST API
  (`/api/towers/pathloss_coefficients/`), with analytic Hata/COST-231 and 3GPP TR 38.901 models as
  fallbacks. Makes the iPhone app draw the same polygon shapes and distances as the Android app.
  New `lib/pathloss/` module (analytic, learned, and 3GPP NR models, coefficient container,
  composite key lookup, provider), wired into `get_licenceHRP.dart` / `polygon_helper.dart` /
  `main.dart`, with 26 unit tests ported from the Java test suite.

## [1.11.4+109] — 2026-08-09

### Changed
- Default Signal Strength setting changed to Strong.
- Furthest-ring coverage labels randomised (were previously deterministic/repetitive) and removed
  when polygons are hidden.

## [1.11.1–1.11.3+105–108] — 2026-08-08 to 2026-08-09

### Added
- Coverage export as GeoJSON, CSV and KML, and signal-ring frequency/technology text labels.
- Purchase/subscription entitlement unit test plus a pure `evaluateEntitlements` evaluator.

### Fixed
- Ads/ad-free purchase flow; the "Advertisement" disclosure label is now hidden until the ad has
  actually loaded.
- Restored an accidentally-deleted `initiatePurchase` that had broken the app's compile in
  `option_menu.dart`.

## [1.10.0+103] — 2026-08-06

### Added
- **In-app User Guide**: `docs/USER_GUIDE.md` (+ rendered `docs/user-guide.html`) covering the
  main features, the colour/symbol legend, the toolbar menu, navigation-drawer filters, important
  behaviours and Android-vs-iPhone differences, linked from a new top-level "User Guide" menu item.

## [1.9.0–1.9.4+98–102] — 2026-07-13 to 2026-07-26

### Changed
- Upgraded multiple dependencies: `google_maps_flutter`, `dio`, `firebase`, `google_mobile_ads`,
  `in_app_purchase`. Migrated deprecated `withOpacity` calls to `withValues(alpha: ...)` and
  `launch` to `launchUrl`.
- Expanded `Info.plist` usage descriptions for location, motion and user-tracking permissions with
  more detailed examples of how the data is used.

### Fixed
- Apple purchase workflow and ad configuration issues.
- `location` dependency upgrade to `^10.0.1` reverted back to `^8.0.1` — the newer version was
  incompatible with the AGP 9 Kotlin plugin on the Android side of this Flutter app.

## [1.8.0–1.8.38+59–97] — 2025-09-13 to 2026-03-17

A long, fast-moving patch series (~39 releases) modernising the app's Android Gradle Plugin/Kotlin
toolchain and iterating heavily on ads and billing polish. Highlights:

### Added
- "Restore Purchases" option in the Remove Ads menu, backed by a new public method on
  `PurchaseHelper`.

### Changed
- Android Gradle Plugin and Gradle wrapper upgraded (8.13.0 / 8.14.3), Kotlin/Java toolchain moved
  to 21, Firebase BoM upgraded.
- "One Year Ad Free" price updated from $14.99 to $9.99.
- Numerous small ads/billing/UI fixes across this series as the two apps' billing flows were
  brought into closer alignment (see individual commit history for the full list —
  `git log --grep="^Release " -i` — this range condenses ~39 point releases with build numbers
  60–97).

## [1.7.0+58] — 2025-01-06

### Changed
- Dependency modernisation pass.

## [1.6.0–1.6.5+52–57] — 2023-06-18 to 2024-06-16

### Changed
- **Major Flutter SDK upgrade** (`sdk: '>=2.19.6 <3.0.0'`), bringing the app up to speed with the
  Android project's feature set.
- `CityDensity` reworked to behave like the Android app: a filter rather than a single choice, and
  surfaced in the site popup.
- Major dependency updates and a full code reformat.

### Fixed
- Google Ads crash caused by a missing `NSUserTrackingUsageDescription` permission string.

## [1.5.0–1.5.3+48–51] — 2022-06-26 to 2023-03-05

### Added
- Ads enabled on iOS (previously Android-only).

### Changed
- Dependency updates (`google_mobile_ads`, `in_app_review`, `url_launcher` and its iOS variant,
  Firebase Analytics/Crashlytics, minimum iOS deployment target raised to 10.0).
- Updated 3G/4G/5G network information and pricing.

## [1.3.2–1.4.10+35–47] — 2022-01-11 to 2022-02-13

The initial push to bring the iPhone/Flutter app's feature set up to parity with the Android app,
plus first-time platform support work.

### Added
- **Flutter Web support** (experimental).
- Links menu item.
- iOS App Tracking Transparency (ATT) prompt.
- Integration tests (`flutter_driver`) and unit tests ported from the Java app.

### Fixed
- Popup text visuals and site popup widget layout, iterated across several point releases.
- Terrain awareness bug; iOS app icons; web map movement and search.

## [1.0.0+1] — 2021-05-24

Initial commit — the first Flutter port of the Android app, targeting iOS as the primary platform
with Android as a secondary target.
