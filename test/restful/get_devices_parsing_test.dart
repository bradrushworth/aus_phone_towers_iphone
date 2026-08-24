import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/restful/get_devices.dart';

/// Parsing of the two ACMA device fields that were being read wrongly on iOS and web.
///
/// Both bugs were silent: no exception, no log, just quietly wrong propagation inputs on one
/// platform and not the other.
void main() {
  group('parseAzimuth', () {
    test('a missing azimuth stays null, which is what marks an omni antenna', () {
      // The bug: this returned 0. DeviceDetails.getPowerAtBearing picks its omnidirectional
      // branch on `azimuth == null`, so a 0 made that branch unreachable — omniCalibrationDb
      // (+13.5 dB) was never applied, and real omnis were treated as directional antennas
      // boresighted due north with front-to-back loss subtracted behind them.
      expect(GetDevices.parseAzimuth(null), isNull);
      expect(GetDevices.parseAzimuth(''), isNull);
    });

    test('a real azimuth is kept', () {
      expect(GetDevices.parseAzimuth('0'), 0);
      expect(GetDevices.parseAzimuth('80'), 80);
      expect(GetDevices.parseAzimuth('300'), 300);
    });

    test('a decimal azimuth rounds, matching Java', () {
      expect(GetDevices.parseAzimuth('119.6'), 120);
      expect(GetDevices.parseAzimuth('119.4'), 119);
    });

    test('an unparseable azimuth is treated as omni rather than as due north', () {
      expect(GetDevices.parseAzimuth('n/a'), isNull);
    });
  });

  group('parseHeight', () {
    test('a decimal height is no longer thrown away', () {
      // The bug: int.tryParse('20.41') is null, which became 0 and then the 10 m floor.
      expect(GetDevices.parseHeight('20.41'), 20);
      expect(GetDevices.parseHeight('12.6'), 12);
    });

    test('truncates rather than rounds, matching Java optIntValue', () {
      expect(GetDevices.parseHeight('20.9'), 20);
    });

    test('whole numbers and absent values behave as before', () {
      expect(GetDevices.parseHeight('31'), 31);
      expect(GetDevices.parseHeight(null), 0);
      expect(GetDevices.parseHeight(''), 0);
      expect(GetDevices.parseHeight('rubbish'), 0);
    });
  });
}
