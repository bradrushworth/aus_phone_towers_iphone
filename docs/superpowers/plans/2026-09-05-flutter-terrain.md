# Flutter port: terrain awareness (effective height, coverage intervals, site_terrain) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Android app's terrain rework (aus_phone_towers_java PR #74) to the Flutter app so both apps feed the learned path-loss model the same effective antenna height, draw coverage that returns beyond a shadowed valley with holes for the shadow, and read the nightly `site_terrain` row instead of calling the Google Elevation API.

**Architecture:** Three pure Dart classes (`TerrainHeight`, `TerrainCoverage`, `ShadowHoles`) mirror the Java `utilities` classes one-to-one; `GetLicenceHRP` and `PolygonHelper.createBasicPolygon` use them per bearing; `GetSiteTerrain` fetches the row through the existing `Api`/Dio layer and `Site.applyTerrain` installs it. Behaviour must match the Android app, whose sources are the reference: `app/src/main/java/au/com/bitbot/phonetowers/utilities/{TerrainHeight,TerrainCoverage,ShadowHoles}.java`, `restful/{GetLicenceHRP,GetSiteTerrain}.java`, `helper/PolygonHelper.java`, `model/Site.java` in `C:/Users/Brad/StudioProjects/aus_phone_towers_java` (read them; do not copy Java idioms blindly).

**Tech Stack:** Flutter 3.48 (master channel, on PATH), Dart, google_maps_flutter 2.17 (`Polygon.holes`), Dio, `flutter test` (plain unit tests under `test/`).

**Spec:** the Android PR #74 description and the beads keen-moser-3c3ce6-xlv / -1g2 in the Java repo (`bd show`), summarised in the Goal above.

## Global Constraints

- Work in the git worktree `C:/Users/Brad/StudioProjects/aus_phone_towers_iphone/.claude/worktrees/terrain-port` (branch `claude/terrain-port`, from `origin/main` at 1.14.17+152). `flutter pub get` has been run there.
- Tests: `flutter test test/<path>` while iterating; `flutter test` once before each commit (must stay green); `flutter analyze` must report no new issues in files you touched.
- Commits: `git commit -F <message-file>` (no backticks or inner quotes); do not push.
- **Shared grid (never redefine):** `GetElevation.SAMPLE_DISTANCES` (19 values, 0.5–16 km) in `lib/restful/get_elevation.dart`; 24 bearings at 15° (index i = bearing i×15, 0 = north) defined once in `TerrainHeight`.
- **Effective height clamp:** 5 m to 1000 m (`TerrainHeight.minEffectiveHeightM`, `maxEffectiveHeightM`).
- **RESTify JSON shape** (see `lib/restful/get_devices.dart` and `lib/networking/response/site_response.dart`): `{"restify": {"rows": [{"values": {"col": {"value": "..."}}}]}}`; values are strings. Filter syntax is `site_id==<id>` URL-encoded, built the way `GetLicenceHRP`/`RestFilter` build theirs (`lib/restful/rest_filter.dart` if present, else the pattern in `get_licenceHRP.dart`). Endpoint: `/towers/site_terrain/?_view=json&_expand=no&_count=1&_filter=<filter>&_fields=site_id,ground_m,bearing_median_m,profile_m`. The live server already serves it (3,817 rows on 2026-09-05).
- `site_terrain` row: `ground_m` int; `bearing_median_m` = 24 comma-separated ints; `profile_m` = 24 groups separated by `;`, each 19 comma-separated ints at `SAMPLE_DISTANCES`.
- The two existing terrain tests (`test/restful/terrain_losses_test.dart`, `test/restful/get_licenceHRP_test.dart`) and `test/restful/get_elevation_test.dart` must keep passing or be updated with an explanation of the numbers.
- Android parity checkpoints (from the Java code, keep identical): `TerrainCoverage.minOuterKm = 0.25`, `refineSteps = 3`; `ShadowHoles.shrink = 0.98`, `capDegrees = 1.0`, `minNearKm = 0.05`, cap fraction 0.8; terrain-row wait ≤ 2 s; elevation wait ≤ 30 s.

---

## File structure

- `lib/model/height_distance_pair.dart` — compareTo by distance then height (F1).
- `lib/restful/get_licenceHRP.dart` — `terrainExcessLossDb` examines every sample (F1); `calculateTerrainCoverage`, `terrainExcessLossForBearing` (memoised), wiring (F5); bounded waits (F6).
- `lib/pathloss/terrain_height.dart` — NEW pure (F2).
- `lib/pathloss/terrain_coverage.dart` — NEW pure (F3).
- `lib/helpers/shadow_holes.dart` — NEW pure geometry (F4).
- `lib/model/site.dart` — terrain fields, `effectiveHeightM`, `applyTerrain`; `getSiteHillElevation` removed (F5, F6).
- `lib/model/device_detail.dart` — per-rung terrain holes (F5).
- `lib/helpers/polygon_helper.dart` — `createBasicPolygon` wiring, `createPolygon` holes, cache path keeps holes, terrain trigger (F5, F6).
- `lib/restful/get_site_terrain.dart` — NEW REST fetch (F6); `lib/networking/api.dart` gains `getSiteTerrainData` (F6).
- Tests: `test/model/height_distance_pair_test.dart`, `test/pathloss/terrain_height_test.dart`, `test/pathloss/terrain_coverage_test.dart`, `test/helpers/shadow_holes_test.dart`, `test/restful/get_site_terrain_test.dart`, `test/model/site_terrain_apply_test.dart`, `test/helpers/polygon_helper_terrain_test.dart`.

Tasks run in order F1 → F6 on the one branch; F7 (changelog + version) is the coordinator's.

---

### Task F1: `HeightDistancePair` orders by distance; knife-edge check examines every sample

**Files:** Modify `lib/model/height_distance_pair.dart`; modify `lib/restful/get_licenceHRP.dart` (`terrainExcessLossDb`, ~lines 430–470); Test `test/model/height_distance_pair_test.dart` (new).

**Why:** `compareTo` compares height only. `terrainExcessLossDb` sorts by it and examines only the top quarter, assuming the highest samples are the only obstacles — false on a rising profile (the receiver-side samples are the highest and are all beyond the receiver, so nothing is ever checked). The Android fix examines all 19 samples; parity requires the same.

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/model/height_distance_pair.dart';

void main() {
  test('sorting a profile orders by distance, not height', () {
    final pairs = [
      HeightDistancePair(height: 700, distance: 3.0),
      HeightDistancePair(height: 500, distance: 1.0),
      HeightDistancePair(height: 900, distance: 2.0),
    ]..sort();
    expect(pairs.map((p) => p.distance).toList(), [1.0, 2.0, 3.0]);
  });

  test('equal heights at different distances are distinct set members', () {
    final set = <HeightDistancePair>{};
    for (double d = 0.5; d <= 16; d += 0.5) {
      set.add(HeightDistancePair(height: 600, distance: d));
    }
    expect(set.length, 32);
  });
}
```

- [ ] **Step 2: Run** `flutter test test/model/height_distance_pair_test.dart` — the first test FAILS.

- [ ] **Step 3: Implement** — `compareTo`: `final byDistance = distance.compareTo(other.distance); return byDistance != 0 ? byDistance : height.compareTo(other.height);` with a doc comment saying why (one sample per distance; ordering by height alone made the top-quarter heuristic blind on rising profiles). In `terrainExcessLossDb` delete `limitSamples`, `samples`, the sort/reverse and the `break`; iterate `heightToDistance` directly (19 samples is cheap). Update its doc comment ("Only the highest quarter…" is gone).

- [ ] **Step 4: Run** `flutter test test/restful/terrain_losses_test.dart test/restful/get_licenceHRP_test.dart test/model/height_distance_pair_test.dart`; if an existing expectation flips from unobstructed to obstructed on a rising profile (the Android test `calculateTerrainLossUpHill` did), verify by hand that an intermediate sample really breaks the line of sight (clearance < 0 after the bulge term) and update the expectation, explaining the numbers in the commit message. Then `flutter test` and `flutter analyze`.

- [ ] **Step 5: Commit** — `Terrain: HeightDistancePair orders by distance; knife-edge check examines every sample (mirror of Android PR #74)`

---

### Task F2: `TerrainHeight`

**Files:** Create `lib/pathloss/terrain_height.dart`; Test `test/pathloss/terrain_height_test.dart`.

**Produces:**
```dart
class TerrainHeight {
  static const int bearings = 24;
  static const double bearingStepDegrees = 360 / bearings;   // 15
  static const double minEffectiveHeightM = 5;
  static const double maxEffectiveHeightM = 1000;
  static int bearingIndex(double bearingDegrees);
  static double effectiveHeightM(double antennaHeightM, int? groundM, List<int>? bearingMedianM, double bearingDegrees);
  static List<int>? parseCsv(String? csv, int expectedCount);   // null when absent/malformed/wrong count
  static String toCsv(List<int> values);
}
```

- [ ] **Step 1: Failing tests** (mirror the Java `TerrainHeightTest` exactly):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/pathloss/terrain_height.dart';

List<int> medians(int v) => List<int>.filled(TerrainHeight.bearings, v);

void main() {
  test('bearingIndex rounds to the nearest 15 degrees', () {
    expect(TerrainHeight.bearingIndex(0), 0);
    expect(TerrainHeight.bearingIndex(7.4), 0);
    expect(TerrainHeight.bearingIndex(7.6), 1);
    expect(TerrainHeight.bearingIndex(345), 23);
    expect(TerrainHeight.bearingIndex(359), 0);
    expect(TerrainHeight.bearingIndex(360), 0);
    expect(TerrainHeight.bearingIndex(-15), 23);
  });
  test('hilltop site gains its height above the median terrain', () {
    expect(TerrainHeight.effectiveHeightM(30, 800, medians(600), 90), 230.0);
  });
  test('valley site loses height but never below the floor', () {
    expect(TerrainHeight.effectiveHeightM(30, 580, medians(600), 0), 10.0);
    expect(TerrainHeight.effectiveHeightM(30, 500, medians(600), 0), TerrainHeight.minEffectiveHeightM);
  });
  test('ceiling applies to extreme summits', () {
    expect(TerrainHeight.effectiveHeightM(30, 2000, medians(400), 0), TerrainHeight.maxEffectiveHeightM);
  });
  test('without terrain the antenna height is used, clamped', () {
    expect(TerrainHeight.effectiveHeightM(30, null, null, 0), 30.0);
    expect(TerrainHeight.effectiveHeightM(30, 800, null, 0), 30.0);
    expect(TerrainHeight.effectiveHeightM(0, null, null, 0), TerrainHeight.minEffectiveHeightM);
  });
  test('per-bearing median is picked by bearing', () {
    final m = medians(600)..[6] = 700;
    expect(TerrainHeight.effectiveHeightM(30, 800, m, 90), 130.0);
    expect(TerrainHeight.effectiveHeightM(30, 800, m, 180), 230.0);
  });
  test('csv round-trips and rejects the wrong length', () {
    final m = medians(12)..[3] = -4;
    expect(TerrainHeight.parseCsv(TerrainHeight.toCsv(m), TerrainHeight.bearings), m);
    expect(TerrainHeight.parseCsv('1,2,3', TerrainHeight.bearings), isNull);
    expect(TerrainHeight.parseCsv('a,b', 2), isNull);
    expect(TerrainHeight.parseCsv(null, 2), isNull);
  });
}
```

- [ ] **Step 2: Implement** (port of the Java class; doc comment explaining hb = height above the average terrain and the former double count):

```dart
class TerrainHeight {
  static const int bearings = 24;
  static const double bearingStepDegrees = 360 / bearings;
  static const double minEffectiveHeightM = 5;
  static const double maxEffectiveHeightM = 1000;

  static int bearingIndex(double bearingDegrees) {
    double b = bearingDegrees % 360;
    if (b < 0) b += 360;
    return (b / bearingStepDegrees).round() % bearings;
  }

  static double effectiveHeightM(double antennaHeightM, int? groundM, List<int>? bearingMedianM, double bearingDegrees) {
    double h = antennaHeightM;
    if (groundM != null && bearingMedianM != null && bearingMedianM.length == bearings) {
      h += groundM - bearingMedianM[bearingIndex(bearingDegrees)];
    }
    return h.clamp(minEffectiveHeightM, maxEffectiveHeightM).toDouble();
  }

  static List<int>? parseCsv(String? csv, int expectedCount) {
    if (csv == null) return null;
    final parts = csv.trim().split(',');
    if (parts.length != expectedCount) return null;
    final out = <int>[];
    for (final p in parts) {
      final v = int.tryParse(p.trim());
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  static String toCsv(List<int> values) => values.join(',');
}
```

- [ ] **Step 3: Run, commit** — `Terrain: TerrainHeight, the effective antenna height rule shared with the trainer (mirror of Android)`

---

### Task F3: `TerrainCoverage`

**Files:** Create `lib/pathloss/terrain_coverage.dart`; Test `test/pathloss/terrain_coverage_test.dart`.

**Produces:**
```dart
typedef DistanceSolver = double Function(double linkBudgetDb);
typedef ExcessLoss = double Function(double distanceKm);
class Shadow { final double nearKm, farKm; }
class TerrainCoverageResult { final double outerKm; final List<Shadow> shadows; }
class TerrainCoverage {
  static const double minOuterKm = 0.25;
  static const int refineSteps = 3;
  static TerrainCoverageResult evaluate(double linkBudgetDb, DistanceSolver solver, ExcessLoss loss, List<double> sampleDistancesKm);
}
```

**Semantics (identical to Java `TerrainCoverage`):** `flat = solver(budget)`; unusable (non-finite or ≤ 0) → `Result(flat, [])`. Points = every sample < flat, plus flat. A point is covered when `loss(p) <= 0` or `solver(budget − loss(p)) >= p`. `outerKm` = farthest covered point refined by `refineSteps` bisections toward the next uncovered point; `minOuterKm` (or flat if smaller) when none covered. Shadows = maximal runs of uncovered points before the last covered point; `nearKm` = midpoint of (previous covered point or 0, first uncovered); `farKm` = midpoint(last uncovered, next covered). **Close a run that ends immediately before the last covered point** (the Java draft missed this; the committed Java code has a trailing-run block).

- [ ] **Step 1: Failing tests** — port the Java `TerrainCoverageTest` six cases verbatim (`SAMPLES` = the 19 distances; `SOLVER = (b) => 10 * pow(10, (b - 100) / 20)`; clear path keeps flat 10 km with no shadows; ridge loss 30 dB for 3.5..8.5 km gives outer 10, one shadow near (3.0+3.5)/2 far (8.5+10)/2; mild 10 dB obstruction beyond 5 km gives outer in [4.5, 5.5] and no shadows; weaker threshold reaches further; everything blocked → `minOuterKm`; NaN solver → NaN outer, no shadows).

- [ ] **Step 2: Implement** — port `TerrainCoverage.java` from the Android repo (read it at `app/src/main/java/au/com/bitbot/phonetowers/utilities/TerrainCoverage.java`), including its `covered()` helper, the bisection, the in-loop and trailing-run shadow closing, and the doc comment (why per-sample evaluation replaced the shrink-only loop).

- [ ] **Step 3: Run, commit** — `Terrain: TerrainCoverage evaluates every sample along a bearing so coverage past a shadowed valley is kept (mirror of Android)`

---

### Task F4: `ShadowHoles`

**Files:** Create `lib/helpers/shadow_holes.dart`; Test `test/helpers/shadow_holes_test.dart`.

**Produces:**
```dart
typedef PointAt = LatLng Function(double bearingDegrees, double distanceKm);
class ShadowHoles {
  static const double shrink = 0.98, capDegrees = 1.0, minNearKm = 0.05;
  static List<List<LatLng>> build(LatLng site, List<double> bearings, List<TerrainCoverageResult?> results, PointAt pointAt);
  /// One entry per rung; a rung whose result list length differs from bearings gets an empty list.
  static List<List<List<LatLng>>> buildAllRungs(LatLng site, List<double> bearings, List<List<TerrainCoverageResult>> coverageByRung, PointAt pointAt);
}
```

**Rules (identical to Java `ShadowHoles.java` after PR #74's fix wave):** clamp near ≥ `minNearKm`, far ≤ `shrink × outer_i`, drop if far ≤ near; a shadow continues the run that ended at the previous bearing index when its range overlaps the run's last interval, else starts a run; ring order `(b1−cap, near1)`, `(bi, neari)…`, `(bk+cap, neark)`, `(bk+cap, farkCap)`, `(bi, fari)` reversed, `(b1−cap, far1Cap)`, with cap fars clamped to `shrink × lerp(outer_i, outer_neighbour, 0.8)` toward the neighbour outside the run, then clamped ≥ near, and the two cap vertices on a side omitted when that clamp collapses to near (no bow-tie). No wrap around 360. `LatLng` from `google_maps_flutter` is a plain value class usable in unit tests.

- [ ] **Step 1: Failing tests** — port the Java `ShadowHolesTest` (adjacent overlapping shadows → one ring of 2+3+3+2 vertices inside 4..8.5 km; a clear bearing splits runs; non-overlapping ranges → separate rings; clamped inside `shrink × outer`; cap clamped to the neighbour edge; degenerate shadows dropped; the bow-tie case omits caps) plus one `buildAllRungs` case (two rungs, the second misaligned → empty). Use the flat-earth `PointAt` from the Java test (1 km = 0.009°).

- [ ] **Step 2: Implement** — port `ShadowHoles.java` (read the committed version, which has `buildAllRungs` and the cap clamp).

- [ ] **Step 3: Run, commit** — `Terrain: ShadowHoles merges per-bearing shadow bands into polygon hole rings (mirror of Android)`

---

### Task F5: Wire effective height, intervals and holes into polygon drawing

**Files:** Modify `lib/model/site.dart` (fields; remove `getSiteHillElevation`), `lib/model/device_detail.dart`, `lib/restful/get_licenceHRP.dart` (bearing loop ~140–200; terrain functions ~355–420), `lib/helpers/polygon_helper.dart` (`createBasicPolygon` ~615–700, `createPolygon` ~348–400, the cache path ~294 that reuses `polygonContainer.getPolygon().points`); Tests: update `test/restful/terrain_losses_test.dart`, add `test/helpers/polygon_helper_terrain_test.dart` for any pure helper you extract.

**Produces:**
- `Site`: `int? terrainGroundM; List<int>? terrainMedians; bool terrainRequested = false; bool terrainLoaded = false; double effectiveHeightM(double antennaHeightM, double bearing) => TerrainHeight.effectiveHeightM(antennaHeightM, terrainGroundM, terrainMedians, bearing);`
- `DeviceDetails`: `final Map<int, List<List<LatLng>>> _terrainHoles = {}; void setTerrainHoles(int rung, List<List<LatLng>> holes); List<List<LatLng>> terrainHoles(int rung); void clearTerrainHoles();`
- `GetLicenceHRP`: `static TerrainCoverageResult calculateTerrainCoverage(Site site, Set<HeightDistancePair> heights, double linkBudgetDb, DistanceSolver solver, double bearing, double freqInMHz, int towerHeight)`; `calculateTerrainLosses(...)` kept as `=> calculateTerrainCoverage(...).outerKm`; `static ExcessLoss terrainExcessLossForBearing(Site site, Set<HeightDistancePair> heights, double bearing, double freqInMHz, int towerHeight)` that computes the transmitter elevation once and memoises loss per distance in a `Map<double,double>`; `terrainExcessLossDb` gains an overload/parameter taking the precomputed transmitter elevation (keep the old signature as a wrapper for the tests). Delete `MAX_TERRAIN_ITERATIONS` and `TERRAIN_LOSS_TOLERANCE_DB`; rewrite the doc comment (keep the issue #56 history, explain the per-sample evaluation).

**Wiring, in both `GetLicenceHRP` (licence patterns) and `PolygonHelper.createBasicPolygon` (circular estimate):**
1. Remove the `hillHeight` block. `heights = calculateTerrain ? site.getHeightsAlongBearing(bearing) : {}`.
2. `final double effectiveHeight = site.effectiveHeightM(towerHeight.toDouble(), bearing);` and pass it to the solver in BOTH modes (replacing `towerHeight + hillHeight` / `towerHeight`). Comment: the trainer fits against this same rule; terrain mode used to add the hill on top of coefficients that already averaged hilltop sites (counted twice).
3. Per bearing build `final loss = GetLicenceHRP.terrainExcessLossForBearing(site, heights, bearing, freqInMHz, towerHeight)` once (terrain mode only) and, per rung, `final coverage = TerrainCoverage.evaluate(freeSpaceLoss_dBi, solver, loss, GetElevation.SAMPLE_DISTANCES); distanceKm = coverage.outerKm; coverageByRung[p].add(coverage);` (non-terrain: `distanceKm = solver(freeSpaceLoss_dBi)`). Keep the 100 km clamp. Append the bearing to a `bearingsUsed` list exactly once per bearing.
4. After the bearing loop, only when `calculateTerrain`: `device.clearTerrainHoles(); final holes = ShadowHoles.buildAllRungs(site.getLatLng(), bearingsUsed, coverageByRung, (b, km) => GetLicenceHRP.travel(site.getLatLng(), b, km)); for (rung, list) → device.setTerrainHoles(rung, list)`. Non-terrain passes must not clear the holes (the toggle-back path draws from cached shapes).
5. `createPolygon`: `holes: PolygonHelper.calculateTerrain ? device.terrainHoles(i).where((h) => h.length >= 3).toList() : const <List<LatLng>>[]`. In the cache path (~line 294) that reuses `polygonContainer.getPolygon().points`, keep the existing polygon's holes when redrawing (`Polygon.holes`), so toggling terrain off and on does not lose them.

- [ ] **Step 1:** Implement 1–5 and the model/device additions. Delete `Site.getSiteHillElevation` and every caller (only the two builders use it; `grep -rn getSiteHillElevation lib`).
- [ ] **Step 2:** Update `test/restful/terrain_losses_test.dart` to the sample-based semantics (clear path unchanged; weaker threshold reaches further; obstructed shorter than clear). If a test asserted a specific shrunk distance from the old iteration, replace it with the sample-based value and explain the numbers in the commit message.
- [ ] **Step 3:** `flutter test`; `flutter analyze`. Commit — `Terrain: effective height in both modes, per-sample coverage intervals, shadow holes in the polygons (mirror of Android PR #74)`

---

### Task F6: `GetSiteTerrain` — load the row, feed the profile, bounded waits

**Files:** Create `lib/restful/get_site_terrain.dart`; modify `lib/networking/api.dart` (`Future<Map<String, dynamic>?> getSiteTerrainData(String path)` returning the raw JSON map, `null` on any Dio error, logged like the other calls), `lib/model/site.dart` (`applyTerrain`), `lib/helpers/polygon_helper.dart` (trigger), `lib/restful/get_licenceHRP.dart` (waits); Tests `test/restful/get_site_terrain_test.dart` (parsing from a JSON map, no network), `test/model/site_terrain_apply_test.dart`, `test/helpers/polygon_helper_terrain_test.dart` (the `needsGoogleElevation` truth table).

**Produces:**
- `GetSiteTerrain({required Site site, required Api api})` with `static String urlFor(Site site)` (endpoint from Global Constraints), `Future<void> fetch()` that: requests; parses `rows[0].values.{ground_m,bearing_median_m,profile_m}.value` (`int.tryParse` for ground; `TerrainHeight.parseCsv(..., 24)` for medians; `parseProfile` for the profile — 24 groups split on `;`, each `parseCsv(..., SAMPLE_DISTANCES.length)`, null if anything is off); on a usable row calls `site.applyTerrain(ground, medians, profile)`; in a `finally` sets `site.terrainLoaded = true` and, when `PolygonHelper.calculateTerrain && !site.finishedDownloadingElevations`, starts the Google download via `PolygonHelper.startGoogleElevation(site)`. Empty rows, 404, malformed values or a thrown error all end with `terrainLoaded = true` and nothing else changed. `static List<List<int>>? parseProfile(String? text)` is pure and tested.
- `Site.applyTerrain(int groundM, List<int> bearingMedianM, List<List<int>>? profileM)`: sets `terrainGroundM`/`terrainMedians`; with a 24-group profile writes `elevations[latLng] = value` directly (NOT `putIfAbsent`) for the site itself (ground) and for each of the 24 × 19 points at `GetLicenceHRP.travel(getLatLng(), i * TerrainHeight.bearingStepDegrees, SAMPLE_DISTANCES[k])`, then sets `startedDownloadingElevations = finishedDownloadingElevations = true`; always sets `terrainLoaded = true`.
- `PolygonHelper.startGoogleElevation(Site site)`: the existing Google-start block (~lines 192–226) extracted, idempotent via `startedDownloadingElevations`; on any failure to start sets `startedDownloadingElevations = false` AND `finishedDownloadingElevations = true` (so the wait cannot hang). `static bool needsGoogleElevation(bool calculateTerrain, bool terrainLoaded, bool finishedDownloadingElevations) => calculateTerrain && terrainLoaded && !finishedDownloadingElevations;`
- Trigger in `queryForSignalPolygon`, in BOTH modes: `if (!site.terrainRequested) { site.terrainRequested = true; GetSiteTerrain(site: site, api: api).fetch(); }` then `if (needsGoogleElevation(calculateTerrain, site.terrainLoaded, site.finishedDownloadingElevations)) startGoogleElevation(site);` (covers terrain switched on after the row was answered while terrain was off).
- `GetLicenceHRP` waits: before the existing terrain wait, `final deadline = DateTime.now().add(const Duration(seconds: 2)); while (site.terrainRequested && !site.terrainLoaded && DateTime.now().isBefore(deadline)) { await Future.delayed(const Duration(milliseconds: 50)); }` in both modes; the terrain-mode wait on `finishedDownloadingElevations` gets a 30-second deadline after which it logs a warning and proceeds without terrain. Extract `static bool shouldKeepWaitingForElevation(Site site, DateTime now, DateTime deadline)` and test it.

- [ ] **Step 1:** Failing tests: `parseProfile` (24 × 19 round-trips; 23 groups → null; a non-numeric sample → null); `applyTerrain` (ground at the site, 19 samples along bearing 90 with the last one 900 m, flags set; without a profile flags untouched but `terrainLoaded` true and `effectiveHeightM(30, 45) == 230` for ground 800/medians 600); `needsGoogleElevation` truth table (4 rows); `shouldKeepWaitingForElevation` (deadline passed → false).
- [ ] **Step 2:** Implement; `flutter test`; `flutter analyze`.
- [ ] **Step 3:** Commit — `Terrain: GetSiteTerrain loads the nightly site_terrain row; profiles replace the Google Elevation download; bounded waits (mirror of Android)`

---

### Task F7 (coordinator): CHANGELOG entry, version 1.14.18+153, PR, merge

`CHANGELOG.md` gains a `## [1.14.18+153] — <date>` entry (Keep a Changelog style, as the existing entries) describing the four user-visible changes; `pubspec.yaml` `version: 1.14.18+153`.

---

## Self-review

- Coverage: Android A1→F1, A2→F2, A3→F3, A4→F4, A5→F5 (incl. the fix-wave items: memoised loss, holes kept across the toggle, no clear in non-terrain passes), A6→F6 (incl. values shape, onCancelled/finally, toggle-on-later, 30 s backstop). The Android `CalculateConnectedTower` change has no Flutter counterpart (no caller of `getSiteHillElevation` outside the two builders).
- Types: `DistanceSolver` in F3 is the same shape as the local `solver` closures in F5 (`double Function(double)`), so no bridge is needed. `TerrainCoverageResult` is the name used by F4/F5. `PointAt` returns `LatLng`. `parseCsv` returns `List<int>?`.
- Dart specifics: `Set<HeightDistancePair>` stays a Set (its `==`/`hashCode` already include distance, so equal heights never collapsed here — F1 is about ordering and the quarter cap, not Set membership); `elevations` is a `Map<LatLng,double>` whose `addElevation` uses `putIfAbsent`, hence the direct write in `applyTerrain`.
