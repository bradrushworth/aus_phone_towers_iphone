// Pure (no Flutter, no platform, no model imports) building blocks of the Export Data feature:
// the feature holder, the tower and coverage property sets, and the GeoJSON and CSV writers.
//
// THE TOWER CONTRACT IS SHARED WITH THE ANDROID APP. Search and rescue agencies load the tower
// export into CalTopo / ArcGIS Pro and run a viewshed from it, so the column names, their order,
// the units and the number formatting must stay identical to the Android app's
// `ExportHelper.TOWER_CSV_COLUMNS` / `buildTowerFeature` (aus_phone_towers_java). Change both
// apps together. See AGENTS.md "Export Data".

import 'dart:convert';

/// One exported map feature: a tower point or a coverage polygon.
///
/// [coordinates] are `[latitude, longitude]` pairs (the order used everywhere else in the app);
/// the GeoJSON writer flips them into the `[longitude, latitude]` order RFC 7946 requires.
/// Property values may be null; a null is JSON `null` and an empty CSV cell, never the text
/// `null`.
class ExportFeature {
  ExportFeature._(this.isPolygon, this.coordinates);

  /// A tower.
  factory ExportFeature.point(double latitude, double longitude) =>
      ExportFeature._(false, <List<double>>[
        <double>[latitude, longitude]
      ]);

  /// A coverage polygon. The ring need not be closed; the writers close it.
  factory ExportFeature.polygon(List<List<double>> ring) =>
      ExportFeature._(true, List<List<double>>.from(ring));

  final bool isPolygon;
  final List<List<double>> coordinates;

  /// Insertion order is the output order.
  final Map<String, Object?> properties = <String, Object?>{};

  ExportFeature put(String key, Object? value) {
    properties[key] = value;
    return this;
  }

  Object? get(String key) => properties[key];
}

/// Number and text formatting shared by every writer. Locale independent by construction:
/// Dart's number formatting never consults the device locale, but keep it in one place anyway.
class ExportNumbers {
  ExportNumbers._();

  /// Decimal places kept for fractional numbers (and coordinates). 6 dp is about 0.1 m.
  static const int decimalPlaces = 6;

  /// Integers plainly, fractions to [decimalPlaces] with trailing zeros stripped, never
  /// scientific notation. NaN and infinity give an empty string.
  static String formatNumber(num? value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    final double d = value.toDouble();
    if (d.isNaN || d.isInfinite) return '';
    String text = d.toStringAsFixed(decimalPlaces);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    }
    if (text == '-0') text = '0';
    return text;
  }

  /// Rounds to [places] decimals; null for NaN or infinity.
  static double? round(double value, int places) {
    if (value.isNaN || value.isInfinite) return null;
    double factor = 1;
    for (int i = 0; i < places; i++) {
      factor *= 10;
    }
    return (value * factor).roundToDouble() / factor;
  }
}

/// The tower export: columns, row building and the elevation cross-check.
class TowerExport {
  TowerExport._();

  /// Columns of the tower CSV, in order; the same names are the GeoJSON property names.
  /// The first 17 are Android's `TOWER_CSV_COLUMNS` exactly; the last three are the terrain
  /// cross-check fields added to both apps on 2026-11-20 (Android audit A16).
  static const List<String> csvColumns = <String>[
    'site_id',
    'name',
    'telco',
    'latitude',
    'longitude',
    'ground_elevation_m',
    'antenna_height_max_m',
    'antenna_height_avg_m',
    'antenna_height_min_m',
    'antenna_top_elevation_m',
    'technologies',
    'frequencies_mhz',
    'transmitter_count',
    'state',
    'postcode',
    'city_density',
    'active',
    'ground_elevation_dem_m',
    'elevation_check',
    'antenna_height_all_max_m',
  ];

  /// The ACMA site elevation and the terrain-model ground height may differ by this much
  /// (metres) before the export flags the site as `differs`.
  static const double elevationToleranceM = 30;

  static const String checkOk = 'ok';
  static const String checkDiffers = 'differs';
  static const String checkUnverified = 'unverified';

  /// `ok` when both grounds are present and within [elevationToleranceM] of each other,
  /// `differs` when both are present and further apart, `unverified` when either is missing.
  static String elevationCheck(double? acmaGroundM, num? demGroundM) {
    if (acmaGroundM == null || demGroundM == null) return checkUnverified;
    return (acmaGroundM - demGroundM).abs() <= elevationToleranceM ? checkOk : checkDiffers;
  }

  /// The ACMA ground elevation is a string and is sometimes blank or not a number.
  static double? parseElevation(String? elevation) {
    if (elevation == null) return null;
    final String trimmed = elevation.trim();
    if (trimmed.isEmpty) return null;
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return parsed;
  }

  /// The ACMA site name with HTML entities decoded and whitespace flattened onto one line so it
  /// survives a CSV cell.
  static String formatName(String? name) {
    if (name == null) return '';
    String text = name
        .replaceAllMapped(RegExp(r'&#(\d+);'), (Match m) {
          final int? code = int.tryParse(m.group(1)!);
          return code == null || code > 0x10FFFF ? m.group(0)! : String.fromCharCode(code);
        })
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// For example `3G/4G/5G`; the caller passes the labels already in oldest-first order.
  static String joinTechnologies(Iterable<String> orderedTechnologies) =>
      orderedTechnologies.join('/');

  /// For example `850;1800;2100` (MHz, ascending, no duplicates).
  static String joinFrequencies(Iterable<int> frequenciesMhz) =>
      (frequenciesMhz.toSet().toList()..sort()).join(';');

  /// The Android city-density names (`CityDensity.getValue`), from the Dart enum's name.
  static String? cityDensityValue(String? enumName) {
    switch (enumName) {
      case 'METRO':
        return 'Metropolitan';
      case 'URBAN':
        return 'Urban';
      case 'MEDIUM':
        return 'Medium';
      case 'SUBURBAN':
        return 'Suburban';
      case 'OPEN':
        return 'Open';
    }
    return null;
  }

  /// Builds the one exported feature for a site.
  ///
  /// Heights are the raw ACMA antenna heights in metres above ground (`DeviceDetails.height`),
  /// ignoring anything not above zero: NEVER `DeviceDetails.getTowerHeight()`, which floors at
  /// 10 m for signal modelling and would overstate short towers. Maximum, average and minimum
  /// are over [visibleDevices], the transmitters under the current filters.
  /// `antenna_height_all_max_m` is over [allDeviceHeights], every transmitter of the site
  /// whatever the filters. `antenna_top_elevation_m` is the number a viewshed wants for the
  /// observer: ground elevation plus the tallest visible antenna.
  static ExportFeature buildFeature({
    required String? siteId,
    required String? name,
    required String? telco,
    required double latitude,
    required double longitude,
    required String? acmaElevationText,
    required int? demGroundM,
    required List<TowerDeviceInput> visibleDevices,
    required Iterable<int?> allDeviceHeights,
    required String? state,
    required String? postcode,
    required String? cityDensity,
    required bool active,
    String? markerColour,
  }) {
    int? maxHeight;
    int? minHeight;
    int totalHeight = 0;
    int heightCount = 0;
    final Map<int, String> technologies = <int, String>{};
    final Set<int> frequencies = <int>{};
    for (final TowerDeviceInput device in visibleDevices) {
      if (device.technology != null) {
        technologies[device.technologyOrder] = device.technology!;
      }
      if (device.frequencyMhz != null) frequencies.add(device.frequencyMhz!);
      final int? h = device.heightM;
      if (h != null && h > 0) {
        maxHeight = maxHeight == null || h > maxHeight ? h : maxHeight;
        minHeight = minHeight == null || h < minHeight ? h : minHeight;
        totalHeight += h;
        heightCount++;
      }
    }
    int? allMax;
    for (final int? h in allDeviceHeights) {
      if (h != null && h > 0) allMax = allMax == null || h > allMax ? h : allMax;
    }

    final double? heightAvg =
        heightCount > 0 ? ExportNumbers.round(totalHeight / heightCount, 1) : null;
    final double? ground = parseElevation(acmaElevationText);
    final double? antennaTop = (ground != null && maxHeight != null)
        ? ExportNumbers.round(ground + maxHeight, 1)
        : null;
    final List<int> orderKeys = technologies.keys.toList()..sort();
    final String technologyList =
        joinTechnologies(orderKeys.map((int k) => technologies[k]!));
    final String cleanName = formatName(name);

    final ExportFeature feature = ExportFeature.point(latitude, longitude);
    feature
        .put('title', cleanName)
        .put(
            'description',
            _describe(telco, siteId, maxHeight, ground, antennaTop, technologyList))
        .put('site_id', siteId)
        .put('name', cleanName)
        .put('telco', telco)
        .put('latitude', latitude)
        .put('longitude', longitude)
        .put('ground_elevation_m', ground)
        .put('antenna_height_max_m', maxHeight)
        .put('antenna_height_avg_m', heightAvg)
        .put('antenna_height_min_m', minHeight)
        .put('antenna_top_elevation_m', antennaTop)
        .put('technologies', technologyList)
        .put('frequencies_mhz', joinFrequencies(frequencies))
        .put('transmitter_count', visibleDevices.length)
        .put('state', state)
        .put('postcode', postcode)
        .put('city_density', cityDensity)
        .put('active', active)
        .put('ground_elevation_dem_m', demGroundM)
        .put('elevation_check', elevationCheck(ground, demGroundM))
        .put('antenna_height_all_max_m', allMax)
        .put('marker-color', markerColour);
    return feature;
  }

  static String _describe(String? telco, String? siteId, int? heightMax, double? ground,
      double? antennaTop, String technologies) {
    final StringBuffer b = StringBuffer();
    if (telco != null) b.write('$telco ');
    b.write('site $siteId.');
    if (heightMax != null) b.write(' Antenna height $heightMax m AGL.');
    if (ground != null) b.write(' Ground elevation ${ExportNumbers.formatNumber(ground)} m.');
    if (antennaTop != null) b.write(' Antenna top ${ExportNumbers.formatNumber(antennaTop)} m.');
    if (technologies.isNotEmpty) b.write(' Technologies $technologies.');
    return b.toString();
  }

  /// "Antenna height" for the site sheet: the raw minimum to maximum, a single value when they
  /// agree, or null (omit the row) when no height is known.
  static String? describeHeightRange(Iterable<int?> heights) {
    int? lo;
    int? hi;
    for (final int? h in heights) {
      if (h == null || h <= 0) continue;
      lo = lo == null || h < lo ? h : lo;
      hi = hi == null || h > hi ? h : hi;
    }
    if (lo == null || hi == null) return null;
    return lo == hi ? '$lo metres' : '$lo–$hi metres';
  }
}

/// What the tower builder needs to know about one transmitter. Plain data so the builder stays
/// free of the app's model classes.
class TowerDeviceInput {
  const TowerDeviceInput({
    required this.heightM,
    required this.technology,
    required this.technologyOrder,
    required this.frequencyMhz,
  });

  /// Raw `DeviceDetails.height`; null or not above zero means unknown.
  final int? heightM;

  /// Display label such as `4G`, or null.
  final String? technology;

  /// Sort key so technologies list oldest first (the `NetworkType` enum index).
  final int technologyOrder;

  /// Whole MHz.
  final int? frequencyMhz;
}

/// What the coverage builder needs to know about one polygon ring. Plain data, see above.
class CoverageInput {
  const CoverageInput({
    required this.siteId,
    required this.siteName,
    required this.telco,
    required this.latitude,
    required this.longitude,
    required this.networkType,
    required this.networkTechnology,
    required this.isRsrp,
    required this.signalBars,
    required this.ringOrder,
    required this.frequencyMhz,
    required this.bandwidthMhz,
    required this.emission,
    required this.eirpW,
    required this.azimuthDeg,
    required this.heightM,
    required this.antennaId,
    required this.deviceRegistrationIdentifier,
    required this.radiationModel,
    required this.terrainAware,
    required this.colour,
    required this.ring,
  });

  final String? siteId, siteName, telco;
  final double latitude, longitude;
  final String networkType, networkTechnology;
  final bool isRsrp;
  final List<int> signalBars;
  final int? ringOrder;
  final int frequencyMhz;
  final double bandwidthMhz;
  final String? emission;
  final double? eirpW;
  final int? azimuthDeg, heightM, antennaId;
  final String? deviceRegistrationIdentifier, radiationModel, colour;
  final bool terrainAware;
  final List<List<double>> ring;
}

/// The coverage export. Property names match the Android app's `buildSignalPolygonFeature`
/// (it also writes a `sim` property; this app has one SIM, so there is none here).
class CoverageExport {
  CoverageExport._();

  static ExportFeature buildFeature(CoverageInput c) {
    final int? order = c.ringOrder;
    final int? signalDbm =
        (order != null && order >= 0 && order < c.signalBars.length) ? c.signalBars[order] : null;
    final String measure = c.isRsrp ? 'RSRP' : 'RSSI';
    final String title = '${c.telco == null ? '' : '${c.telco} '}${c.frequencyMhz} MHz '
        '${c.networkType}${signalDbm == null ? '' : ' at $signalDbm dBm'}';

    final StringBuffer d = StringBuffer('Modelled ${c.networkType} ${c.frequencyMhz} MHz '
        'coverage from site ${c.siteId}.');
    if (signalDbm != null) d.write(' Down to $signalDbm dBm $measure.');
    if (c.heightM != null && c.heightM! > 0) d.write(' Antenna height ${c.heightM} m AGL.');
    if (c.azimuthDeg != null) d.write(' Azimuth ${c.azimuthDeg} degrees.');
    d.write(' Estimated by Aus Phone Towers, not a substitute for a terrain viewshed.');

    return ExportFeature.polygon(c.ring)
        .put('title', title)
        .put('description', d.toString())
        .put('site_id', c.siteId)
        .put('site_name', TowerExport.formatName(c.siteName))
        .put('telco', c.telco)
        .put('network_type', c.networkType)
        .put('network_technology', c.networkTechnology)
        .put('frequency_mhz', c.frequencyMhz)
        .put('bandwidth_mhz', ExportNumbers.round(c.bandwidthMhz, 3))
        .put('emission', c.emission)
        .put('eirp_w', c.eirpW == null ? null : ExportNumbers.round(c.eirpW!, 1))
        .put('azimuth_deg', c.azimuthDeg)
        .put('antenna_height_m', (c.heightM != null && c.heightM! > 0) ? c.heightM : null)
        .put('antenna_id', c.antennaId)
        .put('device_registration_identifier', c.deviceRegistrationIdentifier)
        .put('signal_ring', order)
        .put('signal_dbm', signalDbm)
        .put('signal_measure', measure)
        .put('radiation_model', c.radiationModel)
        .put('terrain_aware', c.terrainAware)
        .put('latitude', c.latitude)
        .put('longitude', c.longitude)
        .put('stroke', c.colour)
        .put('stroke-width', 2)
        .put('stroke-opacity', 0.9)
        .put('fill', c.colour)
        .put('fill-opacity', 0.15);
  }
}

/// GeoJSON (RFC 7946) writer. Output is built in memory so the same code serves the file and
/// web-download paths.
class GeoJsonWriter {
  GeoJsonWriter._();

  static String write(List<ExportFeature> features,
      {required String generator, required String generated}) {
    final StringBuffer out = StringBuffer();
    out.write('{"type":"FeatureCollection","name":${jsonEncode('Aus Phone Towers export')}'
        ',"generator":${jsonEncode(generator)},"generated":${jsonEncode(generated)}'
        ',"features":[');
    for (int i = 0; i < features.length; i++) {
      if (i > 0) out.write(',');
      out.write('\n');
      _writeFeature(out, features[i]);
    }
    if (features.isNotEmpty) out.write('\n');
    out.write(']}');
    return out.toString();
  }

  static void _writeFeature(StringBuffer out, ExportFeature f) {
    out.write('{"type":"Feature","geometry":');
    if (!f.isPolygon) {
      out.write('{"type":"Point","coordinates":${_position(f.coordinates.first)}}');
    } else {
      out.write('{"type":"Polygon","coordinates":[[');
      for (int i = 0; i < f.coordinates.length; i++) {
        if (i > 0) out.write(',');
        out.write(_position(f.coordinates[i]));
      }
      final List<double> first = f.coordinates.first;
      final List<double> last = f.coordinates.last;
      if (first[0] != last[0] || first[1] != last[1]) out.write(',${_position(first)}');
      out.write(']]}');
    }
    out.write(',"properties":{');
    bool firstProperty = true;
    for (final MapEntry<String, Object?> e in f.properties.entries) {
      if (!firstProperty) out.write(',');
      firstProperty = false;
      out.write('${jsonEncode(e.key)}:${_value(e.value)}');
    }
    out.write('}}');
  }

  static String _position(List<double> latLng) =>
      '[${ExportNumbers.formatNumber(latLng[1])},${ExportNumbers.formatNumber(latLng[0])}]';

  static String _value(Object? v) {
    if (v == null) return 'null';
    if (v is bool) return v.toString();
    if (v is num) {
      final String n = ExportNumbers.formatNumber(v);
      return n.isEmpty ? 'null' : n;
    }
    return jsonEncode(v.toString());
  }
}

/// RFC 4180 CSV writer: UTF-8, no byte order mark, CRLF row endings, a field quoted only when it
/// must be. Nulls are empty cells.
class CsvWriter {
  CsvWriter._();

  static const String lineSeparator = '\r\n';

  static String write(List<String> columns, List<ExportFeature> features) {
    final StringBuffer out = StringBuffer();
    out.write(columns.map(escape).join(','));
    out.write(lineSeparator);
    for (final ExportFeature f in features) {
      out.write(columns.map((String c) => escape(f.get(c))).join(','));
      out.write(lineSeparator);
    }
    return out.toString();
  }

  static String escape(Object? value) {
    if (value == null) return '';
    final String text = value is num ? ExportNumbers.formatNumber(value) : value.toString();
    if (text.isEmpty) return '';
    final bool mustQuote = text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r') ||
        text.trim().length != text.length;
    return mustQuote ? '"${text.replaceAll('"', '""')}"' : text;
  }
}
