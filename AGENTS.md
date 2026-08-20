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

## Polygon Precision (lib/helpers/polygon_helper.dart, lib/restful/get_licenceHRP.dart)
`PolygonHelper.polygonBearingIncrement` (set from the "Polygon Precision" menu — Low/Medium/High,
`PolygonHelper.kPolygonPrecisionLow/Medium/High`) controls the bearing step used when tracing a
coverage ring, i.e. how many points it has.

- **Two separate ring-drawing paths exist**, and both must honour this setting:
  - `PolygonHelper.createBasicPolygon` — the circular fallback estimate, used only when a device
    has no `deviceRegistrationIdentifier` or developer mode is on. Loops `bearing +=
    polygonBearingIncrement` directly.
  - `GetLicenceHRP.getLicenceHRPData` — the **primary path**, used for every real tower with
    licence data (the vast majority of sites). This iterates over rows returned by the server
    rather than looping over bearing directly, so it needs `GetLicenceHRP.rowStepForBearingIncrement`
    to translate the precision setting into a row-sampling step. This function was previously
    hardcoded to `i += 2`, silently ignoring the Polygon Precision setting entirely for real towers
    — a real bug (the setting appeared to do nothing, since almost every tower goes through this
    path, not the fallback). Covered by `test/restful/get_licenceHRP_test.dart`.
- **Caching caveat**: `PolygonHelper.queryForSignalPolygon(site, refreshingPolygons,
  cachingPolygons, ...)` — when called with `cachingPolygons == true` (e.g. the terrain-awareness
  toggle in `option_menu.dart`) and the site/device is already cached, it reuses the previously
  computed `PolygonContainer` points verbatim rather than recomputing geometry, so a precision
  change won't retroactively apply until that cache entry is invalidated. The primary marker-tap
  path (`map_common.dart` → `queryForSignalPolygon(site, false, false, ...)`) does **not** use this
  cache, so tapping a tower after changing precision always reflects the new setting.

## Network type classification (lib/model/device_detail.dart)
`DeviceDetails.getNetworkTypeStatic(emission, frequency, bandwidth, telco, antennaId)` classifies
one ACMA licence row from its own emission designator + frequency + telco — **not** stored, always
derived. `getNetworkTypeForLicence` wraps it with frequency refarming (`applyRefarm`, on by
default) and generation-rank tie-breaking (`generationRank`, newest genuine capability wins).
- **This is a line-for-line port of the Java Android app's `DeviceDetails.networkTypesForEmission`
  / `getNetworkTypeForLicence`.** The two must classify every tower identically — any change to one
  side's frequency table, refarm bands, or generation ranking must be mirrored on the other, or the
  same tower will silently show a different technology on Android vs iPhone. Covered by
  `test/network_type_classification_test.dart` and `test/christmas_island_classification_test.dart`
  (ported from the Java app's `DeviceDetailsTest` licence tests and
  `ChristmasIslandClassificationTest`).
- **No hardcoded antenna-ID override sets.** A prior version of this method (both apps) had
  hardcoded `antenna_id` sets (`antennas3G4G`, `antennas3G4G5G`, `antennas4G5G`, ...) that forced
  `LTE`/`NR` regardless of the real carrier. A live production-DB probe (2026-08) proved these were
  injecting phantom/duplicate 5G — confirmed live on this app (debug build 1.13.6, Pixel 8 Pro): the
  Lyneham Vodafone CMTS site showed both a "4G 873 MHz" and a spurious "5G 873 MHz" row for the same
  carrier, because antenna 13198 was hardcoded into both `antennas4G` and `antennas4G5G`. The sets
  are gone on both apps; classification is unambiguous from frequency alone (5G = n77/n78 3.3–3.8
  GHz or n257/n258 24.25–29.5 GHz mmWave; everything sub-3 GHz is 4G or decommissioned 3G).
- **The `switch` dispatches on `emission[6]` — any emission-string equality check must live in the
  matching `case`.** E.g. Telstra's dual 4G/5G `"14M9G7W"` carrier has `'W'` as its own 7th
  character, so the check belongs in `case 'W'`, not `case 'D'` — a 2026-08-20 bug (found while
  porting this method, present in both apps) had it in the wrong arm, making it permanently
  unreachable and silently downgrading those genuine dual-tech carriers to plain UMTS→LTE.

## Support the App (lib/helpers/support_prompt_helper.dart, lib/ui/widgets/support_prompt_screen.dart)
Ported from the Java app's `SupportPromptActivity` / `MapsActivity.maybeShowSupportPrompt()`.

- **`SupportPromptScreen`**: a full-screen prompt (pushed via `Navigator.push`, not a dialog) with
  the cost-transparency message, the three donation buttons (small/medium/large, same SKUs as the
  Donate menu), and — unless `PurchaseHelper().isSubscribed` — the two ad-free purchase buttons
  (same SKUs as Remove Ads), plus a "Maybe later" dismiss button. All purchase taps log a
  `support_prompt_<action>` analytics event (matching Java) before calling
  `PurchaseHelper().initiatePurchase` and popping the route.
- **Reachable two ways**, matching Java exactly:
  1. Manually: the *last* item in the Donate submenu (`listDonateItem` in `option_menu.dart`,
     `Strings.donateSupportPrompt` = "Support the App") — it is a sub-item of Donate, not a
     separate top-level menu entry.
  2. Automatically, about once a week: `SupportPromptHelper.decide` (pure, unit-tested in
     `test/helpers/support_prompt_helper_test.dart`) is the ported decision logic — first-ever
     launch just seeds a SharedPreferences timestamp without showing, then it shows once ≥7 days
     have elapsed since it was last shown/seeded. Wired into
     `MapBodyState.initState()` → `_maybeShowSupportPrompt()` in `map_common.dart`, deferred via
     `addPostFrameCallback` so a `Navigator` ancestor is guaranteed to exist.
- **Deliberately not ported**: the Java screen's "Watch an ad instead" button (a rewarded ad). This
  app has no rewarded/interstitial ad unit configured — only banner ads (see `AdsHelper`) — and a
  real AdMob rewarded ad unit ID would need to be created first; a test-only ad unit ID was not
  used here to avoid shipping a fake button in production.

## Top-level option menu ordering (lib/ui/widgets/option_menu.dart)
`OptionMenuItem`'s declaration order drives the on-screen order (`OptionMenuItem.values` is mapped
directly in `itemBuilder`). It's kept aligned with the Java app's `popup_menu.xml` order for every
item that exists on both platforms: Reload Everything, Follow GPS, Hide Borders, Search Sites, Map
Mode, Rotating Map, Hiding Menu, Export Data, Remove Ads, Donate, Problems Menu, Rate App, Close
App. Two items have no Android equivalent (`lockMap`, `polygonPrecision`) and are inserted next to
their closest thematic neighbour (`rotatingMap`, `exportData` respectively) rather than breaking
that shared sequence. `Calculate Terrain` and `Timing Advance` are Android menu items with no iOS
menu equivalent (Calculate Terrain is a persistent toolbar icon button in `map_common.dart`; Timing
Advance isn't implemented on iOS at all) and are intentionally absent here — don't add them to this
enum without also building the underlying feature.

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
- **Live pricing, not hardcoded**: menu/screen labels (Remove Ads, Donate, Support the App) show
  the store's own localized price string (`ProductDetails.price`, from `_getProducts()`'s
  `queryProductDetails` call), not a hardcoded `$X.XX` literal — prices vary by storefront/locale
  and can change without an app update. `PriceLabelHelper` (pure, `lib/helpers/price_label_helper.dart`,
  tested in `test/helpers/price_label_helper_test.dart`) builds `"Name ($price)"` from a product
  list; `PurchaseHelper.priceFor` / `priceLabel` are thin instance wrappers over it. The hardcoded
  `Strings.donateSmall` / `remove_ads_year` etc. strings are kept only as the **fallback** shown
  before `_getProducts()` resolves (or if it fails) — don't remove them. `_getProducts()` calls
  `notifyListeners()` once products load so already-open `Consumer<PurchaseHelper>` UI (e.g.
  `SupportPromptScreen`) picks up live pricing without needing an unrelated purchase event to
  trigger a rebuild first.

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

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:970c3bf2 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   bd dolt push
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->
## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at `.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale. Codex 0.129.0+ can load Beads context automatically through native hooks; use `/hooks` to inspect or toggle them.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/SYNC_CONCEPTS.md for details and anti-patterns.
<!-- END BEADS CODEX SETUP -->
