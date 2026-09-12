import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/polygon_helper.dart';

void main() {
  test('Driving Mode includes every signal-strength contour', () {
    expect(
      PolygonHelper.signalStrengthPositionFor(
        followGps: true,
        configuredPosition: 0,
        availableRungs: 4,
      ),
      3,
    );
  });

  test('normal mode honours and bounds the configured contour', () {
    expect(
      PolygonHelper.signalStrengthPositionFor(
        followGps: false,
        configuredPosition: 2,
        availableRungs: 4,
      ),
      2,
    );
    expect(
      PolygonHelper.signalStrengthPositionFor(
        followGps: false,
        configuredPosition: 99,
        availableRungs: 4,
      ),
      3,
    );
    expect(
      PolygonHelper.signalStrengthPositionFor(
        followGps: true,
        configuredPosition: 0,
        availableRungs: 0,
      ),
      -1,
    );
  });
}
