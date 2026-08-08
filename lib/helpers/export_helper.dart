import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../model/device_detail.dart';
import '../model/site.dart';
import '../utils/polygon_container.dart';
import 'let_type_helper.dart';
import 'network_type_helper.dart';
import 'polygon_helper.dart';
import 'telco_helper.dart';

/// Exports the currently drawn signal-coverage polygons (and their on-tower
/// metadata) to GeoJSON, CSV and KML files in the app documents folder.
///
/// This mirrors the Android app's ExportKMLAsyncTask / ExportCSVAsyncTask /
/// ExportKMZAsyncTask behaviour, where every polygon (each signal-strength
/// ring) is exported along with the site and device properties.
class ExportHelper {
  /// Exports all signal polygons currently on the map.
  /// Returns the list of written file paths (GeoJSON, CSV, KML).
  static Future<List<String>> exportSignalPolygons() async {
    // Gather every (site, device, polygon) triple currently drawn on the map.
    final List<_ExportEntry> entries = <_ExportEntry>[];
    for (final MapEntry<Site, Map<DeviceDetails, Set<PolygonContainer>>> siteEntry
        in PolygonHelper.sitesPolygons.entries) {
      final Site site = siteEntry.key;
      for (final MapEntry<DeviceDetails, Set<PolygonContainer>> deviceEntry
          in siteEntry.value.entries) {
        final DeviceDetails device = deviceEntry.key;
        for (final PolygonContainer container in deviceEntry.value) {
          entries.add(_ExportEntry(site: site, device: device, polygon: container));
        }
      }
    }

    if (entries.isEmpty) return <String>[];

    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp = _timeStamp();
    final List<String> paths = <String>[];

    // GeoJSON
    final File geoFile = File(p.join(dir.path, 'signal_polygons_$stamp.geojson'));
    await geoFile.writeAsString(_toGeoJson(entries), flush: true);
    paths.add(geoFile.path);

    // CSV
    final File csvFile = File(p.join(dir.path, 'signal_polygons_$stamp.csv'));
    await csvFile.writeAsString(_toCsv(entries), flush: true);
    paths.add(csvFile.path);

    // KML
    final File kmlFile = File(p.join(dir.path, 'signal_polygons_$stamp.kml'));
    await kmlFile.writeAsString(_toKml(entries), flush: true);
    paths.add(kmlFile.path);

    return paths;
  }

  static String _timeStamp() {
    final DateTime now = DateTime.now();
    return '${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String _coords(List<LatLng> points) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < points.length; i++) {
      if (i > 0) sb.write(' ');
      sb.write('${points[i].longitude.toStringAsFixed(6)},'
          '${points[i].latitude.toStringAsFixed(6)},0');
    }
    return sb.toString();
  }

  static String _coordLine(List<LatLng> points) {
    // GeoJSON / KML ring: close the ring by repeating the first point.
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < points.length; i++) {
      if (i > 0) sb.write(' ');
      sb.write('${points[i].longitude.toStringAsFixed(6)} '
          '${points[i].latitude.toStringAsFixed(6)} 0');
    }
    if (points.isNotEmpty) {
      sb.write(' ${points[0].longitude.toStringAsFixed(6)} '
          '${points[0].latitude.toStringAsFixed(6)} 0');
    }
    return sb.toString();
  }

  static Map<String, dynamic> _properties(_ExportEntry e) {
    final Site site = e.site;
    final DeviceDetails device = e.device;
    final Polygon po = e.polygon.polygon;
    return <String, dynamic>{
      'name': site.getNameFormatted(),
      'operatorName': TelcoHelper.getName(site.getTelco()),
      'siteId': site.siteId,
      'networkType': NetworkTypeHelper.resolveNetworkToName(device.getNetworkType()),
      'lteType': LteTypeHelper.getFirstTwoChars(device.getLteType()),
      'frequency': (device.frequency ?? 0) / 1000 / 1000,
      'bandwidth': (device.bandwidth ?? 0) / 1000 / 1000,
      'emission': device.emission ?? '',
      'eirp': device.eirp,
      'azimuth': device.azimuth,
      'towerHeight': device.getTowerHeight(),
      'signalStrengthOrder': e.polygon.order,
      'colorARGB': po.fillColor.value,
      'strokeWidth': po.strokeWidth,
      'fill': po.fillColor.alpha > 0,
      'stroke': po.strokeColor.alpha > 0,
    };
  }

  static String _toGeoJson(List<_ExportEntry> entries) {
    final List<Map<String, dynamic>> features = <Map<String, dynamic>>[];
    for (final _ExportEntry e in entries) {
      final List<LatLng> pts = e.polygon.polygon.points;
      final List<List<double>> ring = pts
          .map((LatLng p) => <double>[p.longitude, p.latitude])
          .toList();
      if (ring.isNotEmpty) {
        ring.add(<double>[ring[0][0], ring[0][1]]); // close ring
      }
      features.add(<String, dynamic>{
        'type': 'Feature',
        'geometry': <String, dynamic>{
          'type': 'Polygon',
          'coordinates': <List<List<double>>>[ring],
        },
        'properties': _properties(e),
      });
    }
    return JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'type': 'FeatureCollection',
      'features': features,
    });
  }

  static String _csvHeader() {
    return 'name,operatorName,siteId,networkType,lteType,frequency,'
        'bandwidth,emission,eirp,azimuth,towerHeight,signalStrengthOrder,'
        'colorARGB,strokeWidth,fill,stroke,coordinates';
  }

  static String _toCsv(List<_ExportEntry> entries) {
    final StringBuffer sb = StringBuffer();
    sb.writeln(_csvHeader());
    for (final _ExportEntry e in entries) {
      final Map<String, dynamic> props = _properties(e);
      final List<String> values = <String>[
        '"${(props['name'] as String).replaceAll('"', '""')}"',
        '"${props['operatorName']}"',
        '${props['siteId']}',
        '"${props['networkType']}"',
        '"${props['lteType']}"',
        '${props['frequency']}',
        '${props['bandwidth']}',
        '"${props['emission']}"',
        '${props['eirp']}',
        '${props['azimuth']}',
        '${props['towerHeight']}',
        '${props['signalStrengthOrder']}',
        '${props['colorARGB']}',
        '${props['strokeWidth']}',
        '${props['fill']}',
        '${props['stroke']}',
        '"${_coords(e.polygon.polygon.points)}"',
      ];
      sb.writeln(values.join(','));
    }
    return sb.toString();
  }

  static String _toKml(List<_ExportEntry> entries) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    sb.writeln('  <Document>');
    sb.writeln('    <name>Aus Phone Towers Signal Polygons</name>');
    for (final _ExportEntry e in entries) {
      final Map<String, dynamic> props = _properties(e);
      sb.writeln('    <Placemark>');
      sb.writeln('      <name>${_xml(props['operatorName'])} '
          '${_xml(props['networkType'])} ${props['frequency']} MHz</name>');
      sb.writeln('      <ExtendedData>');
      for (final MapEntry<String, dynamic> kv in props.entries) {
        if (kv.key == 'coordinates') continue;
        sb.writeln('        <Data name="${kv.key}">'
            '<value>${_xml(kv.value)}</value></Data>');
      }
      sb.writeln('      </ExtendedData>');
      sb.writeln('      <Polygon>');
      sb.writeln('        <outerBoundaryIs>');
      sb.writeln('          <LinearRing>');
      sb.writeln('            <coordinates>'
          '${_coordLine(e.polygon.polygon.points)}</coordinates>');
      sb.writeln('          </LinearRing>');
      sb.writeln('        </outerBoundaryIs>');
      sb.writeln('      </Polygon>');
      sb.writeln('    </Placemark>');
    }
    sb.writeln('  </Document>');
    sb.writeln('</kml>');
    return sb.toString();
  }

  static String _xml(dynamic value) {
    final HtmlEscape escape = HtmlEscape(HtmlEscapeMode.attribute);
    return escape.convert(value.toString());
  }
}

class _ExportEntry {
  _ExportEntry({required this.site, required this.device, required this.polygon});

  final Site site;
  final DeviceDetails device;
  final PolygonContainer polygon;
}