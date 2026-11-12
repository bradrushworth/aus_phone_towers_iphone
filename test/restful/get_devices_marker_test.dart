import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:phonetowers/restful/get_devices.dart';

/// Regression for the iPhone-only defect where an inactive site's visibility update was thrown
/// away: the second assignment copied the original (still invisible) marker. Android draws these
/// sites visible at half alpha.
void main() {
  // A marker as created for a site that has not yet loaded its transmitters: invisible, full alpha.
  Marker hiddenMarker() => Marker(
        markerId: MarkerId('site-1'),
        visible: false,
        alpha: 0.95,
      );

  test('an inactive, visible site is shown at half alpha', () {
    final Marker m = GetDevices.markerAfterDevices(
      hiddenMarker(),
      visible: true,
      active: false,
      baseAlpha: 0.95,
    );

    expect(m.visible, isTrue);
    expect(m.alpha, closeTo(0.475, 1e-9));
  });

  test('an active site keeps the base alpha', () {
    final Marker m = GetDevices.markerAfterDevices(
      hiddenMarker(),
      visible: true,
      active: true,
      baseAlpha: 0.95,
    );

    expect(m.visible, isTrue);
    expect(m.alpha, closeTo(0.95, 1e-9));
  });

  test('applying it twice does not halve the alpha again', () {
    final Marker once = GetDevices.markerAfterDevices(
      hiddenMarker(),
      visible: true,
      active: false,
      baseAlpha: 0.95,
    );
    final Marker twice = GetDevices.markerAfterDevices(
      once,
      visible: true,
      active: false,
      baseAlpha: 0.95,
    );

    expect(twice.alpha, closeTo(0.475, 1e-9));
    expect(twice.visible, isTrue);
  });
}
