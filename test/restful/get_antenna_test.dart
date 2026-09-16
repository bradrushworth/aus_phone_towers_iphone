import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/restful/get_antenna.dart';

void main() {
  group('GetAntenna early-return paths', () {
    setUp(() {
      // antennaCache is a static Map shared across the whole test run; start each test clean so
      // one test's cached placeholder cannot leak into the next.
      GetAntenna.antennaCache.clear();
    });

    test(
        'a null antennaId publishes a placeholder then abandons it, leaving readable defaults',
        () async {
      final DeviceDetails device =
          DeviceDetails(networkType: NetworkType.LTE, antennaId: null);

      await GetAntenna(url: 'unused://', deviceDetails: device)
          .getAntennaData();

      // The device keeps an Antenna instance (getPowerAtBearing reads antenna!.gain
      // unconditionally), but with no antennaId there is nothing to key the cache on.
      expect(device.antenna, isNotNull);
      expect(device.antenna!.gain, 0);
      expect(device.antenna!.frontToBack, 0);
      expect(device.antenna!.horizontalBeamwidth, 0);
      expect(GetAntenna.antennaCache, isEmpty);
    });

    test(
        'antennaId == 0 abandons the cached placeholder instead of leaving it behind',
        () async {
      final DeviceDetails device =
          DeviceDetails(networkType: NetworkType.LTE, antennaId: 0);

      await GetAntenna(url: 'unused://', deviceDetails: device)
          .getAntennaData();

      // Reading the fields must not throw (this is exactly what used to abort the device's
      // polygon with a LateInitializationError), and the placeholder must not be left in
      // antennaCache: get_devices.dart treats a cache hit as "already resolved" for every later
      // device sharing this antennaId, so a stray empty entry would make the failure permanent
      // for the rest of the session.
      expect(() => device.antenna!.gain, returnsNormally);
      expect(device.antenna!.gain, 0);
      expect(GetAntenna.antennaCache.containsKey(0), isFalse);
    });
  });
}
