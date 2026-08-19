import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

void main() {
  group('GetLicenceHRP.rowStepForBearingIncrement', () {
    // Regression test: the Polygon Precision menu previously had no effect on real
    // (non-estimated) coverage, because the server-row sampling loop hardcoded a step
    // of 2 regardless of PolygonHelper.polygonBearingIncrement. This pins the mapping
    // from each precision preset to its resulting row step.
    test('medium (default) preset preserves the original hardcoded step of 2', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionMedium),
        2,
      );
    });

    test('low preset samples fewer rows (coarser, faster)', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionLow),
        4,
      );
    });

    test('high preset samples every row (finer, smoother)', () {
      expect(
        GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionHigh),
        1,
      );
    });

    test('never returns a step below 1, even for a very small increment', () {
      expect(GetLicenceHRP.rowStepForBearingIncrement(0.01), 1);
    });

    test('scales monotonically with the bearing increment', () {
      final int lowStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionLow);
      final int mediumStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionMedium);
      final int highStep =
          GetLicenceHRP.rowStepForBearingIncrement(PolygonHelper.kPolygonPrecisionHigh);
      expect(highStep, lessThan(mediumStep));
      expect(mediumStep, lessThan(lowStep));
    });
  });
}
