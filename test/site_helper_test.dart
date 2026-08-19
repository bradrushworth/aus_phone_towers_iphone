import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/overlay.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

// Regression test for #24: toggling a telco back on used to unconditionally
// mark every one of its markers visible, bypassing whatever network-type /
// density / frequency filters were active. SiteHelper.toggleTelcoMarkers()
// now re-evaluates Site.shouldBeVisible() when re-enabling a telco, so a
// site whose only devices are filtered out (e.g. not 5G, while a 5G-only
// filter is active) must stay hidden.
void main() {
  group('SiteHelper.toggleTelcoMarkers', () {
    late Site site;
    late DeviceDetails lteDevice;
    late MapOverlay mapOverlay;

    void resetStaticState() {
      // SiteHelper (and the filters Site.shouldBeVisible() reads) are held in
      // static fields shared across the whole test suite, so reset them
      // before and after each test to avoid leaking state between tests.
      SiteHelper.globalListMapOverlay = [];
      SiteHelper.hideTelco = Set<Telco>();
      SiteHelper.hideNetworkType = Set<NetworkType>();
      SiteHelper.hideFrequency = Set<List<int>>();
      SiteHelper.hideDensity = Set<CityDensity>();
    }

    setUp(() {
      resetStaticState();

      site = new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN);
      site.siteId = '1234567';
      site.name = 'Optus Test Site';

      // Only a non-5G (LTE) device is attached to this site.
      lteDevice = new DeviceDetails(networkType: NetworkType.UNKNOWN);
      lteDevice.setSite(site);
      lteDevice.emission = '10M0W7D'; // FD_LTE
      lteDevice.frequency = 1840000000;
      lteDevice.polarisation = 'V';
      lteDevice.bandwidth = 10000000;
      lteDevice.active = 'active';
      lteDevice.sddId = '99999999';
      lteDevice.networkType = DeviceDetails.getNetworkTypeStatic(lteDevice.emission,
              lteDevice.frequency!, lteDevice.bandwidth!, site.telco, 0)
          .first;

      site.getDeviceDetailsMobile().add(lteDevice);

      final Marker marker = Marker(
        markerId: MarkerId('site_${site.siteId}'),
        visible: true,
      );
      mapOverlay = new MapOverlay(marker: marker, site: site);
      SiteHelper.globalListMapOverlay.add(mapOverlay);
    });

    tearDown(() {
      resetStaticState();
    });

    test(
        're-enabling a telco keeps a marker hidden that fails the active filter (#24)',
        () {
      // Simulate a "5G-only" filter by hiding every non-NR network type.
      SiteHelper.hideNetworkType.addAll(<NetworkType>[
        NetworkType.UNKNOWN,
        NetworkType.GSM,
        NetworkType.UMTS,
        NetworkType.LTE,
        NetworkType.CDMA,
        NetworkType.NB_IOT,
        NetworkType.OTHER,
      ]);

      // Sanity check the fixture: with a 5G-only filter active, this LTE-only
      // site should not be visible.
      expect(site.shouldBeVisible(), false);

      final SiteHelper siteHelper = SiteHelper();

      // Hide the telco entirely...
      siteHelper.toggleTelcoMarkers(Telco.Optus, false);
      expect(SiteHelper.globalListMapOverlay[0].marker!.visible, false);

      // ...then re-enable it. The telco is visible again, but this
      // particular marker's device fails the active 5G-only filter, so the
      // marker must stay hidden rather than being blindly turned back on.
      siteHelper.toggleTelcoMarkers(Telco.Optus, true);
      expect(SiteHelper.globalListMapOverlay[0].marker!.visible, false);
    });
  });
}
