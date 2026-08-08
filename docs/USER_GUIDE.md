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
  Borders**.
- **Your location** — a semi‑transparent azure dot (requires Location permission). The app can
  centre the map on you; there is no automatic "follow while driving" mode yet.

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

- **Show / Hide Borders** — toggle the radiation polygon outlines.
- **Search Sites** — find a specific tower / site.
- **Reload Everything** — clear the map and re‑download all towers for the current area.
- **Map Mode** — Terrain / Hybrid / Satellite / Normal base map.
- **Hiding Menu** — Hide / Show Radiation on Click (draw a tower's coverage polygon when you tap it).
- **Remove Ads** — subscribe to remove advertising (currently hidden from the menu; ads still
  show for non‑subscribers).
- **Donate** — support development with an in‑app purchase (not shown on the Web build).
- **Developer / Regular Mode** — show extra diagnostic overlays.
- **Report Problem** — take a screenshot to send feedback.
- **Export** — save the coverage polygons currently drawn on the map (with their tower and device
  details) to **GeoJSON**, **CSV** and **KML** files in the app's documents folder. The three files
  are timestamped and can be opened in GIS tools such as QGIS or Google Earth. If no polygons are
  drawn, nothing is exported.
- **Links** — Rate App, AusPhoneTowers.com.au, iOS App Store, Source Code.
- **User Guide** — opens this page.

## 4. Navigation‑drawer filters

Open the drawer (top‑left) to control what is shown:

- **Licencees** — Telstra, Optus, Vodafone, NBN, Other. (Dense Air is downloaded but not yet a toggle.)
- **2G / 3G / 4G / 5G** — GSM, UMTS, LTE, NR.
- **Multiplex Type** — NOT LTE, FD‑LTE, TD‑LTE.
- **Frequencies** — < 700 MHz, 700–1000 MHz, 1.0–2.4 GHz, 2.4–3.8 GHz, ≥ 3.8 GHz.
- **Radiation Models** (city density) — Metropolitan, Urban, Suburban, Open.
- **Signal Strength** — Maximum, Strong, Good, Weak.
- **Transmitter Type** — Telecommunications, Radio, TV, Civil, Pager, CBRS, Aviation.

## 5. Important behaviours

- **Zoom to load** — towers are downloaded in tiles as you pan / zoom. Zoom in
  ("Zoom in further to download towers…") to populate an area.
- **Location is optional** — the app works without granting location; you just won't see your
  position or get location‑based centring.
- **Web vs iPhone** — the Web build hides the Donate buttons (App Store purchases aren't available
  in a browser) and uses web‑optimised icon assets. Rate App uses the in‑app review prompt where
  supported.
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
| Follow‑GPS drive mode | Yes | Not yet |
| Shows your location dot | Yes | Yes (azure dot) |

## 7. Feedback & support

Use **Report Problem** (screenshot) or the **Links** menu (Rate App / AusPhoneTowers.com.au /
iOS App Store / Source Code). The Web/iOS app is still under active development — feedback is
welcome at bitbot@bitbot.com.au.
