import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/get_licenceHRP.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/site.dart';

void main() {
  group('SiteTest', () {
    late Site site;
    late DeviceDetails device1, device2, device3, device4;

    setUp(() {
      site = new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN);

      site.siteId = '9011112';
      ;
      site.name =
          'Optus Site Port Waratah Coal Joint Venture Lot 666 Cormorant Rd KOORAGANG ISLAND';

      device1 = new DeviceDetails();
      device1.setSite(site);
      device1.emission = '10M0W7D'; // FD_LTE
      device1.frequency = 1840000000;
      device1.polarisation = 'S';
      device1.bandwidth = 10000000;
      device1.active = 'active';
      device1.sddId = '11111111';

      device2 = new DeviceDetails();
      device2.setSite(site);
      device2.emission = '8M40G7E'; // GSM
      device2.frequency = 1840000000;
      device2.polarisation = 'V';
      device2.bandwidth = 10000000;
      device2.active = 'active';
      device2.sddId = '22222222';

      device3 = new DeviceDetails();
      device3.setSite(site);
      device3.emission = '10M0W7D'; // FD_LTE
      device3.frequency = 1840000000;
      device3.polarisation = 'V';
      device3.bandwidth = 40000000;
      device3.active = 'active';
      device3.sddId = '33333333';

      device4 = new DeviceDetails();
      device4.setSite(site);
      device4.emission = '3M84G7W'; // UMTS
      device4.frequency = 947600000;
      device4.polarisation = 'S';
      device4.bandwidth = 3840000;
      device4.active = ''; // false
      device4.sddId = '44444444';

      List<DeviceDetails> deviceDetailsMobile = site.getDeviceDetailsMobile();
      deviceDetailsMobile.add(device1);
      deviceDetailsMobile.add(device2);
      deviceDetailsMobile.add(device3);
      deviceDetailsMobile.add(device4);
    });

    test('centerEachLine', () {
      expect(
        Site.centerEachLine(
            "Telstra Exchange\n5321 Casterton-Edenhope Road\nKadnook"),
        "           Telstra Exchange           \n" +
            "     5321 Casterton-Edenhope Road     \n" +
            "               Kadnook                \n",
      );
    });

    test('getNameFormatted', () {
      expect(
        site.getNameFormatted(),
        "Optus Site \n" +
            "Port Waratah Coal Joint \n" +
            "Venture \n" +
            "Lot 666 Cormorant Rd \n" +
            "KOORAGANG ISLAND",
      );
    });

    test('getSiteId', () {
      expect("9011112", site.siteId);
    });

    test('getTelco', () {
      expect(Telco.Telstra, site.getTelco());
    });

    test('getNameFormatted', () {
      expect(
          "Optus Site \n" +
              "Port Waratah Coal Joint \n" +
              "Venture \n" +
              "Lot 666 Cormorant Rd \n" +
              "KOORAGANG ISLAND",
          site.getNameFormatted());
    });

    test('getDeviceDetailsMobileBands', () {
      expect(site.getDeviceDetailsMobileBands().length, 3);
      expect(
          site
              .getDeviceDetailsMobileBands()
              .containsKey("001840000000_10M0W7D"),
          true);
      expect(
          site
              .getDeviceDetailsMobileBands()
              .containsKey("001840000000_8M40G7E"),
          true);
      expect(
          site
              .getDeviceDetailsMobileBands()
              .containsKey("000947600000_3M84G7W"),
          true);
    });

    test('countNumberAntennas1', () {
      expect(site.countNumberAntennas(device1), 2);
      expect(site.countNumberAntennaPaths(device1), 4);
      expect(site.getNetworkCapacity(device1), 207364440);
    });

    test('countNumberAntennas2', () {
      expect(site.countNumberAntennas(device2), 1);
      expect(site.countNumberAntennaPaths(device2), 1);
      expect(site.getNetworkCapacity(device2), 13545000);
    });

    test('countNumberAntennas3', () {
      expect(site.countNumberAntennas(device3), 2);
      expect(site.countNumberAntennaPaths(device3), 2);
      expect(site.getNetworkCapacity(device3), 414728884);
    });

    test('countNumberAntennas4', () {
      expect(site.countNumberAntennas(device4), 1);
      expect(site.countNumberAntennaPaths(device4), 2);
      expect(site.getNetworkCapacity(device4), 33983928);
    });

    // test('hasTechnology', () {
    //   expect(site.hasTechnology(0), false);
    //   expect(site.hasTechnology(1), true);
    //   expect(site.hasTechnology(2), true);
    //   expect(site.hasTechnology(3), true);
    //   expect(site.hasTechnology(4), false);
    //   expect(site.hasTechnology(5), false);
    //   expect(site.hasTechnology(6), false);
    //   expect(site.hasTechnology(7), false);
    //   expect(site.hasTechnology(8), true);
    //   expect(site.hasTechnology(9), true);
    //   expect(site.hasTechnology(10), true);
    //   expect(site.hasTechnology(11), false);
    //   expect(site.hasTechnology(12), false);
    //   expect(site.hasTechnology(13), true);
    //   expect(site.hasTechnology(14), true);
    //   expect(site.hasTechnology(15), true);
    //   expect(site.hasTechnology(16), true);
    //   expect(site.hasTechnology(17), true);
    //   expect(site.hasTechnology(18), false);
    //   expect(site.hasTechnology(19), true);
    // });

    test('getAlpha', () {
      expect(site.getAlpha(), 0.95);
    });

    // test('getColour', () {
    //   expect(site.getColour(), 240.0);
    // });

    test('getRotation', () {
      expect(site.getRotation(), -50.0);
    });

    test('getIconName', () {
      expect(site.getIconName(), 'telstra.png');
    });

    //   test('getActiveDevicesForArfcnLTE', () {
    //     int CONNECTED_NETWORK_TYPE = 13;
    //     NetworkType networkType = CellIdentity.getNetworkGeneration(
    //         CONNECTED_NETWORK_TYPE);
    //     expect(NetworkType.LTE, networkType);
    //     Set<DeviceDetails> expectedDevices = new HashSet<>();
    //     expectedDevices.add(device1);
    //     expectedDevices.add(device3);
    //     expect(expectedDevices,
    //         site.getActiveDevicesForFrequency(networkType, device1.frequency));
    //   });
    //
    //   test('getActiveDevicesForArfcnUMTS', () {
    //     int CONNECTED_NETWORK_TYPE = 10;
    //     NetworkType networkType = CellIdentity.getNetworkGeneration(
    //         CONNECTED_NETWORK_TYPE);
    //     expect(NetworkType.UMTS, networkType);
    //     Set<DeviceDetails> expectedDevices = new HashSet<>();
    //     expectedDevices.add(device4);
    //     expect(expectedDevices,
    //         site.getActiveDevicesForFrequency(networkType, device4.frequency));
    //   });
  });
}
