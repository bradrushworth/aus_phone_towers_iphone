import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/model/antenna.dart';

void main() {
  group('Antenna', () {
    test('a freshly constructed Antenna can be read without throwing', () {
      // GetAntenna caches the Antenna before its fetch resolves and never awaits it, so
      // getPowerAtBearing() legitimately reads these fields early — and on licences with no
      // antenna record, reads them having never been written. When they were `late`, that threw
      // LateInitializationError and the device's whole polygon was abandoned.
      final Antenna antenna = Antenna();
      expect(antenna.gain, 0);
      expect(antenna.frontToBack, 0);
      expect(antenna.horizontalBeamwidth, 0);
    });

    test('the default beamwidth fails the directional-gain test in getPowerAtBearing', () {
      // getPowerAtBearing only adds directional gain when `beamwidth > 0 && beamwidth < 360`,
      // so an unpopulated antenna contributes no gain rather than a wrong one. This is the same
      // outcome Java reaches, where the fields are primitives defaulting to 0.0.
      final Antenna antenna = Antenna();
      expect(antenna.horizontalBeamwidth > 0 && antenna.horizontalBeamwidth < 360, isFalse);
    });
  });
}
