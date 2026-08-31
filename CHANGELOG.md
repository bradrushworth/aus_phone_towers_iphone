# Changelog

All notable changes to the Australian Phone Towers iPhone (Flutter) app are documented in this
file. The format is based on [Keep a Changelog](https://keepachangelog.com/). Versions are
`versionName+versionBuild` (`build-name`+`build-number` in `pubspec.yaml`, matching
`CFBundleShortVersionString`+`CFBundleVersion` on iOS and `versionName`+`versionCode` on Android).
See the sibling [`aus_phone_towers_java`](https://github.com/bradrushworth/aus_phone_towers_java)
repo's own `CHANGELOG.md` for the Android app's parallel history — the two apps share most
features and bugs are frequently fixed in both.

## [1.14.15+150] — 2026-08-31

### Fixed
- **With Calculate Terrain on, every signal-strength contour drew at the same radius** (GitHub
  issue #56, reported against the Android app and fixed there in 7.7.51; this app carries the
  same ported code). An obstructed bearing was walked down a fixed ladder of sample distances
  until the path was clear, and that ladder takes no account of the signal level — so Maximum,
  Strong, Good and Weak all snapped onto the same rung wherever terrain blocked the path, which
  in hilly country is most bearings. Coverage also stopped dead at the first ridge with no
  diffraction allowance, drawing far less range than users measure in the field. Terrain is now
  charged to the link budget as knife-edge diffraction loss (ITU-R P.526) and the distance
  re-solved through the trained path-loss model, so a weaker threshold still reaches further
  after paying the same terrain penalty, and signals carry past a ridge instead of stopping at
  it.

  The Android app's other issue #56 fix — the hypothetical-location pin surviving Refresh Data
  as a dead handle — does not apply here: this app has no long-press hypothetical-location pin.

## [1.14.14+149] — 2026-08-31

### Fixed
- **iOS tower pin icons rendering cut off / corrupted** (GitHub issue #58). The Google Maps iOS
  SDK keeps every registered marker icon in a single texture atlas and corrupts already-rendered
  icons once too many distinct icon images accumulate (upstream flutter/flutter#172909); since
  `SiteHelper.globalListMapOverlay` keeps every tower ever downloaded and is never pruned, the
  app was handing the platform map view an unbounded and ever-growing marker set. The markers
  passed to the map are now capped to those near the current viewport
  (`selectMarkersForViewport`, `lib/helpers/marker_viewport.dart`), with the marker set refreshed
  shortly after the camera stops moving so the cap keeps following the viewport while panning.
- **Pinned the native Google Maps iOS SDK to 9.x** via `google_maps_flutter_ios_sdk9` (the
  default `google_maps_flutter_ios` package leaves the pod constraint open up to `< 11.0`, and
  with `ios/Podfile.lock` untracked every CI build silently resolved the newest 10.x). The pin
  keeps builds reproducible on the iOS 15 deployment floor and steps the SDK back from the 10.x
  line the corrupted-pin reports (issue #58) arrived on; upgrading deliberately to
  `google_maps_flutter_ios_sdk10`+ is tracked as its own bead (requires an iOS 16 floor).

## [1.14.13+148] — 2026-08-30

### Fixed
- **Paying users no longer see ads at cold start or after a silent restore** (GitHub issue #56).
  The ad-free entitlement is now cached locally (`EntitlementCache`) and seeded before the store
  responds, the "Restore purchases" menu item reports its outcome (restored / no purchase found /
  failure) instead of doing nothing visible, and a null `purchaseID` on a restored transaction no
  longer aborts delivery of the entitlement. The store evaluation always overwrites the cached
  seed, so refunds and yearly expiry still re-show ads.

## [1.14.12+147] — 2026-08-30

### Changed
- **Removed the draw-time density monotonicity clamp from the learned path-loss model**
  (mirrors the Android 7.7.49 change, GitHub issue #49). The OPEN ≥ SUBURBAN ≥ URBAN ≥ METRO
  coverage-size ordering is now enforced entirely server-side, by the Java trainer refusing to
  publish a coefficient group that predicts less range than a denser neighbour
  (`PathLossTrainerIT.enforceDensityMonotonicity`). Clamping on the handset papered over
  inconsistent published groups, hiding which trained group produced a bad number and making
  field reports undiagnosable — the app now draws exactly what the published
  `pathloss_coefficients` table says.

## [1.14.11+146] — 2026-08-30

### Fixed
- **Tapping a tower a second time hides its coverage again** (GitHub issue #55). Every tap
  cleared and then unconditionally redrew the tapped site, so toggle-off never stuck; and the
  polygon-removal step cleared every site's polygons instead of just the tapped one, so with
  Multi-Tower Coverage on a site could never be individually dismissed.
- **Directional sites no longer draw a full omnidirectional disc** (GitHub issue #55). When a
  tower's licence_hrp rows spanned more than one page, the "found real data" flag was lost at
  the page boundary, so the real directional lobes were discarded in favour of the circular
  estimate. The flag now carries across pagination, and a failed fetch draws nothing rather
  than masquerading as omnidirectional coverage.
- **Optus 900 MHz towers display as 4G, not 5G** (GitHub issue #55). The block classifies as a
  dual 4G/5G carrier, but the 5G half is live-verified only in metro areas while LTE B8 is
  universally on-air — a rural tower on this block was showing "5G" it does not have. The
  display pick now prefers 4G for this band; the shared classifier still reports the full dual
  list. Mirrored in the Java Android app the same day (its DeviceDetails), per the lockstep rule.

### Added
- **Problem-report emails carry device metadata in the subject** — "Aus Phone Towers Problem
  Report: <model>, <deviceId>, v<version>+<build>", matching the Android app, so a report can be
  told apart from every other report and correlated with its sender's device.
## [1.14.10+145] — 2026-08-27

### Fixed
- **Suburban coverage polygons could be smaller than urban ones for the same signal, the wrong
  way round.** Each density's learned calibration offset is regressed independently from that
  density's own samples, and the table is sparse enough that neighbouring densities often land on
  different fallback tiers. Nothing tied those offsets together, so a suburban site could end up
  with a markedly smaller predicted range than a nearby urban one, inverting the
  open > suburban > urban > metro ordering the underlying physics already guarantees. The
  predicted range for a given density is now never allowed to fall below the next denser
  neighbour's, whichever fallback tier either landed in. Scoped to non-NR network types: the
  guarantee this leans on is Hata's, and the 3GPP 38.901 model NR falls back to when untrained
  does not carry it (METRO and URBAN use genuinely different, non-monotonic curves) — ported to
  this app alongside the equivalent Android fix in `aus_phone_towers_java` 7.7.46/7.7.48.

## [1.14.9+144] — 2026-08-27

### Fixed
- **This is the build that actually ships the site-details table fix.** 1.14.9+143 only added a
  test dependency and never touched pubspec.yaml's version line again after it, so the table
  layout fix, the screenshot-pipeline fixes, and everything else committed since stayed on `main`
  without ever being built or deployed — the release pipeline is deliberately gated on a version
  bump (`when.changeset: [pubspec.yaml]`), and nothing after 143 provided one. The live site was
  running 143's code the whole time, not a stale cache of it.

## [1.14.9+143] — 2026-08-26

### Changed
- **No user-facing change.** This release exists only because the build pipeline is gated on
  `pubspec.yaml`, and the store-screenshot harness needed a dependency declared there. Shipping a
  build was the side effect, not the goal — 1.14.8 (142) is the version in App Store review.

### Fixed (developer tooling)
- **The screenshot workflow could publish App Store images at a size Apple rejects.** It booted
  whichever iPhone simulator `simctl` happened to list last, on the assumption that the list is
  ordered newest-last. It is not ordered by screen size at all, so a run could capture perfectly
  good screenshots on a 6.1" or 6.3" device and still report success, because nothing downstream
  ever looked at the pixels. It now picks by size class (Pro Max, else Plus, else any iPhone) and
  a new step measures every PNG with `sips`, failing the build unless it is a 6.9" App Store size.
- **The screenshot run could photograph the wrong thing and pass.** It slept for a fixed 12
  seconds after launching the app. On a slow cold start that captured the integration-test
  placeholder rather than the map. It now waits for a `MaterialApp` to actually paint, and
  asserts it did.
- **An empty map could be captured and shipped.** Every screenshot here is of a map, and a map
  that renders but downloads nothing is a plausible-looking blank picture that survives every
  other check — the widget tree is perfectly healthy either way. The run now waits for towers to
  arrive and fails if none do.
- **`flutter_driver` was never declared as a dependency**, so the driver the workflow loads could
  not have compiled.
- **The app never started at all on the screenshot simulator.** `main()` awaits the App Tracking
  Transparency prompt on iOS. That is a system modal whose future does not complete until a human
  taps it, and on CI nobody ever will — so `runApp()` was never reached and the app rendered
  nothing. No crash, no exception, just a blank run that the old harness would have photographed
  and published. The prompt is now skipped under `--dart-define=SCREENSHOT_MODE=true`, which is set
  only by that workflow and has no effect on any released build.

## [1.14.8+142] — 2026-08-26

### Fixed
- **Two carriers no longer disagree about the same street corner.** Coverage size depends on how
  built-up an area is, and the app worked that out by counting how many towers *one carrier* had
  nearby. Telstra operates far more towers than Vodafone almost everywhere, so the same place was
  treated as a dense city for one carrier and an outer suburb for another — and the answer could
  change as you panned the map. Measured across Australia: of 4,838 areas carrying two or more
  carriers, **498 (10.3%) had carriers disagreeing**. That is the cause of reports that one
  carrier's coverage looked far too small next to another's at the same site.

  There is now a single published figure for every location, identical for every carrier and shared
  with the Android app. **You will see coverage shapes change size** — that is the fix, not a
  regression.

### Changed
- Coverage areas with no tower data at all are treated as open country, which is what they are.

## [1.14.7+141] — 2026-08-25

### Fixed
- **The app title could be cut off on a narrow screen.** "Aus Phone Towers" now shrinks to fit the
  space left beside the search and menu buttons instead of clipping.

### Changed
- **Larger text in the cell-information row along the bottom of the map**, which is the one part of
  the app that has to be readable at a glance while driving.
- **The app version is now shown in Settings → Help**, so you can tell which build you are running.
  Tap it to copy it, ready to paste into a problem report.
- **"Rate the app" is now on the Support the App page** as well as in settings. It costs nothing and
  helps more than a small donation does.

## [1.14.6+140] — 2026-08-25

### Fixed
- **Omnidirectional towers were drawn far too small on iOS and web** — a licence with no azimuth
  was being read as azimuth 0 rather than "no azimuth", which is what marks an antenna as
  omnidirectional. That made the omni branch of the power calculation unreachable: the +13.5 dB
  omni calibration never applied, and every genuine omni was instead treated as a directional
  antenna pointed due north, with front-to-back loss subtracted behind it. Android was never
  affected, which is why the same site could look very different on the two apps.
- **Tower heights with a decimal point silently became 10 m** — ACMA publishes heights like
  "20.41", which the integer parser rejected outright; the height then fell to 0 and was floored
  at 10 m, shifting both the intercept and the slope of the path-loss estimate.
- **A tower's coverage could be dropped entirely because its antenna details had not arrived yet**
  — the antenna record is fetched in the background, and reading it before it landed threw rather
  than falling back, abandoning that transmitter's polygon. It now behaves as the Android app does
  and simply contributes no directional gain until the record arrives.
- **Coverage fell back to raw textbook path loss in some areas** — where no learned coefficients
  existed for a carrier at a given density, the model dropped to uncalibrated Hata. It now borrows
  the nearest calibrated density instead, which mostly closes the size gap that made one carrier's
  coverage look several times larger than another's at the same site.
- **Dark mode was wrong at the top and bottom of the screen** — the iPhone status bar and the ad
  strip stayed light while the rest of the app went dark.
- **The filter drawer was a narrow sliver on the web** — it was a fixed phone-width column against
  a full desktop browser window, and now scales with the viewport.

### Changed
- **Telstra and Vodafone brand colours corrected** against each brand's published guidelines —
  Telstra is Blue Ribbon #0D54FF and Vodafone is #E60000 (Pantone 485), kept in lockstep with the
  Android app. Optus deliberately stays teal: their brand primary is a yellow that all but
  disappears on a light terrain basemap.
- **New app icon** across iOS, Android and the web, including maskable web icons.
- The "this app is in development" dialog no longer appears at startup.

## [1.13.18+133] — 2026-08-24

### Changed
- **Android now uses its own Android-restricted elevation key** — new
  `terrainAwarenessKeyAndroid` secret, provisioned in the Cloud console (Maps Elevation API
  only, restricted to Android apps with the row `au.com.bitbot.phonetowers.flutter` /
  `54:EF:0F:58:CE:4D:E3:9A:1C:29:53:8E:E7:95:E1:DE:92:BF:D1:78`). The Android build proves
  that identity via `X-Android-Package`/`X-Android-Cert` instead of the interim site-Referer
  arrangement on the legacy key (live-verified: denied bare, serves elevations with the
  header pair). Mobile builds no longer depend on the exposed legacy key — the last consumer
  is the web build, pending its server-side arrangement or acceptance of the
  websites-restricted + quota-capped steady state.

## [1.13.17+132] — 2026-08-24

### Fixed
- **Terrain awareness now survives the Maps key lockdown, and failures are loud** — sister
  change to the Java app (problem report 2026-08-23, Tasmania). The Google Elevation web
  service reports failures such as `REQUEST_DENIED` as an HTTP **200** with an empty
  `results` array; `GetElevation` looped over the zero rows "successfully" — and only set
  `finishedDownloadingElevations` inside that loop, so an empty response also left the
  licence-HRP wait loop spinning forever. Now:
  - Each platform uses the key whose restriction it can satisfy, and proves the identity
    that restriction checks: **iOS** uses the new iOS-restricted key
    (`terrainAwarenessKeyIos`) with the `X-Ios-Bundle-Identifier` header; **Android** sends
    the `Referer` the legacy key is now Websites-restricted to (interim until
    `au.com.bitbot.phonetowers.flutter` gets its own Android-restricted key); **web** relies
    on the browser's own Referer, which the api.bitbot.com.au CORS proxy must forward.
  - A non-OK status (or no response) is logged and surfaced once per session as a "Terrain
    data is unavailable — drawing coverage without terrain" snackbar, the response is no
    longer force-unwrapped, and the finished flag is always released so polygons can never
    hang waiting for elevations. Pinned by `get_elevation_test.dart`.

## [1.13.16+131] — 2026-08-23

### Fixed
- **Ads could stay on screen after buying (or restoring) Remove Ads** — the banner region in
  `MapBody` read `PurchaseHelper().isSubscribed` once per build without listening for changes.
  At cold start the ad usually finishes loading before `restorePurchases()` delivers a paid
  user's entitlement, so the ad rendered first — and when the entitlement then arrived, nothing
  rebuilt the banner subtree; the ad strip stayed visible until some unrelated rebuild touched
  the map UI. The region is now `EntitlementGatedAdBanner`
  (`lib/ui/widgets/entitlement_gated_ad_banner.dart`), a `Consumer<PurchaseHelper>` that hides
  the moment the entitlement lands and re-shows if a yearly entitlement lapses mid-session.
  Covered by `test/ui/widgets/entitlement_gated_ad_banner_test.dart`.
- **Real (licence_hrp) coverage polygons drew several times too large** — the HRP polygon
  loop used the density-only `calculateDistance` overload, but since the 2026-08-22 trainer
  re-baseline the server publishes ONLY composite (`density|mnc|networkType|band`)
  coefficient groups, so the lookup found nothing and silently fell back to raw analytic
  Okumura–Hata: ~3.8× too far for a 778 MHz LTE cell, 12×+ for 3.5 GHz NR (which also
  missed the 3GPP 38.901 anchor — only the composite path routes NR there). Tapped-tower
  polygons now use the same trained composite calibration as the estimated (basic) polygons
  and the connected-tower mapping path. Sister change to `aus_phone_towers_java`.

## [1.13.15+130] — 2026-08-23

### Fixed
- **Towers whose licence has NO `licence_hrp` rows silently drew no coverage polygon at all** —
  the zero-rows early return skipped the `createBasicPolygon` fallback entirely (surfaced by
  the 2026-08-22 `cell_mapping` re-baseline selecting such devices). An empty result now flows
  through to the estimated pattern, exactly like a missing registration identifier. Mirrors
  the Java app.
- **Omnidirectional simple polygons rendered ~2.4× too small** — the shared −41.7 dB constant
  was calibrated for directional antennas (which also add gain − 2.15); the omni branch
  measured 13.5 dB below its real `licence_hrp` levels (17 omni devices / 6,120 HRP rows).
  New `omniCalibrationDb` (+13.5) centres it. Mirrors the Java app.

## [1.13.14+129] — 2026-08-23

### Fixed
- **Tapping any pin in a fanned-out cluster always selected the Telstra one** — markers
  hit-test on the whole icon bitmap (transparent pixels included), and the rotated icons were
  drawn centred on identical swept-circle squares, so every co-located telco's tap target was
  the same rectangle and the top of the stack won every tap. The rotated pin is now cropped to
  its tight bounding box with the tip exposed as the Marker anchor: Telstra's bitmap (and tap
  target) extends only left of the shared tip, Vodafone's only right, so each pin's head is
  tappable in its own right. `rotated_marker_icon_test.dart` pins the anchor geometry.

## [1.13.13+128] — 2026-08-23

### Fixed
- **Web deploys were invisible to returning visitors** — ausphonetowers.com.au sits behind
  Cloudflare, and the S3 sync uploaded with no `Cache-Control`, so Cloudflare edge-cached
  `main.dart.js` at its default TTL (and browsers heuristic-cached it on top; Flutter web
  filenames are not content-hashed). After the 1.13.12 deploy, edges kept serving the old
  bundle — the marker fan-out and polygon fixes never reached the page. The deploy now uploads
  everything with `Cache-Control: no-cache` (revalidate via ETag → cheap 304s), and a
  purge-on-deploy step activates once `CLOUDFLARE_ZONE_ID`/`CLOUDFLARE_API_TOKEN` are added to
  the Codemagic environment. A one-off manual "Purge Everything" in the Cloudflare dashboard
  clears the already-cached old objects.

## [1.13.12+127] — 2026-08-22

### Fixed
- **Co-located telco pins hid each other on the Web build** — the Java app fans out markers at
  per-telco angles (Telstra −60°, Optus 0°, Vodafone +60°, …) via `Marker.rotation`, which
  `google_maps_flutter_web` silently ignores: on ausphonetowers.com.au every pin rendered bolt
  upright, so a Vodafone pin at a shared site was completely hidden behind the Telstra one. The
  lean is now baked into the icon bitmap itself (`TelcoHelper.getRotatedIcon` rotates the PNG
  about the pin tip on an enlarged canvas, cached per telco; the Marker anchors at the canvas
  centre with `rotation: 0` so mobile doesn't rotate twice). Pinned by
  `rotated_marker_icon_test.dart`.
- **Simple (non-HRP) coverage polygons over-attenuated behind the antenna** — the estimated
  radiation pattern's `(1−cos θ)^1.15 × frontToBack` loss curve is tuned for the main lobe
  (−3 dB at 32°) but was unbounded behind the antenna: 2.22× the front-to-back ratio at 180°
  (~55 dB instead of 25 dB), while front-to-back ratio is by definition the rear attenuation.
  Now clamped at the front-to-back ratio, mirroring the Java app. Validated against 45 real
  `licence_hrp` patterns across all three telcos: back-lobe error improves from −23.6 dB median
  to −1.1 dB, with boresight (+1.4 dB median) and side sectors unchanged. New
  `radiation_pattern_test.dart`.
- **Coverage polygons and borders far darker than the Android app** — the fill alpha had drifted
  to double Java's (base 20 vs 10, satellite/hybrid +40 vs +25). With dozens of stacked rings
  per suburb the doubled per-ring fill compounded into a near-opaque blue sheet. Now matches the
  Java `PolygonHelper.createPolygon` values exactly; the border alpha (30 + fill) lightens with it.

## [1.13.11+126] — 2026-08-22

### Fixed
- **Platform-inappropriate menu items on the Web build** — "Rate App" is hidden on Web (no
  store listing to rate from a browser) and "Remove Ads" is hidden on Web (same store-purchase
  machinery as Donate, which was already hidden there).
- **Store links now match the platform** — "Rate App" on the Android build opened the *Apple*
  App Store listing; it now opens the Google Play listing on Android and the App Store on iOS.
  The Help/Links section shows the store link for the current platform (both stores on Web,
  where a visitor may want the mobile app for either).

### Changed
- **Ad keywords mirror the Android app's tuned commercial-intent head** — plans/SIM/data/home
  internet terms telcos actually bid on, plus the app's coverage/tower vocabulary and the
  road-trip audience. The old hobbyist tail (pager, PMR, CB radio, amateur radio, scanner, TV,
  CBRS, aviation) had near-zero advertiser demand and diluted the list.

## [1.13.10+125] — 2026-08-22

### Fixed
- **No 5G shown at Optus 900 MHz and Telstra 850 MHz towers** — mirrored from the Java app
  (aus_phone_towers_java PR #33), live-verified against production the same day:
  - Optus 900 MHz (B8 + n8): 5G NR SA measured on-air at 939 MHz (Band n8, Tuggeranong ACT)
    inside the single 25 MHz ACMA carrier (`25M0W7D`/`25M0W7W` @ 947.5 MHz). The `'D'` arm now
    classifies `[LTE, NR]` (was LTE-only) and the `'W'` arm `[LTE, NR]` (was UMTS — dead since
    the 2024 3G shutdown), with the `'W'` lower bound corrected 940 → 900 MHz.
  - Telstra 850 MHz (B5 + n5): 86,643 NR n5 observations across 787 distinct cells in the last
    two years; the blanket `'W'` 850 arm now classifies `[LTE, NR]` instead of UMTS (Telstra
    3G850 shut down October 2024). `14M9G7W` was already dual.
  - Confirmed not needed: Vodafone holds no 900-band register rows (its n8 sightings are
    network-sharing on Optus hardware), and Telstra 700 `20M0W7D` stays LTE-only.
  New fixtures in `network_type_classification_test.dart` pin all three carriers.

## [1.13.9+124] — 2026-08-22

### Changed
- Quick-wins parity with the Android app: menu renames to plain English, the RESTify
  empty-`_filter` guard (`RestFilter`), and the ad banner container overflow fix (wrap content
  instead of a fixed height). Codemagic dashboard workflow recreated as `codemagic.yaml` in-repo.
  (This entry was added retrospectively with 1.13.10 — the release itself shipped earlier on
  2026-08-22 without a changelog entry.)

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
