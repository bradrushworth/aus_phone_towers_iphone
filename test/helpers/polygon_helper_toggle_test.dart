import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/map_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

// Regression tests for GitHub issue #55 (BUG 1): tapping a tower marker a second time
// stopped hiding its coverage polygons. Root cause: map_common.dart's
// showCustomInfoWindowAsBottomSheet unconditionally called
// PolygonHelper.queryForSignalPolygon(site, ...) to (re)draw every tap, even when
// clearSitePatterns()/queryForSignalPolygon() had *just* unregistered the site as part of
// the "toggle off" branch inside queryForSignalPolygon (PolygonHelper.sitesPolygons.containsKey
// + !refreshingPolygons => unregister and return without redrawing). These tests exercise
// PolygonHelper.queryForSignalPolygon directly (the piece both bugs actually live in), forcing
// developer mode on so it takes the synchronous PolygonHelper.createBasicPolygon path and needs
// no network access (a null deviceRegistrationIdentifier would also take that path, but
// DeviceDetails.toString()/hashCode force-unwrap it, so a device stored as a Map key needs a
// real one here).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Forces PolygonHelper.queryForSignalPolygon's DRI-fallback dispatch down the synchronous
    // createBasicPolygon path without needing a null deviceRegistrationIdentifier.
    MapHelper().developerMode = true;
  });

  tearDownAll(() {
    MapHelper().developerMode = false;
  });

  Site buildSite() {
    final Site site = Site(
      telco: Telco.Telstra,
      cityDensity: CityDensity.URBAN,
      siteId: 'toggle-test-site',
      latitude: -28.0396,
      longitude: 148.5878, // St George, QLD - the site from issue #55
    );
    final DeviceDetails device = DeviceDetails(
      sddId: 'toggle-test-device',
      siteId: site.siteId,
      networkType: NetworkType.LTE,
      frequency: 763000000,
      emission: '20M0W7D',
      eirp: 100,
      bandwidth: 20000000,
      height: 30,
      deviceRegistrationIdentifier: 'toggle-test-dri-a',
    );
    device.site = site;
    site.deviceDetailsMobile.add(device);
    return site;
  }

  setUp(() {
    // Isolate each test from PolygonHelper's static, app-wide state.
    PolygonHelper.sitesPolygons.clear();
    PolygonHelper.globalListPolygons.clear();
    PolygonHelper.labelOverlays.clear();
    PolygonHelper.multiTowerCoverage = false;
  });

  test('first call on a site registers and draws its polygons', () {
    final Site site = buildSite();

    PolygonHelper().queryForSignalPolygon(site, false, false);

    expect(PolygonHelper.sitesPolygons.containsKey(site), isTrue,
        reason: 'a first tap should register the site as showing coverage');
    expect(
        PolygonHelper.globalListPolygons
            .where((overlay) => overlay.site == site)
            .isNotEmpty,
        isTrue,
        reason: 'a first tap should draw at least one polygon for the site');
  });

  test(
      'a second identical call unregisters the site instead of redrawing it (toggle off)',
      () {
    final Site site = buildSite();

    // First call: draws and registers, as above.
    PolygonHelper().queryForSignalPolygon(site, false, false);
    expect(PolygonHelper.sitesPolygons.containsKey(site), isTrue);

    // Second call with the same (refreshingPolygons: false) arguments that
    // map_common.dart's marker tap handler uses - this is the toggle-off call.
    PolygonHelper().queryForSignalPolygon(site, false, false);

    expect(PolygonHelper.sitesPolygons.containsKey(site), isFalse,
        reason: 'a second tap must unregister the site (coverage toggled off)');
    expect(
        PolygonHelper.globalListPolygons
            .where((overlay) => overlay.site == site)
            .isEmpty,
        isTrue,
        reason: 'a second tap must remove the site\'s own drawn polygons');
  });

  test(
      'removing one site\'s polygons does not touch another site\'s polygons '
      '(regression: removeWhere used to blast every non-developer polygon)', () {
    final Site siteA = buildSite();
    final Site siteB = Site(
      telco: Telco.Optus,
      cityDensity: CityDensity.URBAN,
      siteId: 'toggle-test-site-b',
      latitude: -28.05,
      longitude: 148.6,
    );
    final DeviceDetails deviceB = DeviceDetails(
      sddId: 'toggle-test-device-b',
      siteId: siteB.siteId,
      networkType: NetworkType.LTE,
      frequency: 947000000,
      emission: '20M0W7D',
      eirp: 100,
      bandwidth: 20000000,
      height: 25,
      deviceRegistrationIdentifier: 'toggle-test-dri-b',
    );
    deviceB.site = siteB;
    siteB.deviceDetailsMobile.add(deviceB);

    PolygonHelper().queryForSignalPolygon(siteA, false, false);
    PolygonHelper().queryForSignalPolygon(siteB, false, false);
    expect(PolygonHelper.sitesPolygons.containsKey(siteA), isTrue);
    expect(PolygonHelper.sitesPolygons.containsKey(siteB), isTrue);

    // Toggle site A off.
    PolygonHelper().queryForSignalPolygon(siteA, false, false);

    expect(PolygonHelper.sitesPolygons.containsKey(siteA), isFalse);
    expect(PolygonHelper.sitesPolygons.containsKey(siteB), isTrue,
        reason: 'toggling one site off must not unregister a different site');
    expect(
        PolygonHelper.globalListPolygons
            .where((overlay) => overlay.site == siteB)
            .isNotEmpty,
        isTrue,
        reason: 'toggling one site off must not remove another site\'s drawn polygons');
  });
}
