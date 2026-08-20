import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';

/// Ported from the Java Android app's ChristmasIslandClassificationTest. Pins how
/// DeviceDetails.getNetworkTypeStatic classifies the real Christmas Island Telstra transmitters.
/// The emission designators, frequencies and bandwidths below are the actual values from the
/// ACMA RRL, read from the production database on 2026-08-20.
///
/// How a transmitter is classified is a property of our code - it must never change without us
/// noticing, and it does not need a database to check, since classification is a pure function
/// of (emission, frequency, bandwidth, telco, antenna). This is deliberately a plain unit test,
/// not an integration test against the live database.
void main() {
  group('ChristmasIslandClassification', () {
    // Real rows from device_details_mobile_telstra for the Christmas Island sites.
    const emission778 = "20M0W7D";
    const emission864 = "10M0W7D";
    const emission939 = "8M40G7E";

    List<NetworkType> classify(String emission, int freqHz, int bandwidthHz, int antennaId) {
      return DeviceDetails.getNetworkTypeStatic(
          emission, freqHz, bandwidthHz, Telco.Telstra, antennaId);
    }

    test('778 MHz (band 28) 20M0W7D must classify as 4G LTE', () {
      expect(classify(emission778, 778000000, 20000000, 81535).first, NetworkType.LTE);
    });

    test('864 MHz (band 5) 10M0W7D must classify as 4G LTE', () {
      expect(classify(emission864, 864000000, 10000000, 81417).first, NetworkType.LTE);
    });

    test('939.2 MHz 8M40G7E must classify as 2G GSM and not be refarmed', () {
      final types = classify(emission939, 939200000, 8400000, 80163);
      expect(types.first, NetworkType.GSM);
      expect(types.contains(NetworkType.LTE), isFalse,
          reason: '939.2 MHz GSM must not be classified as LTE');
      expect(types.contains(NetworkType.NR), isFalse,
          reason: '939.2 MHz GSM must not be classified as NR');
    });

    test('no sub-1 GHz Christmas Island carrier is ever classified as NR', () {
      const nrMessage = 'a sub-1 GHz Christmas Island carrier must not classify as 5G NR';
      expect(classify(emission778, 778000000, 20000000, 81535).contains(NetworkType.NR), isFalse,
          reason: nrMessage);
      expect(classify(emission864, 864000000, 10000000, 81417).contains(NetworkType.NR), isFalse,
          reason: nrMessage);
      expect(classify(emission939, 939200000, 8400000, 80163).contains(NetworkType.NR), isFalse,
          reason: nrMessage);
    });
  });
}
