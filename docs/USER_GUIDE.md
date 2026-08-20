# Aus Phone Towers (iPhone & Web) — User Guide

*Aus Phone Towers* (`phonetowers`) is a Flutter app for **iPhone** and **Web** that maps the
mobile phone towers across Australia. It downloads tower locations from ACMA / OpenCellID
datasets and draws each transmitter on a Google Map together with its estimated coverage polygon.

> **Note:** This iPhone/Web edition is a port of the Android app and currently has **fewer
> features**. In particular it does *not* yet identify the specific tower your phone is connected
> to, so there is no "Cell Information" bar, no timing‑advance ring and no crowd‑sourced
> observation markers yet. Those features are planned but not ported (see
> *Differences from the Android app* below).

## 1. The map

- **Tower markers** — one marker per transmitter. Instead of plain coloured pins, each tower is
  shown as the **carrier's logo icon** (Telstra, Optus, Vodafone, NBN, Dense Air, Other, or a
  generic non‑telco icon). Tap a marker for details.
- **Coverage polygons** — coloured shaded areas showing the estimated coverage of each antenna.
  The colour matches the carrier (see the legend below). Toggle the outline with **Show/Hide
  Borders**. Polygon opacity is boosted on satellite/hybrid map types and when **Follow GPS**
  (drive mode) is active, so coverage remains visible over dark imagery.
- **Coverage labels** — each tower's coverage carries a small text label showing its
  **frequency and technology** (e.g. `850 MHz 4G LTE`). The label sits right on the shaded
  polygon's outer line — anchored on the point of the outermost ring that is furthest from the
  tower, nudged just far enough out to clear the fill without floating away from it. Because HRP
  coverage rings are irregular (terrain, hills, sector directions), the label may appear at a
  different angle for each tower — that is expected. Tapping a tower redraws its coverage and
  refreshes the label position.
- **Your location** — a semi‑transparent azure dot (requires Location permission). Use the
  **Follow GPS** menu item to keep the map centred on you as you move ("drive mode").

## 2. Colour & symbol legend

Tower markers use carrier logo icons. The colours below are used for the **coverage polygons**
(fill and outline) and for the tower's icon where applicable.

| Carrier / type | Polygon colour (RGB) | Meaning |
|---|---|---|
| Telstra | Blue (0, 10, 255) | Telstra towers |
| Optus | Teal / Cyan (0, 127, 135) | Optus towers |
| Vodafone | Red (255, 0, 0) | Vodafone towers |
| Dense Air | Navy (17, 53, 79) | Dense Air small cells |
| NBN | Magenta / Violet (145, 15, 145) | NBN fixed‑wireless & mobile |
| Other | Azure (0, 127, 255) | Other providers (TPG, Lycamobile, Vivid Wireless, …) |
| Radio / TV / Civil / Pager / Aviation / CBRS | Pink (255, 177, 216) | Non‑telco transmitters |
| Your location | Azure dot | Your device's position (semi‑transparent) |

## 3. Toolbar menu (top‑right `⋯`)

The menu is grouped the same way as the Android app:

- **Reload Everything** — clear the map and re‑download all towers for the current area.
- **Follow GPS** — toggle "drive mode". When on, the map stays centred on your location as you
  move (uses more battery). When off, the map stops recentring.
- **Lock / Unlock Map** — freeze (or unfreeze) *all* camera movement: pan, zoom, rotate and tilt
  gestures, the built‑in "my location" button, Follow GPS's auto‑recentring, and Search's
  jump‑to‑result. Useful when you want to screenshot or study a fixed area of coverage without
  anything nudging the camera.
- **Rotating Map** — choose how the map's bearing follows you while **Follow GPS** is on
  (rotation is only ever applied on a Follow‑GPS location update, so it has no effect while
  Follow GPS is off):
  - **Travel Direction** (default) — the map rotates to face the direction you're travelling,
    based on your GPS course‑over‑ground.
  - **Phone Orientation** — the map rotates to face the direction you point the phone, based on
    the device's compass/magnetometer. Useful when stationary and lining up with a tower you can
    see. If the device has no compass, a message is shown and the map falls back to not rotating
    for this reading.
  - **Disable Rotation** — the map's bearing is never changed automatically.
- **Show / Hide Borders** — toggle the radiation polygon outlines.
- **Search Sites** — find a specific tower / site.
- **Map Mode** — Terrain / Hybrid / Satellite / Normal base map.
- **Hiding Menu** — a sub‑menu:
  - **Hide / Show Radiation on Click** — when on (default), tapping a tower draws its coverage
    polygon; when off, tapping does nothing.
  - **Disable frequency refarming** — when ticked, legacy 3G (UMTS) licences that now run as 4G/5G
    (e.g. band‑refarmed 900/2100 MHz) are shown at their *literal* licence type (3G UMTS) instead
    of being re‑classified to their current reuse (4G LTE). Changing this reloads the towers.
  - **Multi‑Tower Coverage** — when ticked, tapping additional towers *adds* their coverage
    polygons to the map instead of replacing the previous tower's coverage. Turn it off (and tap
    any tower) to clear all accumulated coverage.
- **Export Data** — a sub‑menu:
  - **Export Towers (GeoJSON)** — one point per tower (carrier, generation, frequency, azimuth,
    height, EIRP, …) for every tower currently on the map.
  - **Export Towers (CSV)** — the same data as a CSV.
  - **Export Coverage (GeoJSON)** — the coverage polygons currently drawn on the map (with their
    tower/device details) to GeoJSON, CSV and KML, timestamped, for use in QGIS / Google Earth.
- **Polygon Precision** — how many points make up each coverage ring: **Low** (faster, blockier),
  **Medium** (default) or **High** (smoother, more points). Applies to newly drawn coverage.
- **Remove Ads** — buy *1 Year Ad‑Free* or *Permanent Ad‑Free* to remove the banner
  advertisement. The purchase is restored automatically on future launches (tap **Restore
  Purchases** if needed). The yearly option reverts to showing ads after 12 months and can be
  bought again; the permanent option never expires.
- **Donate** — support development with a one‑off in‑app purchase (small / medium / large).
  Donations are repeatable and do **not** remove ads (not shown on the Web build).
  - **Support the App** — the last item in the Donate menu; opens a full‑screen "Support Aus
    Phone Towers" prompt with the same donation options plus the ad‑free purchases (hidden if
    you're already ad‑free), and a **Maybe later** button to dismiss. The same screen is also
    shown automatically about once a week.
- **Problems Menu** — a sub‑menu:
  - **Developer / Regular Mode** — show extra diagnostic overlays.
  - **User Guide** — opens this page (the top‑right menu item that previously opened the wrong
    page has been fixed).
  - **Report Problem** — take a screenshot to send feedback.
  - **Links** — Rate App, AusPhoneTowers.com.au, iOS App Store, Source Code.
- **Rate App** — requests the native App Store review prompt (where the OS allows it), and always
  also opens the App Store listing directly, since Apple silently disables the native prompt
  outside a real App Store install (TestFlight, sandbox, debug builds).
- **Close App** — Android only; exits the app. Not shown on iPhone/Web, since neither platform
  permits an app to exit itself.

## 4. Navigation‑drawer filters

Open the drawer (top‑left) to control what is shown:

- **Licencees** — Telstra, Optus, Vodafone, NBN, Other. (Dense Air is downloaded but not yet a toggle.)
- **2G / 3G / 4G / 5G** — GSM, UMTS, LTE, NR.
- **Multiplex Type** — NOT LTE, FD‑LTE, TD‑LTE.
- **Frequencies** — < 700 MHz, 700–1000 MHz, 1.0–2.4 GHz, 2.4–3.8 GHz, ≥ 3.8 GHz.
- **Radiation Models** (city density) — Metropolitan, Urban, Suburban, Open.
- **Signal Strength** — Maximum, Strong, Good, Weak (default: Good).
- **Transmitter Type** — Telecommunications, Radio, TV, Civil, Pager, CBRS, Aviation.

## 5. Important behaviours

- **Zoom to load** — towers are downloaded in tiles as you pan / zoom. Zoom in
  ("Zoom in further to download towers…") to populate an area.
- **Location is optional** — the app works without granting location; you just won't see your
  position or get location‑based centring.
- **Web vs iPhone** — the Web build hides the Donate buttons (App Store purchases aren't available
  in a browser) and uses web‑optimised icon assets. Rate App uses the in‑app review prompt where
  supported, and always also opens the App Store listing directly as a guaranteed fallback.
- **Coverage polygons are estimates** — generated from ACMA licence / HRP data and a radiation
  model, not official carrier coverage maps.
- **No connected‑tower features yet** — unlike the Android app, this edition does not yet show
  which tower you are using, the Cell Information bar, the timing‑advance ring, or crowd‑sourced
  observation markers.

## 6. Differences from the Android app

| Feature | Android | iPhone / Web |
|---|---|---|
| Tower markers | Coloured pins (rotated) | Carrier logo icons |
| Connected‑tower / Cell Info bar | Yes | Not yet |
| Timing‑advance ring | Yes | Not yet |
| Observation markers (yellow / orange) | Yes | Not yet |
| Follow‑GPS drive mode | Yes | Yes |
| Rotating Map (Travel Direction / Phone Orientation / Disable Rotation) | Yes | Yes |
| Frequency refarming toggle (literal vs reuse) | Yes | Yes |
| Polygon precision (point count) control | Yes | Yes |
| Export Towers (GeoJSON/CSV) | Yes | Yes |
| Export Coverage (GeoJSON/CSV/KML) | Yes | Yes (GeoJSON/CSV/KML) |
| Shows your location dot | Yes | Yes (azure dot) |

## 7. Feedback & support

Use **Report Problem** (in the **Problems Menu**) or the **Problems Menu → Links** (Rate App /
AusPhoneTowers.com.au / iOS App Store / Source Code). The Web/iOS app is still under active
development — feedback is welcome at bitbot@bitbot.com.au.
