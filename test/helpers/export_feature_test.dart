import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/export_feature.dart';

ExportFeature tower({
  String? acma = '100',
  int? dem,
  List<TowerDeviceInput>? devices,
  List<int?>? all,
  String? name = 'Test &amp; Site',
}) {
  final List<TowerDeviceInput> d = devices ??
      const <TowerDeviceInput>[
        TowerDeviceInput(heightM: 4, technology: '4G', technologyOrder: 3, frequencyMhz: 1800),
      ];
  return TowerExport.buildFeature(
    siteId: '123',
    name: name,
    telco: 'Telstra',
    latitude: -35.5,
    longitude: 149.25,
    acmaElevationText: acma,
    demGroundM: dem,
    visibleDevices: d,
    allDeviceHeights: all ?? d.map((TowerDeviceInput x) => x.heightM),
    state: 'ACT',
    postcode: '2600',
    cityDensity: 'Urban',
    active: true,
  );
}

void main() {
  test('CSV header equals the contract exactly', () {
    const String expected =
        'site_id,name,telco,latitude,longitude,ground_elevation_m,antenna_height_max_m,'
        'antenna_height_avg_m,antenna_height_min_m,antenna_top_elevation_m,technologies,'
        'frequencies_mhz,transmitter_count,state,postcode,city_density,active,'
        'ground_elevation_dem_m,elevation_check,antenna_height_all_max_m';
    expect(TowerExport.csvColumns.join(','), expected);
    final String csv = CsvWriter.write(TowerExport.csvColumns, <ExportFeature>[tower()]);
    expect(csv.split('\r\n').first, expected);
  });

  test('a 4 m antenna exports 4, not the 10 m modelling floor', () {
    final ExportFeature f = tower();
    expect(f.get('antenna_height_max_m'), 4);
    expect(f.get('antenna_height_min_m'), 4);
    expect(f.get('antenna_top_elevation_m'), 104);
  });

  test('unknown height gives empty height and empty antenna top', () {
    final ExportFeature f = tower(devices: const <TowerDeviceInput>[
      TowerDeviceInput(heightM: 0, technology: '4G', technologyOrder: 3, frequencyMhz: 700),
      TowerDeviceInput(heightM: null, technology: '5G', technologyOrder: 4, frequencyMhz: 3500),
    ]);
    expect(f.get('antenna_height_max_m'), isNull);
    expect(f.get('antenna_height_avg_m'), isNull);
    expect(f.get('antenna_top_elevation_m'), isNull);
    expect(f.get('antenna_height_all_max_m'), isNull);
    final String row =
        CsvWriter.write(TowerExport.csvColumns, <ExportFeature>[f]).split('\r\n')[1];
    expect(row.contains('null'), isFalse);
    expect(row, contains('100,,,,,4G/5G,'));
  });

  test('blank or non-numeric ACMA elevation gives empty ground', () {
    expect(tower(acma: '  ').get('ground_elevation_m'), isNull);
    expect(tower(acma: 'n/a').get('ground_elevation_m'), isNull);
    expect(tower(acma: '  ').get('antenna_top_elevation_m'), isNull);
  });

  test('elevation_check boundaries', () {
    expect(TowerExport.elevationCheck(130, 100), 'ok');
    expect(TowerExport.elevationCheck(130.01, 100), 'differs');
    expect(TowerExport.elevationCheck(70, 100), 'ok');
    expect(TowerExport.elevationCheck(null, 100), 'unverified');
    expect(TowerExport.elevationCheck(100, null), 'unverified');
    expect(tower(dem: 130).get('elevation_check'), 'ok');
    expect(tower(dem: 131).get('elevation_check'), 'differs');
    expect(tower().get('elevation_check'), 'unverified');
    expect(tower(dem: 140).get('ground_elevation_dem_m'), 140);
  });

  test('all-transmitter max ignores the filters; stats use visible ones', () {
    final ExportFeature f = tower(
      devices: const <TowerDeviceInput>[
        TowerDeviceInput(heightM: 10, technology: '4G', technologyOrder: 3, frequencyMhz: 1800),
        TowerDeviceInput(heightM: 15, technology: '3G', technologyOrder: 2, frequencyMhz: 850),
      ],
      all: <int?>[10, 15, 40],
    );
    expect(f.get('antenna_height_max_m'), 15);
    expect(f.get('antenna_height_min_m'), 10);
    expect(f.get('antenna_height_avg_m'), 12.5);
    expect(f.get('antenna_height_all_max_m'), 40);
    expect(f.get('technologies'), '3G/4G');
    expect(f.get('frequencies_mhz'), '850;1800');
    expect(f.get('transmitter_count'), 2);
  });

  test('CSV and GeoJSON write nulls as empty / null, numbers plainly', () {
    final ExportFeature f = tower(acma: '', name: 'A, "B"');
    final String csv = CsvWriter.write(TowerExport.csvColumns, <ExportFeature>[f]);
    expect(csv, contains('"A, ""B"""'));
    expect(csv.contains('null'), isFalse);
    expect(csv, contains('-35.5,149.25'));
    final String json =
        GeoJsonWriter.write(<ExportFeature>[f], generator: 'g', generated: 't');
    expect(json, contains('"ground_elevation_m":null'));
    expect(json, contains('"coordinates":[149.25,-35.5]'));
    expect(json, contains('"active":true'));
  });

  test('site name decodes entities', () {
    expect(tower().get('name'), 'Test & Site');
  });

  test('describeHeightRange', () {
    expect(TowerExport.describeHeightRange(<int?>[null, 0]), isNull);
    expect(TowerExport.describeHeightRange(<int?>[4, 4]), '4 metres');
    expect(TowerExport.describeHeightRange(<int?>[4, 30, null]), '4–30 metres');
  });

  test('coverage uses the Android property names', () {
    final ExportFeature f = CoverageExport.buildFeature(const CoverageInput(
      siteId: '1',
      siteName: 'S',
      telco: 'Optus',
      latitude: -35,
      longitude: 149,
      networkType: '4G',
      networkTechnology: 'LTE',
      isRsrp: true,
      signalBars: <int>[-85, -95, -105, -115],
      ringOrder: 1,
      frequencyMhz: 1800,
      bandwidthMhz: 20,
      emission: '20M0W7D',
      eirpW: 100.04,
      azimuthDeg: null,
      heightM: 0,
      antennaId: 7,
      deviceRegistrationIdentifier: 'r',
      radiationModel: 'Urban',
      terrainAware: true,
      colour: '#007F87',
      ring: <List<double>>[
        <double>[-35, 149],
        <double>[-35, 150],
        <double>[-34, 150]
      ],
    ));
    for (final String k in <String>[
      'frequency_mhz',
      'bandwidth_mhz',
      'eirp_w',
      'azimuth_deg',
      'antenna_height_m',
      'signal_ring',
      'signal_dbm',
      'signal_measure',
      'terrain_aware'
    ]) {
      expect(f.properties.containsKey(k), isTrue, reason: k);
    }
    expect(f.get('signal_dbm'), -95);
    expect(f.get('signal_measure'), 'RSRP');
    expect(f.get('antenna_height_m'), isNull);
    expect(f.get('eirp_w'), 100.0);
  });
}
