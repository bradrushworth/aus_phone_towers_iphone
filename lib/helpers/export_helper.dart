import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path/path.dart' as p;

import '../model/device_detail.dart';
import '../model/overlay.dart';
import '../model/site.dart';
import '../restful/get_licenceHRP.dart' show CityDensity;
import '../restful/site_terrain_batch.dart';
import '../utils/polygon_container.dart';
import 'export_delivery_io.dart' if (dart.library.js_interop) 'export_delivery_web.dart';
import 'export_feature.dart';
import 'export_file.dart';
import 'network_type_helper.dart';
import 'polygon_helper.dart';
import 'site_helper.dart';
import 'telco_helper.dart';

/// The file formats the menu can produce.
enum ExportFormat {
  geojson('.geojson', 'application/geo+json'),
  csv('.csv', 'text/csv'),
  kml('.kml', 'application/vnd.google-earth.kml+xml');

  const ExportFormat(this.extension, this.mimeType);
  final String extension;
  final String mimeType;
}

/// One row of the Export Data menu.
enum ExportChoice { towersGeoJson, towersCsv, coverageGeoJson, coverageKml }

/// Exports the towers on the map, and the signal-coverage polygons currently drawn, as GeoJSON,
/// CSV or KML, then hands the file to the share sheet (iOS/Android) or the browser (web).
///
/// The tower contract (columns, names, order, units) is shared with the Android app; see
/// export_feature.dart and AGENTS.md "Export Data".
class ExportHelper {
  static const String kExportsFolderName = kExportsFolder;
  static const Duration kExportRetention = kExportsRetention;

  static bool isExpired(DateTime modified, DateTime now) => isExportExpired(modified, now);

  /// Which files a menu row writes: exactly the one format it names, never more.
  static List<ExportFormat> formatsFor(ExportChoice choice) {
    switch (choice) {
      case ExportChoice.towersGeoJson:
      case ExportChoice.coverageGeoJson:
        return const <ExportFormat>[ExportFormat.geojson];
      case ExportChoice.towersCsv:
        return const <ExportFormat>[ExportFormat.csv];
      case ExportChoice.coverageKml:
        return const <ExportFormat>[ExportFormat.kml];
    }
  }

  static bool isTowers(ExportChoice c) =>
      c == ExportChoice.towersGeoJson || c == ExportChoice.towersCsv;

  /// The message shown after a successful export: the file names only (never the sandbox path).
  static String describeSavedFiles(List<String> paths,
      {required bool isIOS, bool isWeb = false}) {
    final StringBuffer sb = StringBuffer();
    if (isWeb) {
      sb.write('Downloaded:\n');
    } else if (isIOS) {
      sb.write('Saved to Files → On My iPhone → Aus Phone Towers → Exports:\n');
    } else {
      sb.write("Saved to the app's $kExportsFolderName folder:\n");
    }
    for (final String path in paths) {
      sb.write('${p.basename(path)}\n');
    }
    return sb.toString().trimRight();
  }

  /// Builds and delivers the export for [choice]. Returns the file names, or an empty list when
  /// there is nothing to export. Call on the UI thread (it reads map objects).
  static Future<List<String>> export(ExportChoice choice, {Rect? shareOrigin}) async {
    final List<ExportFeature> features;
    if (isTowers(choice)) {
      final List<Site> sites = visibleTowerSites();
      // Ground heights the map has not loaded yet are fetched now, in one bounded batch. A
      // failure only leaves those towers unverified.
      final Map<String, int> fetched = await SiteTerrainBatchFetcher.fetchGround(
          sites
              .where((Site s) => s.terrainGroundM == null && !s.terrainLoaded)
              .map((Site s) => s.siteId),
          PolygonHelper.api);
      features = sites.map((Site s) => buildTowerFeature(s, fetchedGround: fetched)).toList();
    } else {
      features = collectCoverageFeatures();
    }
    if (features.isEmpty) return <String>[];

    final String stamp = _timeStamp();
    final String label = isTowers(choice) ? 'Towers' : 'Coverage';
    final List<ExportFile> files = <ExportFile>[];
    for (final ExportFormat format in formatsFor(choice)) {
      files.add(ExportFile(
        name: 'AusPhoneTowers_${label}_$stamp${format.extension}',
        text: _render(format, features, isTowers(choice)),
        mimeType: format.mimeType,
      ));
    }
    await deliverExportFiles(files, shareOrigin: shareOrigin);
    return files.map((ExportFile f) => f.name).toList();
  }

  static String _render(ExportFormat format, List<ExportFeature> features, bool towers) {
    switch (format) {
      case ExportFormat.geojson:
        return GeoJsonWriter.write(features,
            generator: 'Aus Phone Towers', generated: _isoNow());
      case ExportFormat.csv:
        return CsvWriter.write(TowerExport.csvColumns, features);
      case ExportFormat.kml:
        return _toKml(features);
    }
  }

  static String _isoNow() {
    final DateTime n = DateTime.now().toUtc();
    return '${n.year}-${_pad(n.month)}-${_pad(n.day)}T${_pad(n.hour)}:${_pad(n.minute)}:'
        '${_pad(n.second)}Z';
  }

  static String _timeStamp() {
    final DateTime now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String _hex(Telco telco) {
    final int argb = TelcoHelper.getColor(telco, 255).toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static String? _density(CityDensity? d) => TowerExport.cityDensityValue(d?.name);

  /// One feature per site whose marker is visible (so the filters are respected), built from the
  /// transmitters that pass the filters. Sorted by telco then site id so repeat exports compare.
  static List<Site> visibleTowerSites() {
    final Set<Site> sites = <Site>{};
    for (final MapOverlay overlay in SiteHelper.globalListMapOverlay) {
      final Site? site = overlay.site;
      if (site == null || overlay.marker?.visible != true) continue;
      if (site.latitude == null || site.longitude == null) continue;
      sites.add(site);
    }
    final List<Site> sorted = sites.toList()
      ..sort((Site a, Site b) {
        final int t = TelcoHelper.getName(a.getTelco()).compareTo(TelcoHelper.getName(b.getTelco()));
        return t != 0 ? t : (a.siteId ?? '').compareTo(b.siteId ?? '');
      });
    return sorted;
  }

  /// [fetchedGround] holds terrain-model ground heights fetched at export time (site id to
  /// metres); the site itself is not modified, so map drawing is unaffected.
  static ExportFeature buildTowerFeature(Site site,
      {Map<String, int> fetchedGround = const <String, int>{}}) {
    final List<DeviceDetails> all = site.getDeviceDetailsMobile();
    List<DeviceDetails> visible = all.where(site.isDeviceVisible).toList();
    // A visible marker with no visible transmitters is stale; fall back to everything known.
    if (visible.isEmpty) visible = List<DeviceDetails>.of(all);
    return TowerExport.buildFeature(
      siteId: site.siteId,
      name: site.name,
      telco: TelcoHelper.getName(site.getTelco()),
      latitude: site.latitude!,
      longitude: site.longitude!,
      acmaElevationText: site.elevation,
      demGroundM: site.terrainGroundM ?? fetchedGround[site.siteId],
      visibleDevices: visible.map((DeviceDetails d) {
        final NetworkType nt = d.getNetworkType();
        return TowerDeviceInput(
          heightM: d.height,
          technology: NetworkTypeHelper.resolveNetworkToName(nt),
          technologyOrder: nt.index,
          frequencyMhz: d.frequency == null ? null : d.frequency! ~/ 1000 ~/ 1000,
        );
      }).toList(),
      allDeviceHeights: all.map((DeviceDetails d) => d.height),
      state: site.state,
      postcode: site.postcode,
      cityDensity: _density(site.getCityDensity()),
      active: site.active,
      markerColour: _hex(site.getTelco()),
    );
  }

  /// Every ring currently drawn (filtered-out polygons are removed from the map, not hidden).
  static List<ExportFeature> collectCoverageFeatures() {
    final List<ExportFeature> features = <ExportFeature>[];
    final List<Site> sites = PolygonHelper.sitesPolygons.keys.toList()
      ..sort((Site a, Site b) {
        final int t = TelcoHelper.getName(a.getTelco()).compareTo(TelcoHelper.getName(b.getTelco()));
        return t != 0 ? t : (a.siteId ?? '').compareTo(b.siteId ?? '');
      });
    for (final Site site in sites) {
      final Map<DeviceDetails, Set<PolygonContainer>>? devices = PolygonHelper.sitesPolygons[site];
      if (devices == null || site.latitude == null || site.longitude == null) continue;
      for (final MapEntry<DeviceDetails, Set<PolygonContainer>> e in devices.entries) {
        final List<PolygonContainer> rings = e.value.toList()
          ..sort((PolygonContainer a, PolygonContainer b) => a.order.compareTo(b.order));
        for (final PolygonContainer c in rings) {
          final Polygon po = c.polygon;
          if (!po.visible || po.points.length < 3) continue;
          features.add(_coverageFeature(site, e.key, c.order, po));
        }
      }
    }
    return features;
  }

  static ExportFeature _coverageFeature(Site site, DeviceDetails d, int order, Polygon po) {
    final NetworkType nt = d.getNetworkType();
    return CoverageExport.buildFeature(CoverageInput(
      siteId: site.siteId,
      siteName: site.name,
      telco: TelcoHelper.getName(site.getTelco()),
      latitude: site.latitude!,
      longitude: site.longitude!,
      networkType: NetworkTypeHelper.resolveNetworkToName(nt),
      networkTechnology: nt.name,
      isRsrp: NetworkTypeHelper.isRsrp(nt),
      signalBars: NetworkTypeHelper.getNetworkBars(nt),
      ringOrder: order,
      frequencyMhz: (d.frequency ?? 0) ~/ 1000 ~/ 1000,
      bandwidthMhz: (d.bandwidth ?? 0) / 1000000.0,
      emission: d.emission,
      eirpW: d.eirp,
      azimuthDeg: d.azimuth,
      heightM: d.height,
      antennaId: d.antennaId,
      deviceRegistrationIdentifier: d.deviceRegistrationIdentifier,
      radiationModel: _density(site.getCityDensity()),
      terrainAware: PolygonHelper.calculateTerrain,
      colour: _hex(site.getTelco()),
      ring: po.points.map((LatLng l) => <double>[l.latitude, l.longitude]).toList(),
    ));
  }

  static String _coordLine(List<List<double>> ring) {
    final StringBuffer sb = StringBuffer();
    for (final List<double> pt in ring) {
      if (sb.isNotEmpty) sb.write(' ');
      sb.write('${ExportNumbers.formatNumber(pt[1])},${ExportNumbers.formatNumber(pt[0])},0');
    }
    if (ring.isNotEmpty) {
      sb.write(' ${ExportNumbers.formatNumber(ring[0][1])},'
          '${ExportNumbers.formatNumber(ring[0][0])},0');
    }
    return sb.toString();
  }

  static String _toKml(List<ExportFeature> features) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    sb.writeln('  <Document>');
    sb.writeln('    <name>Aus Phone Towers Signal Polygons</name>');
    for (final ExportFeature f in features) {
      sb.writeln('    <Placemark>');
      sb.writeln('      <name>${_xml(f.get('title'))}</name>');
      sb.writeln('      <description>${_xml(f.get('description'))}</description>');
      sb.writeln('      <ExtendedData>');
      for (final MapEntry<String, Object?> kv in f.properties.entries) {
        if (kv.key == 'title' || kv.key == 'description') continue;
        final Object? v = kv.value;
        final String text = v == null
            ? ''
            : (v is num ? ExportNumbers.formatNumber(v) : v.toString());
        sb.writeln('        <Data name="${_xml(kv.key)}"><value>${_xml(text)}</value></Data>');
      }
      sb.writeln('      </ExtendedData>');
      sb.writeln('      <Polygon>');
      sb.writeln('        <outerBoundaryIs>');
      sb.writeln('          <LinearRing>');
      sb.writeln('            <coordinates>${_coordLine(f.coordinates)}</coordinates>');
      sb.writeln('          </LinearRing>');
      sb.writeln('        </outerBoundaryIs>');
      sb.writeln('      </Polygon>');
      sb.writeln('    </Placemark>');
    }
    sb.writeln('  </Document>');
    sb.writeln('</kml>');
    return sb.toString();
  }

  static String _xml(Object? value) =>
      const HtmlEscape(HtmlEscapeMode.attribute).convert((value ?? '').toString());
}
