# AGENTS.md — Australian Phone Towers (aus_phone_towers_iphone)

Guidance for any AI agent or developer working in this repository. These rules apply ONLY to this
iPhone/Flutter repository. The Android project (`aus_phone_towers_java`) has its own separate
`AGENTS.md` and should not share these.

## Project basics
- Flutter app (Dart), targeting iOS (primary) and Android (secondary). Package: `phonetowers`.
- State management: `provider` (`ChangeNotifier` singletons — `SiteHelper`, `PurchaseHelper`,
  `SearchHelper`, `MapHelper`, `PolygonHelper` — wired up via `ChangeNotifierProvider` in
  `lib/main.dart` and read via `Provider.of<T>(context, ...)`), plus plain `StatefulWidget`/
  `setState` for local widget-only state. No Riverpod/Bloc — don't introduce a second
  state-management approach without discussing it first.
- Networking: `dio` for HTTP, REST API at `https://api.bitbot.com.au/api`.
- Maps: `google_maps_flutter`.
- Logging: `logger` package.
- Dependencies in `pubspec.yaml`. Run `flutter pub get` after pulling.

## Build commands
- Install dependencies: `flutter pub get`
- Run app: `flutter run`
- Run unit tests: `flutter test`
- Run a specific test: `flutter test test/pathloss/`
- Static analysis: `flutter analyze`
- Build iOS: `flutter build ios`
- Build Android APK: `flutter build apk`
- Clean: `flutter clean`
- Integration tests: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/better_test.dart`

## Flutter SDK
- Flutter SDK is installed at `/home/openhands/tools/flutter` (stable channel).
- Dart SDK is bundled inside Flutter at `/home/openhands/tools/flutter/bin/cache/dart-sdk`.
- If binary permissions are missing after extraction, run:
  `chmod +x /home/openhands/tools/flutter/bin/cache/dart-sdk/bin/dart*` and
  `find /home/openhands/tools/flutter/bin/cache/artifacts -type f -name "impellerc" -o -name "font_subset" -o -name "gen_snapshot" | xargs chmod +x`

## Path loss module (lib/pathloss/)
The path loss algorithm estimates the distance a radio signal travels given a measured path-loss in
dB. It is ported from the Java Android app's `au.com.bitbot.phonetowers.pathloss` package.

### Architecture
- **`PathLossModel`** (interface): `calculateDistance(density, levelInDb, freqInMHz, height)` and
  `calculateDistanceWithContext(mnc, networkType, density, levelInDb, freqInMHz, height)`.
- **`AnalyticPathLossModel`**: Okumura-Hata / COST-231-Hata closed-form formulas. The fallback when
  no trained coefficients are available. Exposes `hataInterceptDb` / `hataSlopeDb` for the
  Hata-anchored trained forms.
- **`Nr3gppPathLossModel`**: 3GPP TR 38.901 (5G NR) path-loss anchor. Used as the calibration anchor
  for 5G NR observations and as the runtime model when no learned NR coefficients exist.
- **`LearnedPathLossModel`**: Uses trained coefficients (fetched from REST). Three functional forms:
  - `log-distance` (legacy): `level = b0 + b1·log10(d) + b2·log10(f) + b3·log10(h)`
  - `hata-correction`: `level = hataIntercept + b0 + b1·hataSlope·log10(d)`
  - `hata-calibration` (current): `log10(d) = b0 + b1·log10(hataDistance)`
  Falls back to analytic Hata (or 3GPP 38.901 for NR) when no coefficients are trained.
- **`PathLossCoefficients`**: Container for trained coefficients, keyed by density-only or composite
  (mnc|networkType|band|density) keys. JSON serialisable (`toJson` / `fromJson`).
- **`PathLossKey`**: Builds composite lookup keys and band buckets (LOW/MID/HIGH).
- **`PathLossModelProvider`**: Singleton. On app startup, fetches coefficients from the REST API
  (`/api/towers/pathloss_coefficients/`). Until the fetch completes (or if it fails), falls back to
  the analytic model. The provider is the single entry point used by `GetLicenceHRP` and
  `PolygonHelper`.
- **`LinearRegression`**: OLS solver (used by tests; the actual training happens server-side in the
  Java app).

### REST endpoint
- Coefficients are fetched from `https://api.bitbot.com.au/api/towers/pathloss_coefficients/?_view=json&_expand=no&_count=100`
- The Java Android app trains the coefficients and writes them to the MySQL `pathloss_coefficients`
  table. This iPhone app only reads them — it does not train.
- REST client: `lib/restful/get_path_loss_coefficients.dart`

### Wiring
- `lib/restful/get_licenceHRP.dart`: `calculateDistance` delegates to `PathLossModelProvider`.
  The context-aware overload `calculateDistanceWithContext` uses composite (mnc+networkType+density)
  lookup, matching the Android app's tower-mapping path.
- `lib/helpers/polygon_helper.dart`: `createBasicPolygon` uses the composite context lookup so
  estimated polygons use the same trained coefficients as the mapping path.
- `lib/main.dart`: `PathLossModelProvider` is initialised fire-and-forget after secrets are loaded.

### Tests
Tests are in `test/pathloss/` and are ported from the Java app's test suite:
- `analytic_path_loss_model_test.dart`: pins exact Hata formula numeric outputs.
- `nr3gpp_path_loss_model_test.dart`: 3GPP 38.901 model behaviour (finite distances, monotonicity,
  b0=0/b1=1 reproduces anchor, NR fallback).
- `learned_path_loss_model_test.dart`: fallback to analytic, coefficient inversion, Hata-anchored
  forms, JSON round-trip, composite overload gap fix.
- `linear_regression_test.dart`: OLS solver correctness (exact fit, noisy fit, singular matrix).

Run with: `flutter test test/pathloss/`

## Ads and billing (lib/helpers/ads_helper.dart, lib/helpers/purchase_helper.dart)
Non-subscribed users see an inline adaptive AdMob banner at the bottom of the map; purchasing
`yearly_adfree` or `permanent_adfree` (via `in_app_purchase`/`in_app_purchase_storekit`) removes it.

### Ads
- **`AdsHelper`** (singleton): loads the banner via `AdSize.getInlineAdaptiveBannerAdSize`, whose
  `AdSize` **always reports `height == 0`** — that's a placeholder size, not the rendered size. The
  real size is only known after load, via `BannerAd.getPlatformAdSize()`, which `AdsHelper` fetches
  in `onAdLoaded` and caches on `loadedAdSize`. Any UI sizing a banner container **must** use
  `loadedAdSize`, never `bannerAd.size` — using the latter silently collapses the ad to zero height
  even though it loaded successfully (this was a real bug, fixed in `AdsHelper`/`AdBannerContainer`).
- **`AdBannerContainer`** (`lib/ui/widgets/ad_banner_container.dart`): the widget that reserves
  space for the banner and shows the "Advertisement" label, decoupled from `google_mobile_ads`
  types (`Size`/plain `Widget` instead of `AdSize`/`AdWidget`) so its sizing logic can be exercised
  in a plain widget test without a platform channel. Covered by
  `test/ui/widgets/ad_banner_container_test.dart`.

### Billing
- **`PurchaseHelper`** (singleton, `ChangeNotifier`): wraps `in_app_purchase` /
  `in_app_purchase_storekit`. The pure decision logic (donation vs. yearly vs. permanent, yearly
  expiry) lives in `lib/helpers/entitlement_evaluator.dart#evaluateEntitlements`, kept
  side-effect-free so it's unit-testable without StoreKit.
- **iOS StoreKit2 gotcha**: `in_app_purchase_storekit` defaults to StoreKit2
  (`InAppPurchaseStoreKitPlatform._useStoreKit2 = true`). In plugin versions up to 0.4.10.x it
  reported `PurchaseDetails.transactionDate` as a local-time `"yyyy-MM-dd HH:mm:ss"` string —
  Android and StoreKit1 report epoch milliseconds instead, and naive `int.tryParse`-only parsing
  silently failed on iOS, so yearly purchases were never recognised as active. This was fixed
  upstream in 0.4.11+1 (StoreKit2 now reports epoch milliseconds too), which this app picked up via
  `flutter pub upgrade`. `evaluateEntitlements` still parses both formats via
  `_parseTransactionDateMillis` (tries `int.tryParse` first, falls back to `DateTime.parse`) as
  defense-in-depth against older/downgraded plugin versions. Covered by
  `test/purchase_helper_test.dart`.

## Documentation must be kept in sync
Whenever you add, change, or remove a user-facing feature, command, or behaviour in this
project, you MUST also update the relevant documentation before considering the task complete:

- `docs/USER_GUIDE.md` — the end-user guide (toolbar menu, map features, behaviours, legends).
- `README.md` — the developer/feature overview, including the Android-vs-iOS feature-comparison
  table and the signal-propagation notes.

This applies to new menu items, exported formats, map overlays/labels, settings, and any
behaviour change a user would notice. Do not leave docs stale after a code change.

## Push to `main` only for an explicit release
A Codemagic build is triggered by every push, and each build costs money, so:

- **Do NOT push to `main` for ordinary / non-release commits.** Keep that work on a branch
  (or simply don't push) so a build is not started on every commit.
- You **may** push directly to `main` only when the user explicitly asks for a release of a
  new version of the app. An explicit release always includes a version bump (see
  "Only bump version when releasing" below), which is what signals a real release.
- When releasing, bump the version and push to `main`. A separate release branch is not
  required unless the user asks for one.
- If the user asks for a normal commit / branch push (not a release), push the branch only —
  do not push to `main`.

## Only bump version when releasing
The iOS app version lives in `pubspec.yaml` (`version:` — `x.y.z+build`). Bump it as part of
a release. Pure doc-only or non-release commits do not require a version bump and may be
pushed from a non-main branch normally.

## Agentic tooling / context & token discipline

### Context exclusions (do not read or scan — token bloat, never source of truth)
- `.dart_tool/**`
- `.pub-cache/**`
- `build/**` (Flutter build output)
- `ios/.symlinks/**`
- `ios/Pods/**`
- `android/.gradle/**`
- `android/app/build/**`

### Platform channels are real here, not hypothetical
`lib/ui/map_common.dart` (Dart side) talks to
`android/app/src/main/java/au/com/bitbot/phonetowers/flutter/MainActivity.kt` (Kotlin side) via
`MethodChannel`. When changing either side, check the other for a breaking API contract change
(method names, argument shapes, return types). `android/` and `ios/` here are thin embedding/
platform-channel glue for this Flutter app — they are not the native Android Java app in the
`aus_phone_towers_java` sibling repo, and its architecture rules don't apply to this folder.

### Native build/config changes
Never modify `android/app/build.gradle`, `ios/Runner.xcodeproj`, `ios/Podfile`, `pubspec.yaml`
dependency versions, or `codemagic.yaml` without first outputting a precise explanation of the
intended change (what, why, and blast radius).

### Token conservation
- Don't run continuous test/build-fix-retest loops automatically. After a single test or build
  failure, stop and ask before attempting a self-correcting retry loop.
- Use incremental edits — refactor one module or feature at a time rather than broad sweeps.

## Conventions
- Dart style: follow `flutter_lints` (enforced by `flutter analyze`). Fix all warnings before
  committing.
- File naming: `lowercase_with_underscores.dart` for source files.
- Test files: `test/` directory mirroring `lib/` structure, `_test.dart` suffix.
- Prefer targeted edits to existing files over creating new files with different suffixes.
- Business logic lives under `lib/helpers/`, `lib/model/`, `lib/networking/`, `lib/restful/`,
  `lib/utils/`, `lib/billing/`; UI lives under `lib/ui/`. Keep new logic in those layers rather
  than inline in widgets.
- The `log10` function is a top-level function in `lib/helpers/translate_frequencies.dart`, NOT
  `dart:math`. Import it where needed (the path loss module and tests use it extensively).
