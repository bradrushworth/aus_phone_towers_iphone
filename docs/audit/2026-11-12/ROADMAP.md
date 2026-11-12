# iPhone product roadmap, 2026-11-12

Grounded in what this app is: a map of every licensed transmitter in Australia with calculated
coverage, on a platform that cannot tell which tower the phone is using. Its strengths are the
shared data and models from the Android project, a web edition from the same code, and a working
ads plus one-off-purchase model. Effort: S is under a week for one agent with review, M one to
three weeks, L more. Finding ids refer to REPORT.md in this folder.

## Now (next one or two releases)

### 1. A map that shows what is there
- **Value:** every tower appears, 5G rings mean the same as on Android, and a bad connection says
  so instead of leaving a blank area.
- **Evidence:** I1, I2, I3, I6.
- **Effort:** S. Four small changes, each with a unit test.
- **Risks:** 5G shapes grow; say so in the changelog. I3 touches the recursive neighbour download.
- **Depends on:** nothing.
- **Measure:** the device check for I2; no "towers missing" reports; Crashlytics non-fatals from
  `downloadTowersForSingleTelco` fall to zero.

### 2. An export that search and rescue can use
- **Value:** a police or SES volunteer with an iPhone gets the same file as a colleague with
  Android, into Files, AirDrop or email, with the heights a viewshed needs.
- **Evidence:** I4, I5. The guide says this is why the export exists.
- **Work:** step 1 of I4 at once (Files visibility, no new dependency). Then the share sheet and
  the Android field contract together.
- **Effort:** S, then M.
- **Risks:** field names are safety-relevant and need the owner's ruling. A new dependency
  (`share_plus`). Never floor or invent a height.
- **Depends on:** the owner's decision on the terrain-model elevation fields proposed for Android
  (its audit item A16), so both apps add them in one release.
- **Measure:** exports shared per week (one analytics event); one agency confirming the file
  loads in the template it uses for the Android file.

### 3. Store compliance pass
- **Value:** no avoidable rejection or warning at the next submission.
- **Evidence:** I10, I11, I18, I20, and I12 for the Android build.
- **Effort:** S.
- **Risks:** the privacy manifest must agree with the App Privacy answers in App Store Connect.
- **Depends on:** a privacy-policy URL from the owner.
- **Measure:** an upload with no ITMS warnings; a TestFlight build with no compliance prompt.

### 4. Small fixes users will notice
- I7 (map jumps back), I8 (search offline), I9 (Report a Problem), I15, I16. **Effort:** S.
- I9 needs a Mac build to verify. It matters more than its size: it is how users reach the owner.

## Next (the quarter)

### 5. Saved areas for offline use
- **Value:** the map works where there is no data, which is where people most want to know where
  the nearest tower is. Useful to travellers, rural users and search teams alike.
- **Evidence:** Android ships it. Its logic (bounds, index, codec, sector maths) is plain code
  with unit tests, written to be free of platform types. Nothing in it needs cell information.
- **Work:** port the offline package to `lib/offline/`; "Save this area" and "Saved areas" in Map
  Layers; draw the estimated shapes from saved data, as Android does; state the age of the data.
- **Effort:** M.
- **Risks:** storage growth (cap the area, as Android does); stale data must be labelled.
- **Depends on:** item 1 (I3 is the same code path).
- **Measure:** saved areas per user; sessions that draw from saved data.

### 6. Compass to a tower
- **Value:** "which way is that tower?" for pointing an antenna or a booster, or walking to
  better signal. It works without knowing the serving cell: the user picks the tower.
- **Evidence:** Android has a compass screen whose maths (bearing, distance, smoothing, target
  choice) is plain code with tests. This app already uses `flutter_compass` for map rotation.
  "Signal booster" is in the ads keyword head because that audience is here.
- **Work:** a "Compass" button on the site sheet beside Directions and ACMA; a full-screen dial
  with bearing and distance; own location updates while open.
- **Effort:** M.
- **Risks:** compass accuracy near vehicles; say so on the screen. iPhone only, not web.
- **Measure:** opens per week; time on the screen.

### 7. Nearest towers, by carrier
- **Value:** answers the question the store listing asks ("Which is the best phone provider for
  you?") without asking the user to read polygons: for where you are, each carrier's nearest
  sites, their bands, and which predicted ring you stand inside.
- **Evidence:** all inputs are on the phone: loaded sites, model v2 distances per ring, location.
- **Work:** a sheet from a "Near me" chip; rows per carrier; tap a row to open the site.
- **Effort:** M.
- **Risks:** it is a prediction from licences, not a measurement. Label it that way, show ring
  names and never a dBm figure, and get the owner's ruling on the wording before building.
- **Depends on:** item 1.
- **Measure:** opens per session; site sheets opened from it.

### 8. Local ad keywords
- **Value:** more relevant ads at no cost to the user. **Evidence:** I14. **Effort:** S.
- **Measure:** banner eCPM for the four weeks before and after.

### 9. iOS platform upkeep
- **Value:** the app keeps launching on new iOS versions and keeps passing upload checks.
- **Evidence:** I13; the changelog lists major versions held back (`device_info_plus` 13,
  `location` 10, `package_info_plus` 10, the next Firebase line).
- **Effort:** M. **Risks:** native changes cannot be tested from Windows; each needs a Codemagic
  build and a TestFlight check. **Measure:** crash-free sessions unchanged after each step.

## Later

- **10. Measured-signal layer.** If the Android project builds its planned layer of what phones
  actually measure per area, this app should show it. It would give iPhone users the one thing
  their phone cannot produce. Effort M here, L there. Depends on that project and on its privacy
  rules for the aggregate.
- **11. Cell lookup for search and rescue.** The Android roadmap plans a search by cell identity
  that shows the tower, sector and distance band. It is a lookup, not a measurement, so it can
  work on iPhone and web unchanged. Build it once, in both, to one design. Effort M.
- **12. Change alerts.** "A new tower was licensed near a saved area." Needs a server job and push
  notifications. Effort L. Depends on item 5.
- **13. Web export and iPad layout.** Browser download for exports; a side panel on wide screens
  in place of the 600-point sheet. Effort M.
- **14. Decide the future of the Android build of this project.** It goes to Play's internal
  track as a draft. Either keep it as a test vehicle and say so, or stop building it and save the
  build minutes. Owner decision.

## Converge with Android

Keep one definition, with a test on each side that fails when they drift:

- The network-type classifier and refarming rules (already tested on both sides).
- The path-loss table and shared vectors (already pinned by hash).
- The signal rungs per technology. Add them to the shared vector file so I1 cannot recur.
- The export field names, units and null rules. Add a shared sample file both test suites read.
- Menu and chip labels, ads keyword head, brand colours, the user guide's structure.
- Saved-area file format, if item 5 is built, so a later sync is possible.

## Right to differ on iOS

- No connected tower, connection card, timing-advance ring, uploads or leaderboard. iOS does not
  expose cell information. Do not imitate these with guesses.
- Follow GPS started by hand, not automatic Driving Mode (ruling of 2026-08-26). No full-screen
  ads while driving follows from having no interstitials at all.
- Settings as a sheet, not a preferences screen.
- No rewarded ad on the support screen until a real ad unit exists.
- Lock Map resets each launch.
- The T O V letters on the app icon.

## Monetisation and retention

Consistent with the banner, the two ad-free purchases and donations.

- **Keep free:** the map, coverage, search and export. Export is the public-safety use and the
  best reason an agency recommends the app.
- **Finish the yearly product move.** Confirm in App Store Connect that the restorable yearly
  pass is on sale and the old consumable is not. Until then a customer can pay twice and cannot
  restore.
- **One place to buy, easy to find.** The support screen is already the single shop. Add the
  price of ad-free to the Settings row label so the offer is visible without opening it.
- **Paid extras that cost little:** more than two saved areas (item 5); extra export formats
  (KML and GPX for towers). Decide when item 5 ships, not before.
- **Retention without cell data:** saved areas and favourite towers give a reason to return;
  change alerts (item 12) give a reason to be notified. The weekly support prompt already exists;
  do not add more prompts.
- **Measure before changing ads:** record banner fill and eCPM per release. The ad unit ids for
  landscape exist and are unused; test whether a landscape unit earns more before adding any new
  format.

## Order of work

1. Item 1 and step 1 of item 2 in one release (small, visible, low risk).
2. Item 3 with the next App Store submission.
3. Items 2 (rest) and 4.
4. Item 5, then 6 or 7 by owner preference.
