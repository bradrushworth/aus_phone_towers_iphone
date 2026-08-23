import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/model/device_detail.dart';

/// The basic (non-licence_hrp) polygon's radiation pattern. The (1-cos)^1.15 curve is tuned
/// for the main lobe (-3 dB at 32 deg off boresight) but was unbounded behind the antenna:
/// 2.22x the front-to-back ratio at 180 deg (~55 dB with the 25 dB default), while
/// front-to-back ratio IS the rear attenuation by definition. Validated against 45 real
/// licence_hrp patterns (2026-08-22): the clamp takes the back-lobe error from -23.6 dB
/// median to -1.1 dB with boresight and side sectors unchanged. Mirrors the Java app's
/// DeviceDetailsTest.backLobeAttenuationClampsAtFrontToBack.
void main() {
  DeviceDetails device() => DeviceDetails(networkType: NetworkType.LTE)
    ..eirp = 2000.0
    ..azimuth = 0; // antenna == null -> defaults: gain 16 dBi, F/B 25 dB, beamwidth 60 deg

  test('behind the antenna the attenuation is exactly the front-to-back ratio', () {
    final d = device();
    expect(d.getPowerAtBearing(0) - d.getPowerAtBearing(180), closeTo(25.0, 0.001));
  });

  test('omni antennas are calibrated and flat', () {
    // No azimuth = omnidirectional. Measured against 17 real omni devices (6,120 licence_hrp
    // rows): without omniCalibrationDb the estimate ran 13.5 dB below the real (flat)
    // pattern — omni polygons rendered ~2.4x too small. Mirrors the Java app.
    final d = DeviceDetails(networkType: NetworkType.LTE)..eirp = 2000.0;
    final p = d.getPowerAtBearing(0);
    expect(p, closeTo(d.getPowerAtBearing(137), 0.001));
    // dBm(2000 W) = 63.0, +3 empirical, -41.7 shared constant, +13.5 omni calibration
    expect(p, closeTo(37.81, 0.05));
  });

  test('main lobe shape is unchanged by the back-lobe clamp', () {
    final d = device();
    final front = d.getPowerAtBearing(0);
    // ~-3 dB at 32 deg off boresight (the curve's design point).
    expect(front - d.getPowerAtBearing(32), closeTo(2.9, 0.5));
    // 90 deg off = exactly F/B, the clamp boundary (no behaviour change).
    expect(front - d.getPowerAtBearing(90), closeTo(25.0, 0.001));
  });
}
