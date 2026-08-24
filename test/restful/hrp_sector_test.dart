import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

/// Mirrors the Java app's GetLicenceHRPSectorTest so the two implementations stay in step.
///
/// The drawing code used to add a constant 1.25 degrees ("half of 2.5, the measurement resolution
/// with ACMA"). Measured against the live database on 2026-08-24 that holds for only 2.1% of the
/// ~175M published rows: 96.2% are 1 degree sectors, with 0.5, 2, 3, 4, 5 and 6 degrees also
/// occurring. Every affected polygon was rotated by a constant 0.75 degrees.
void main() {
  group('licence_hrp sector geometry', () {
    test('1 degree sector — the dominant case — centres at half a degree', () {
      expect(GetLicenceHRP.sectorHalfWidth(1.0, 2.0), closeTo(0.5, 1e-9));
    });

    test('2.5 degree sector still centres where the old constant did', () {
      // The 2.1% the hard-coded 1.25 was correct for — it must not regress.
      expect(GetLicenceHRP.sectorHalfWidth(0.0, 2.5), closeTo(1.25, 1e-9));
    });

    test('other published widths are honoured', () {
      expect(GetLicenceHRP.sectorHalfWidth(10.0, 10.5), closeTo(0.25, 1e-9));
      expect(GetLicenceHRP.sectorHalfWidth(10.0, 12.0), closeTo(1.0, 1e-9));
      expect(GetLicenceHRP.sectorHalfWidth(10.0, 13.0), closeTo(1.5, 1e-9));
      expect(GetLicenceHRP.sectorHalfWidth(10.0, 16.0), closeTo(3.0, 1e-9));
    });

    test('final sector wrapping through north is measured forwards', () {
      expect(GetLicenceHRP.sectorHalfWidth(359.0, 0.0), closeTo(0.5, 1e-9));
      expect(GetLicenceHRP.sectorHalfWidth(357.5, 0.0), closeTo(1.25, 1e-9));
    });

    test('missing or unusable stop_angle falls back to the dominant width', () {
      final expected = GetLicenceHRP.kDefaultSectorWidthDegrees / 2;
      expect(GetLicenceHRP.sectorHalfWidth(7.0, null), closeTo(expected, 1e-9));
      expect(GetLicenceHRP.sectorHalfWidth(7.0, double.nan), closeTo(expected, 1e-9));
      expect(GetLicenceHRP.sectorHalfWidth(7.0, 7.0), closeTo(expected, 1e-9));
      expect(GetLicenceHRP.sectorHalfWidth(0.0, 360.0), closeTo(expected, 1e-9));
    });

    test('documents the 0.75 degree rotation this replaced', () {
      final oldBearing = 1.0 + 1.25;
      final newBearing = 1.0 + GetLicenceHRP.sectorHalfWidth(1.0, 2.0);
      expect(oldBearing - newBearing, closeTo(0.75, 1e-9));
    });
  });
}
