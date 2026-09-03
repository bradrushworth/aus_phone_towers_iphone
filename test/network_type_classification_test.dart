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

    test('Telstra 850 W is dual 4G/5G, not UMTS (3G850 shut down October 2024)', () {
      // Real ACMA fixture (live-probed 2026-08-22): 9M90G7W @ 882.5 MHz is the dominant
      // Telstra 850-band register row; production holds 86,643 Telstra NR n5 observations
      // (787 cells) in the last two years. Mirrors the Java app's
      // DeviceDetailsTest.telstra850W_isGenuineDual4g5g_notUmts.
      final types = DeviceDetails.getNetworkTypeStatic(
          "9M90G7W", 882500000, 9900000, Telco.Telstra, 0);
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
      // only 2100 MHz 3G/4G 'W' rows - no genuine 5G indication from the ANTENNA - so the
      // antenna id must never be what decides the type. The classifier still reports the
      // literal licence as UMTS for both rows. The refarm of that legacy-only 2100 'W' carrier
      // is now telco-aware (2026-09, Java app GitHub #60): Telstra has no n1 5G SA in
      // production observed_cell, so its reuse is LTE only; Optus runs n1 SA (920 rows / 62
      // cells / 15 regions / 29 devices since 2026-01-01 - the #60 Pixel is served on n1 at
      // 2137 MHz from a site carrying 20M0W7W @ 2140 MHz), so its reuse is [LTE, NR] and the
      // display pick is the newest genuine technology. With refarming OFF both fall back to
      // UMTS (see 'refarming disabled shows the literal 3G type'). Mirrors the Java app's
      // DeviceDetailsTest.licence_legacyDualAntennaSetsNotPhantom5g.
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Telstra, 80562),
          NetworkType.LTE);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2117000000, 14000000, Telco.Optus, 93658),
          NetworkType.NR);
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "20M0W7W", 2117000000, 14000000, Telco.Optus, 93658),
          [NetworkType.UMTS]);
    });

    test('licence: every row becomes exactly one transmitter', () {
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7D", 3565000000, 20000000, Telco.Optus, 0),
          NetworkType.NR);
      // Optus 2100 MHz 'W' UMTS refarmed to its live [LTE, NR] reuse by default (refarming ON),
      // shown once as its newest genuine technology; Telstra's refarms to LTE only.
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Optus, 0),
          NetworkType.NR);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Telstra, 0),
          NetworkType.LTE);
    });

    test('licence: Optus 900 MHz dual carrier displays as LTE, not NR (GitHub #55)', () {
      // St George QLD, Broadcast Australia site 15491: the Optus 900 MHz block classifies
      // as a genuine dual [LTE, NR] carrier (see getNetworkTypeStatic tests above), but
      // that NR indication is generalised from a single live-verified metro cell
      // (Tuggeranong ACT), not confirmed at this rural site. A knowledgeable local
      // reported this tower has 4G only. Unlike the Optus 2100 / Telstra 850 / Vodafone
      // 700 dual carriers (widely verified NR deployments), the Optus 900 band prefers the
      // universally-present LTE for its single displayed technology.
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "25M0W7D", 947500000, 25000000, Telco.Optus, 0),
          NetworkType.LTE);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "25M0W7W", 947500000, 25000000, Telco.Optus, 0),
          NetworkType.LTE);
      // The underlying classifier is untouched: it still reports the full dual list.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "25M0W7D", 947500000, 25000000, Telco.Optus, 0),
          [NetworkType.LTE, NetworkType.NR]);
    });

    test('licence: Optus 2100 MHz dual carrier still displays as NR (not affected by #55 fix)',
        () {
      // Confirms the Optus 900 MHz override above is scoped to that band only -- the
      // widely-verified Optus 2100 MHz dual carrier keeps showing the newest technology.
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7D", 2140000000, 20000000, Telco.Optus, 0),
          NetworkType.NR);
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

    // --- New NR arms proven by production observed_cell (registered 5G SA rows since
    // 2026-01-01, mcc 505; rows / distinct cells / distinct geohash-3 regions / distinct
    // devices). Mirrors the Java app's DeviceDetailsTest (GitHub #60, 2026-09-02). A handful of
    // rows is NOT enough (Telstra n8 = 5 rows, n18 = 13 rows are deliberately NOT added).

    test('Optus 2300 D is a genuine dual 4G/5G carrier (B40 + n40)', () {
      // Optus n40: 1,196 / 61 / 7 / 16. Home-site row for the Java app's GitHub #60:
      // 70M0W7D @ 2365 MHz. Mirrors DeviceDetailsTest.optus2300D_isGenuineDual4g5g_n40.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "70M0W7D", 2365000000, 70000000, Telco.Optus, 0),
          [NetworkType.LTE, NetworkType.NR]);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "70M0W7D", 2365000000, 70000000, Telco.Optus, 0),
          NetworkType.NR);
    });

    test('Optus 2300 W stays TD-LTE only until proven', () {
      // The B40 'W' arm is shared by every telco and is not part of this change: the n40
      // evidence was gathered against 'D' rows. Pinned so a future widening is deliberate.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "70M0W7W", 2365000000, 70000000, Telco.Optus, 0),
          [NetworkType.LTE]);
    });

    test('Optus 2100 W refarms to dual 4G/5G (n1)', () {
      // Optus n1: 920 / 62 / 15 / 29. Register rows near the #60 Pixel: 20M0W7W @ 2140 MHz,
      // which used to refarm to LTE only while the Pixel sat on n1 SA at 2137 MHz.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "20M0W7W", 2140000000, 20000000, Telco.Optus, 0),
          [NetworkType.UMTS]);
      expect(
          DeviceDetails.getCapableTypesForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Optus, 0),
          [NetworkType.LTE, NetworkType.NR]);
    });

    test('Vodafone 2100 W refarms to dual 4G/5G (n1)', () {
      // Vodafone n1: 4,759 / 375 / 12 / 68 (14M0W7WEC @ 2117.6 MHz is the real register shape).
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "14M0W7WEC", 2117600000, 14000000, Telco.Vodafone, 0),
          [NetworkType.UMTS]);
      expect(
          DeviceDetails.getCapableTypesForLicence(
              "14M0W7WEC", 2117600000, 14000000, Telco.Vodafone, 0),
          [NetworkType.LTE, NetworkType.NR]);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "14M0W7WEC", 2117600000, 14000000, Telco.Vodafone, 0),
          NetworkType.NR);
    });

    test('Telstra 2100 W refarms to LTE only (no n1 evidence)', () {
      // Telstra has no n1 5G SA in production observed_cell, so its 2100 'W' reuse stays LTE.
      expect(
          DeviceDetails.getCapableTypesForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Telstra, 0),
          [NetworkType.LTE]);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Telstra, 0),
          NetworkType.LTE);
    });

    test('refarm is only for legacy-only rows, not for bands outside the refarm table', () {
      // The telco-aware 2100 refarm must not leak into other 'W' UMTS bands: Vodafone 900 'W'
      // is still classified as (and refarmed to) what the existing tables say.
      expect(
          DeviceDetails.getCapableTypesForLicence(
              "4M20G7W", 956000000, 4200000, Telco.Vodafone, 0),
          [NetworkType.LTE]);
      // and a UMTS row outside every refarm band stays UMTS
      expect(
          DeviceDetails.getCapableTypesForLicence("10M0W7W", 0, 10000000, Telco.Vodafone, 0),
          [NetworkType.UMTS]);
    });

    test('refarmed legacy carrier reports its live reuse, or the literal type when disabled', () {
      // Mirrors DeviceDetailsTest.capability_refarmedLegacyCarrierReportsItsLiveReuse.
      expect(
          DeviceDetails.getCapableTypesForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Optus, 0),
          [NetworkType.LTE, NetworkType.NR]);
      expect(
          DeviceDetails.getCapableTypesForLicence(
              "20M0W7W", 2140000000, 20000000, Telco.Telstra, 0),
          [NetworkType.LTE]);
      final saved = DeviceDetails.refarmEnabled;
      try {
        DeviceDetails.refarmEnabled = false;
        expect(
            DeviceDetails.getCapableTypesForLicence(
                "20M0W7W", 2140000000, 20000000, Telco.Optus, 0),
            [NetworkType.UMTS]);
      } finally {
        DeviceDetails.refarmEnabled = saved;
      }
    });

    test('Telstra 2600 D is a genuine dual 4G/5G carrier (B7 + n7)', () {
      // Telstra n7: 8,794 / 567 / 13 / 128 - the arm previously said "No NR".
      // Mirrors DeviceDetailsTest.telstra2600D_isGenuineDual4g5g_n7.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "20M0W7D", 2650000000, 20000000, Telco.Telstra, 0),
          [NetworkType.LTE, NetworkType.NR]);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7D", 2650000000, 20000000, Telco.Telstra, 0),
          NetworkType.NR);
    });

    test('Vodafone 1800 D is a genuine dual 4G/5G carrier (B3 + n3)', () {
      // Vodafone n3: 1,586 / 123 / 9 / 51.
      // Mirrors DeviceDetailsTest.vodafone1800D_isGenuineDual4g5g_n3.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "20M0W7D", 1840000000, 20000000, Telco.Vodafone, 0),
          [NetworkType.LTE, NetworkType.NR]);
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "20M0W7D", 1840000000, 20000000, Telco.Vodafone, 0),
          NetworkType.NR);
    });

    test('Vodafone 2100 D is a genuine dual 4G/5G carrier (B1 + n1)', () {
      // Vodafone n1: 4,759 / 375 / 12 / 68.
      // Mirrors DeviceDetailsTest.vodafone2100D_isGenuineDual4g5g_n1.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "5M00W7D", 2162400000, 5000000, Telco.Vodafone, 0),
          [NetworkType.LTE, NetworkType.NR]);
    });

    test('Telstra 900 and 1800 D remain LTE only (too few rows)', () {
      // Telstra n8 (5 rows) and n18 (13 rows) are noise-level; Telstra/Optus 1800 'D' and
      // Telstra 900 'D' keep their existing LTE-only classification.
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "20M0W7D", 1840000000, 20000000, Telco.Telstra, 0),
          [NetworkType.LTE]);
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "20M0W7D", 1840000000, 20000000, Telco.Optus, 0),
          [NetworkType.LTE]);
      expect(
          DeviceDetails.getNetworkTypeStatic(
              "10M0W7D", 947500000, 10000000, Telco.Telstra, 0),
          [NetworkType.LTE]);
    });

    test('licence: Optus 900 MHz LTE-display exception survives the new NR arms (GitHub #55)',
        () {
      // The #55 display override is untouched by the #60 arms: the block is still capable of
      // [LTE, NR] (observed_cell since 2026-01-01: 1,682 Optus n8 SA rows / 106 cells /
      // 18 regions) but displays as LTE by policy. Mirrors
      // DeviceDetailsTest.capability_optus900DisplaysLteButIsCapableOfNr.
      expect(
          DeviceDetails.getNetworkTypeForLicence(
              "25M0W7D", 947500000, 25000000, Telco.Optus, 0),
          NetworkType.LTE);
      expect(
          DeviceDetails.getCapableTypesForLicence(
              "25M0W7D", 947500000, 25000000, Telco.Optus, 0),
          [NetworkType.LTE, NetworkType.NR]);
    });

    test('licence: the display type is always one of the capable types', () {
      // Whatever the display policy picks must be something the row can actually do.
      // Mirrors DeviceDetailsTest.capability_displayTypeIsAlwaysOneOfTheCapableTypes.
      final rows = <List<Object>>[
        ["25M0W7D", 947500000, 25000000, Telco.Optus],
        ["20M0W7W", 2140000000, 20000000, Telco.Optus],
        ["20M0W7W", 2140000000, 20000000, Telco.Telstra],
        ["70M0W7D", 2365000000, 70000000, Telco.Optus],
        ["20M0W7D", 3565000000, 20000000, Telco.Telstra],
        ["8M40G7E", 939200000, 8400000, Telco.Telstra],
      ];
      for (final r in rows) {
        final display = DeviceDetails.getNetworkTypeForLicence(
            r[0] as String, r[1] as int, r[2] as int, r[3] as Telco, 0);
        final capable = DeviceDetails.getCapableTypesForLicence(
            r[0] as String, r[1] as int, r[2] as int, r[3] as Telco, 0);
        expect(capable.contains(display), isTrue,
            reason: '${r[0]} ${r[3]}: display $display not in $capable');
      }
    });
  });
}
