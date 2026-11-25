import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

// Which filters hide a transmitter (Site.isDeviceVisible).
//
// The Generation and Multiplex filters describe mobile networks. A broadcast, aviation or CB
// licence classifies as GSM only because its emission designator's information type is 'E'
// (voice / sound broadcasting): FM radio is 200KF8EHF, AM 18K0A3E, aviation 6K00A3E, CB 16K0F3E,
// the commonest designators in production. Untick 2G and every radio station disappeared even with
// Radio ticked (user report, 2026-11-25; Android PR #168 pins the same rule in
// DeviceDetailsVisibilityTest).
void main() {
  late Set<NetworkType> savedNetworkTypes;
  late Set<List<int>> savedFrequencies;
  late Set<CityDensity> savedDensities;
  late bool savedNotLte, savedFd, savedTd;

  setUp(() {
    savedNetworkTypes = Set.of(SiteHelper.hideNetworkType);
    savedFrequencies = Set.of(SiteHelper.hideFrequency);
    savedDensities = Set.of(SiteHelper.hideDensity);
    savedNotLte = PolygonHelper.displayNotLteMultiplex;
    savedFd = PolygonHelper.displayFdMultiplex;
    savedTd = PolygonHelper.displayTdMultiplex;
    SiteHelper.hideNetworkType.clear();
    SiteHelper.hideFrequency.clear();
    SiteHelper.hideDensity.clear();
    PolygonHelper.displayNotLteMultiplex = true;
    PolygonHelper.displayFdMultiplex = true;
    PolygonHelper.displayTdMultiplex = true;
  });

  tearDown(() {
    SiteHelper.hideNetworkType
      ..clear()
      ..addAll(savedNetworkTypes);
    SiteHelper.hideFrequency
      ..clear()
      ..addAll(savedFrequencies);
    SiteHelper.hideDensity
      ..clear()
      ..addAll(savedDensities);
    PolygonHelper.displayNotLteMultiplex = savedNotLte;
    PolygonHelper.displayFdMultiplex = savedFd;
    PolygonHelper.displayTdMultiplex = savedTd;
  });

  Site siteWith(Telco telco, String emission, int frequency) {
    final types = DeviceDetails.getNetworkTypeStatic(emission, frequency, 0, telco, 0);
    final site = Site(telco: telco, cityDensity: CityDensity.SUBURBAN);
    final device = DeviceDetails(
        emission: emission, frequency: frequency, networkType: types.first, site: site);
    site.deviceDetailsMobile.add(device);
    return site;
  }

  bool visible(Site site) => site.isDeviceVisible(site.deviceDetailsMobile.first);

  test('the real radio, aviation and CB designators classify as GSM', () {
    expect(DeviceDetails.getNetworkTypeStatic('200KF8EHF', 102300000, 0, Telco.Radio, 0),
        [NetworkType.GSM]);
    expect(DeviceDetails.getNetworkTypeStatic('6K00A3E', 118100000, 0, Telco.Aviation, 0),
        [NetworkType.GSM]);
  });

  test('FM radio stays visible when the generation filter hides GSM', () {
    SiteHelper.hideNetworkType.add(NetworkType.GSM);
    expect(visible(siteWith(Telco.Radio, '200KF8EHF', 102300000)), isTrue);
  });

  test('AM radio, aviation and CB stay visible when every generation is hidden', () {
    SiteHelper.hideNetworkType.addAll(NetworkType.values);
    expect(visible(siteWith(Telco.Radio, '18K0A3E', 666000)), isTrue);
    expect(visible(siteWith(Telco.Aviation, '6K00A3E', 118100000)), isTrue);
    expect(visible(siteWith(Telco.CBRS, '16K0F3E', 476425000)), isTrue);
  });

  test('radio stays visible when the Not LTE multiplex is hidden', () {
    PolygonHelper.displayNotLteMultiplex = false;
    expect(visible(siteWith(Telco.Radio, '200KF8EHF', 102300000)), isTrue);
  });

  test("a mobile carrier's GSM transmitter is still hidden by the generation filter", () {
    SiteHelper.hideNetworkType.add(NetworkType.GSM);
    expect(visible(siteWith(Telco.Telstra, '200KG7E', 935000000)), isFalse);
  });

  test("a mobile carrier's non-LTE transmitter is still hidden by the multiplex filter", () {
    PolygonHelper.displayNotLteMultiplex = false;
    expect(visible(siteWith(Telco.Optus, '200KG7E', 935000000)), isFalse);
  });

  test('radio is still hidden by the frequency and density filters', () {
    SiteHelper.hideFrequency.add([0, 699]);
    expect(visible(siteWith(Telco.Radio, '200KF8EHF', 102300000)), isFalse);
    SiteHelper.hideFrequency.clear();
    SiteHelper.hideDensity.add(CityDensity.SUBURBAN);
    expect(visible(siteWith(Telco.Radio, '200KF8EHF', 102300000)), isFalse);
  });
}
