import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';

/// Mirrors the Java Android app's DeviceDetailsTest network-type/licence tests, so the two
/// implementations of DeviceDetails.getNetworkTypeStatic / getNetworkTypeForLicence cannot drift
/// silently again. See the Java app's DeviceDetails Javadoc for the full history: hardcoded
/// "antenna-ID sets" (antennas3G4G, antennas3G4G5G, antennas4G5G, ...) used to force LTE/NR on
/// certain antennas regardless of the real carrier, which a live production-DB probe (2026-08)
/// proved was injecting phantom/duplicate 5G — confirmed live on this app (debug build 1.13.6,
/// Pixel 8 Pro): the Lyneham Vodafone CMTS site showed both a "4G 873 MHz" and a "5G 873 MHz" row
/// for the same carrier, because antenna 13198 was hardcoded into both antennas4G and
/// antennas4G5G. The sets are gone; classification is now derived purely from
/// (emission, frequency, bandwidth, telco) via a per-telco frequency table, ported line-for-line
/// from the Java app's networkTypesForEmission.
void main() {
  group('NetworkTypeClassification', () {
    test('formerly-hardcoded antenna IDs no longer force a network type', () {
      // Antenna 13198 used to be hardcoded into both antennas4G and antennas4G5G, forcing
      // [LTE] or [LTE, NR] regardless of the real carrier. A genuine sub-1 GHz Vodafone 'W'
      // (UMTS-class) emission on that antenna must classify purely from its own data: UMTS
      // (refarmed to LTE by default, since 873 MHz sits in the B5/B8 850/900 MHz refarm band) —
      // never NR. This is the exact Lyneham Vodafone CMTS bug: a phantom "5G 873 MHz" row
      // duplicating the real "4G 873 MHz" one.
      final types = DeviceDetails.getNetworkTypeStatic(
          "10M0W7W", 873000000, 10000000, Telco.Vodafone, 13198);
      expect(types.contains(NetworkType.NR), isFalse,
          reason: 'a sub-1 GHz Vodafone carrier must never classify as 5G NR');
      expect(types, [NetworkType.UMTS]);

      final licenceType = DeviceDetails.getNetworkTypeForLicence(
          "10M0W7W", 873000000, 10000000, Telco.Vodafone, 13198);
      expect(licenceType, NetworkType.LTE); // Refarmed by default; still never NR.
    });

    test('Optus n1 2100 D is a genuine dual 4G/5G carrier', () {
      final types = DeviceDetails.getNetworkTypeStatic(
          "20M0W7D", 2140000000, 20000000, Telco.Optus, 0);
      expect(types, [NetworkType.LTE, NetworkType.NR]);
    });

    test('Vodafone n28 700 D is a genuine dual 4G/5G carrier', () {
      final types = DeviceDetails.getNetworkTypeStatic(
          "15M0W7D", 758000000, 15000000, Telco.Vodafone, 0);
      expect(types, [NetworkType.LTE, NetworkType.NR]);
    });

    test('Telstra 14M9G7W 700 is a genuine dual 4G/5G carrier', () {
      final types = DeviceDetails.getNetworkTypeStatic(
          "14M9G7W", 758000000, 14900000, Telco.Telstra, 0);
      expect(types, [NetworkType.LTE, NetworkType.NR]);
    });

    test('Telstra 14M9G7W 850 is a genuine dual 4G/5G carrier', () {
      final types = DeviceDetails.getNetworkTypeStatic(
          "14M9G7W", 883000000, 14900000, Telco.Telstra, 0);
      expect(types, [NetworkType.LTE, NetworkType.NR]);
    });

    test('Optus 900 D is a genuine dual 4G/5G carrier (B8 + n8)', () {
      // Real ACMA fixture (live-probed 2026-08-22): the single 25 MHz-wide Optus 900-band
      // carrier at Tuggeranong-area sites, 25M0W7D @ 947.5 MHz centre. A live Optus 5G SA
      // NR cell at 939 MHz (Band n8) was measured on-air the same day. Mirrors the Java
      // app's DeviceDetailsTest.optus900D_isGenuineDual4g5g.
      final types = DeviceDetails.getNetworkTypeStatic(
          "25M0W7D", 947500000, 25000000, Telco.Optus, 0);
      expect(types, [NetworkType.LTE, NetworkType.NR]);
    });

    test('Optus 900 W is dual 4G/5G, not UMTS (3G shut down 2024)', () {
      // Same block carried as 25M0W7W at some sites. Mirrors the Java app's
      // DeviceDetailsTest.optus900W_isGenuineDual4g5g_notUmts.
      final types = DeviceDetails.getNetworkTypeStatic(
          "25M0W7W", 947500000, 25000000, Telco.Optus, 0);
      expect(types, [NetworkType.LTE, NetworkType.NR]);
      expect(types.contains(NetworkType.UMTS), isFalse);
    });

    test('Optus 900 W lower bound covers 939.2 MHz', () {
      // The old 'W' arm started at 940 MHz and missed the 939.2 MHz centre named in its
      // own comment. Mirrors the Java app's DeviceDetailsTest.optus900W_lowerBoundCovers939.
      final types = DeviceDetails.getNetworkTypeStatic(
          "10M0W7W", 939200000, 10000000, Telco.Optus, 0);
      expect(types, [NetworkType.LTE, NetworkType.NR]);
    });

    test('Telstra non-14M9G7W emission at 700/850 is LTE only, no NR', () {
      // The dual 4G/5G table entry is keyed on the exact "14M9G7W" emission string - any other
      // 'D' emission in the same band is plain LTE (no genuine 5G indication).
      final types = DeviceDetails.getNetworkTypeStatic(
          "10M0W7D", 758000000, 10000000, Telco.Telstra, 0);
      expect(types, [NetworkType.LTE]);
    });

    test('n77/n78 3.3-3.8 GHz W emission is 5G NR, never 3G', () {
      final types = DeviceDetails.getNetworkTypeStatic(
          "60M0W7W", 3510000000, 60000000, Telco.Optus, 0);
      expect(types, [NetworkType.NR]);
      expect(types.contains(NetworkType.UMTS), isFalse);
    });

    test('B40 2300-2400 MHz W emission is TD-LTE, never 3G', () {
      final types = DeviceDetails.getNetworkTypeStatic(
          "70M0W7W", 2365000000, 70000000, Telco.Optus, 0);
      expect(types, [NetworkType.LTE]);
      expect(types.contains(NetworkType.UMTS), isFalse);
    });

    test('mmWave n257/n258 D emission is 5G NR', () {
      final types = DeviceDetails.getNetworkTypeStatic(
          "20M0W7D", 26000000000, 800000000, Telco.Optus, 0);
      expect(types, [NetworkType.NR]);
    });

    // --- One correct transmitter per licence (mirrors Java's getNetworkTypeForLicence tests) ---

    test('licence: a genuine 5G-band row is shown as NR', () {
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7D", 3565000000, 20000000, Telco.Telstra, 0),
          NetworkType.NR);
    });

    test('licence: a dual-tech carrier shows the newest genuine technology', () {
      // A carrier the data treats as both 4G and 5G (Optus n1 2100 'D') is shown as 5G, not
      // downgraded to 4G.
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7D", 2140000000, 20000000, Telco.Optus, 0),
          NetworkType.NR);
    });

    test('licence: formerly-hardcoded dual-antenna IDs are not phantom 5G', () {
      // Antennas 80562/93658 used to be hardcoded into antennas3G4G5G/antennas4G5G. They carry
      // only 2100 MHz 3G/4G 'W' rows - no genuine 5G indication - so with the sets gone they
      // classify as LTE (refarmed from UMTS by default), never NR.
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Telstra, 80562),
          NetworkType.LTE);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2117000000, 14000000, Telco.Optus, 93658),
          NetworkType.LTE);
    });

    test('licence: every row becomes exactly one transmitter', () {
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7D", 3565000000, 20000000, Telco.Optus, 0),
          NetworkType.NR);
      // 2100 MHz 'W' UMTS refarmed to LTE by default (refarming ON).
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Optus, 0),
          NetworkType.LTE);
    });

    test('licence: a UMTS emission outside any refarm band stays UMTS', () {
      expect(
          DeviceDetails.getNetworkTypeForLicence("10M0W7W", 0, 10000000, Telco.Vodafone, 0),
          NetworkType.UMTS);
    });

    test('licence: refarming disabled shows the literal 3G type', () {
      final saved = DeviceDetails.refarmEnabled;
      try {
        DeviceDetails.refarmEnabled = false;
        expect(
            DeviceDetails.getNetworkTypeForLicence(
                "20M0W7W", 2140000000, 20000000, Telco.Optus, 0),
            NetworkType.UMTS);
      } finally {
        DeviceDetails.refarmEnabled = saved;
      }
    });
  });
}
