import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/pathloss/transmit_power.dart';

/// Unit tests for the path-loss model v2 `P` term (spec section 3). The shared cross-app vectors
/// in test/pathloss/shared_vectors_test.dart additionally pin [TransmitPower.subcarriers] and
/// [TransmitPower.perReEirpDbm] against an independent Python port; these tests cover the
/// branches and edge cases the vectors don't happen to hit.
void main() {
  group('TransmitPowerTest', () {
    group('subcarriers - LTE', () {
      test('exact standard bandwidths use the resource-block table', () {
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 1400000), 12 * 6);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 3000000), 12 * 15);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 5000000), 12 * 25);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 10000000), 12 * 50);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 15000000), 12 * 75);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 20000000), 12 * 100);
      });

      test('non-standard bandwidths (multi-carrier ACMA licences) use the formula', () {
        // N_RB = max(1, floor(0.9 * bandwidthHz / 180000)).
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 25000000), 12 * 125);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 30000000), 12 * 150);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 35000000), 12 * 175);
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 40000000), 12 * 200);
      });

      test('a vanishingly small bandwidth still returns at least one resource block', () {
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 1), 12 * 1);
      });

      test('a standard bandwidth within 1 Hz still matches (ACMA records are not bit-exact)', () {
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 1400000.4), 12 * 6);
      });

      test('just outside the 1 Hz tolerance falls through to the formula, not the table', () {
        // floor(0.9 * 1400002 / 180000) = floor(7.0000099...) = 7, not the table's 6.
        expect(TransmitPower.subcarriers(NetworkType.LTE, 1865.0, 1400002), 12 * 7);
      });
    });

    group('subcarriers - unsupported network types', () {
      test('throws ArgumentError for anything but LTE and NR', () {
        for (final NetworkType nt in <NetworkType>[
          NetworkType.GSM,
          NetworkType.UMTS,
          NetworkType.CDMA,
          NetworkType.NB_IOT,
          NetworkType.OTHER,
          NetworkType.UNKNOWN,
        ]) {
          expect(() => TransmitPower.subcarriers(nt, 1865.0, 20000000),
              throwsArgumentError, reason: '$nt');
        }
      });
    });

    group('subcarriers - NR', () {
      test('TDD band n40 (2300-2400 MHz) uses 30 kHz SCS, inclusive of the lower edge', () {
        // N_RB = max(1, floor(0.95 * bandwidthHz / (12 * scsHz))).
        expect(TransmitPower.subcarriers(NetworkType.NR, 2300.0, 10000000), 12 * 26);
        expect(TransmitPower.subcarriers(NetworkType.NR, 2399.0, 10000000), 12 * 26);
      });

      test('2400 MHz itself is outside n40: back to 15 kHz SCS', () {
        expect(TransmitPower.subcarriers(NetworkType.NR, 2400.0, 10000000), 12 * 52);
      });

      test('n78 (>= 3300 MHz) uses 30 kHz SCS, inclusive of the lower edge', () {
        expect(TransmitPower.subcarriers(NetworkType.NR, 3300.0, 10000000), 12 * 26);
        expect(TransmitPower.subcarriers(NetworkType.NR, 3510.0, 10000000), 12 * 26);
      });

      test('just below 3300 MHz still uses 15 kHz SCS', () {
        expect(TransmitPower.subcarriers(NetworkType.NR, 3299.0, 10000000), 12 * 52);
      });

      test('sub-1 GHz bands use 15 kHz SCS', () {
        expect(TransmitPower.subcarriers(NetworkType.NR, 885.0, 10000000), 12 * 52);
      });
    });

    group('isTddBand', () {
      test('n40 (2300-2400 MHz), inclusive of the lower edge, exclusive of the upper', () {
        expect(TransmitPower.isTddBand(2300.0), isTrue);
        expect(TransmitPower.isTddBand(2399.0), isTrue);
        expect(TransmitPower.isTddBand(2400.0), isFalse);
      });

      test('n78 (>= 3300 MHz), inclusive of the lower edge', () {
        expect(TransmitPower.isTddBand(3299.0), isFalse);
        expect(TransmitPower.isTddBand(3300.0), isTrue);
        expect(TransmitPower.isTddBand(3510.0), isTrue);
      });

      test('everything else (sub-1 GHz, and the 2400-3300 MHz gap) is FDD', () {
        expect(TransmitPower.isTddBand(700.0), isFalse);
        expect(TransmitPower.isTddBand(1865.0), isFalse);
        expect(TransmitPower.isTddBand(2650.0), isFalse);
      });
    });

    group('isUsableEirp', () {
      test('positive finite eirp and bandwidth is usable', () {
        expect(TransmitPower.isUsableEirp(100.0, 20000000.0), isTrue);
      });

      test('non-positive eirp is not usable', () {
        expect(TransmitPower.isUsableEirp(0.0, 20000000.0), isFalse);
        expect(TransmitPower.isUsableEirp(-5.0, 20000000.0), isFalse);
      });

      test('non-finite eirp is not usable', () {
        expect(TransmitPower.isUsableEirp(double.nan, 20000000.0), isFalse);
        expect(TransmitPower.isUsableEirp(double.infinity, 20000000.0), isFalse);
      });

      test('non-positive or non-finite bandwidth is not usable', () {
        expect(TransmitPower.isUsableEirp(100.0, 0.0), isFalse);
        expect(TransmitPower.isUsableEirp(100.0, -5.0), isFalse);
        expect(TransmitPower.isUsableEirp(100.0, double.nan), isFalse);
      });
    });

    group('looksLikeDbScale', () {
      test('eirp that reads back as dBm within 0.05 dB of the HRP maximum looks dB-scale', () {
        // 10*log10(10.0) + 30 == 40.0 exactly.
        expect(TransmitPower.looksLikeDbScale(10.0, 40.0), isTrue);
      });

      test('a genuine Watts-scale eirp does not look dB-scale', () {
        expect(TransmitPower.looksLikeDbScale(10.5, 40.0), isFalse);
        expect(TransmitPower.looksLikeDbScale(13489.6, 40.0), isFalse);
      });

      test('non-positive or non-finite inputs never look dB-scale', () {
        expect(TransmitPower.looksLikeDbScale(0.0, 40.0), isFalse);
        expect(TransmitPower.looksLikeDbScale(double.nan, 40.0), isFalse);
        expect(TransmitPower.looksLikeDbScale(10.0, double.nan), isFalse);
      });
    });

    group('perReEirpDbm', () {
      test('divides the wideband EIRP among the subcarriers, in dB', () {
        // 10*log10(1000) + 30 - 10*log10(1) = 30 + 30 - 0 = 60.
        expect(TransmitPower.perReEirpDbm(1000.0, 1), closeTo(60.0, 1e-9));
        // 10*log10(1000) + 30 - 10*log10(1000) = 30 + 30 - 30 = 30.
        expect(TransmitPower.perReEirpDbm(1000.0, 1000), closeTo(30.0, 1e-9));
      });

      test('more subcarriers means less power per resource element', () {
        final double fewer = TransmitPower.perReEirpDbm(1000.0, 100);
        final double more = TransmitPower.perReEirpDbm(1000.0, 1000);
        expect(more, lessThan(fewer));
      });
    });

    group('estimatedPatternLossDb', () {
      test('omnidirectional (null azimuth) has no pattern loss', () {
        expect(TransmitPower.estimatedPatternLossDb(null, 123.0, 25.0), 0.0);
      });

      test('boresight (bearing == azimuth) has no pattern loss', () {
        expect(TransmitPower.estimatedPatternLossDb(200.0, 200.0, 25.0), 0.0);
      });

      test('loss increases from boresight out to the front-to-back ratio, then clamps', () {
        double lossAt(double bearing) =>
            TransmitPower.estimatedPatternLossDb(0.0, bearing, 25.0);

        expect(lossAt(0), 0.0);
        expect(lossAt(30), lessThan(lossAt(60)));
        expect(lossAt(60), lessThan(lossAt(90)));
        expect(lossAt(90), closeTo(25.0, 1e-9));
        // Beyond 90 degrees the raw (1-cos)^1.15 curve exceeds the front-to-back ratio, so it
        // is clamped there for the rest of the way to the back lobe.
        expect(lossAt(120), closeTo(25.0, 1e-9));
        expect(lossAt(150), closeTo(25.0, 1e-9));
        expect(lossAt(180), closeTo(25.0, 1e-9));
      });

      test('never exceeds the front-to-back ratio, for a dense sweep including angles beyond '
          '+/-360 degrees', () {
        const double frontToBack = 18.0;
        for (double bearing = -720.0; bearing <= 720.0; bearing += 5.0) {
          final double loss = TransmitPower.estimatedPatternLossDb(37.0, bearing, frontToBack);
          expect(loss.isNaN, isFalse, reason: 'bearing=$bearing');
          expect(loss, inInclusiveRange(0.0, frontToBack), reason: 'bearing=$bearing');
        }
      });

      test('is not reduced (wrapped) to [0, 180] before the loss is computed, but the loss is '
          'the same as the physically-equivalent wrapped angle because cosine is periodic', () {
        final double unwrapped = TransmitPower.estimatedPatternLossDb(350.0, 10.0, 25.0);
        final double wrapped = TransmitPower.estimatedPatternLossDb(0.0, 20.0, 25.0);
        expect(unwrapped, wrapped);
      });

      test('scales with the front-to-back ratio', () {
        final double narrow = TransmitPower.estimatedPatternLossDb(0.0, 45.0, 10.0);
        final double wide = TransmitPower.estimatedPatternLossDb(0.0, 45.0, 30.0);
        expect(narrow, lessThan(wide));
      });
    });
  });
}
