import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/helpers/let_type_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/model/antenna.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/site.dart';

void main() {
  group('DeviceDetailsTest', () {
    late Site site;
    late DeviceDetails deviceDetails;

    setUp(() {
      site = new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN);

      deviceDetails = new DeviceDetails(networkType: NetworkType.LTE);
      deviceDetails.setSite(site);
      deviceDetails.bandwidth = 20000000;
    });

    test('formatNetworkSpeed', () {
      expect(DeviceDetails.formatNetworkSpeed(207618048), "198 Mbps");
      expect(DeviceDetails.formatNetworkSpeed(33554432), "32 Mbps");
      expect(DeviceDetails.formatNetworkSpeed(1073741824), "1.0 Gbps");
      expect(DeviceDetails.formatNetworkSpeed(923795456), "881 Mbps");
      expect(
          DeviceDetails.formatNetworkSpeed(2362232012), "2.2 Gbps"); // Not sure how to round down
      expect(DeviceDetails.formatNetworkSpeed(57344), "56 kbps");
      expect(DeviceDetails.formatNetworkSpeed(128), "128  bps");
    });

    test('isActiveTrueNotTelecoms', () {
      deviceDetails.active = "";
      deviceDetails.setSite(new Site(telco: Telco.Aviation, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.isActive(), true);
    });

    test('isActiveTrueValue', () {
      deviceDetails.active = "stuff";
      expect(deviceDetails.isActive(), true);
    });

    test('isActiveFalse', () {
      deviceDetails.active = "";
      expect(deviceDetails.isActive(), false);
    });

    test('isMultiConditionCodeFalseShort', () {
      deviceDetails.emission = "10M0W7D";
      expect(deviceDetails.isMultiConditionCode(), false);
    });

    test('isMultiConditionCodeFalse', () {
      deviceDetails.emission = "3M84G7W--";
      expect(deviceDetails.isMultiConditionCode(), false);
    });

    test('isMultiConditionCodeTrue', () {
      deviceDetails.emission = "9M00W7WEC";
      expect(deviceDetails.isMultiConditionCode(), true);
    });

    test('isMIMOTrue', () {
      deviceDetails.polarisation = "S";
      expect(deviceDetails.isMIMO(), true);
    });

    test('isMIMOFalse', () {
      deviceDetails.polarisation = "V";
      expect(deviceDetails.isMIMO(), false);
    });

    test('getAntennaCapacityLP', () {
      deviceDetails.bandwidth = 8200000;
      deviceDetails.emission = "8M20W7W";
      deviceDetails.frequency = 955900000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.NB_IOT);
      expect(deviceDetails.getAntennaCapacity(), 42509710);
    });

    test('getAntennaCapacityGSM', () {
      // Still at Christmas Island
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "8M40G7E";
      deviceDetails.frequency = 1840000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.GSM);
      expect(deviceDetails.getAntennaCapacity(), 13545000);
    });

    test('getAntennaCapacityUMTS', () {
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "9M00W7WEC";
      deviceDetails.frequency = 1840000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
      expect(deviceDetails.getAntennaCapacity(), 44249907);
    });

    test('getAntennaCapacityFD_LTE', () {
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 1840000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
      expect(deviceDetails.getAntennaCapacity(), 51841110);
    });

    test('getAntennaCapacityTD_LTE', () {
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "19M9W7DEW";
      deviceDetails.frequency = 1840000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
      expect(deviceDetails.getAntennaCapacity(), 38510539);
    });

    test('getAntennaCapacityTD_NR', () {
      deviceDetails.bandwidth = 20000000;
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 3565000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
      expect(deviceDetails.getAntennaCapacity(), 490104422);
    });

    test('getAntennaCapacityTD_NR_mmWave', () {
      deviceDetails.bandwidth = 20000000;
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 26000000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
      expect(deviceDetails.getAntennaCapacity(), 490104422);
    });

    test('getNetworkTypeNR', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 3565000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
    });

    test('getNetworkTypeNR_mmWave', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 26000000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
    });

    test('getNetworkTypeLTE', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 1840000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getNetworkTypeLTE_AmbigiousWithNR', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 1840000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getNetworkTypeUMTS', () {
      deviceDetails.emission = "3M84G7W--";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getNetworkTypeUMTS1', () {
      deviceDetails.emission = "10M0W7W";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getNetworkTypeUMTS2', () {
      deviceDetails.emission = "9M00W7WEC";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getNetworkTypeGSM', () {
      deviceDetails.emission = "8M40G7E";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getNetworkType(), NetworkType.GSM);
    });

    test('getLteType_FD_LTE', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 1840000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getLteType_FD_LTE_Optus', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 763000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getLteType_TD_LTE_Optus', () {
      deviceDetails.emission = "80M0W7D";
      deviceDetails.frequency = 2342000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
    });

    test('getLteType_TD_LTE_NBN', () {
      deviceDetails.emission = "19M9W7DEW";
      deviceDetails.frequency = 3507000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_5G_NR', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 3565000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_UMTS', () {
      deviceDetails.emission = "3M84G7W--";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_UMTS2', () {
      deviceDetails.emission = "9M00W7WEC";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_UMTS3', () {
      deviceDetails.emission = "9M90G7WEC";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_GSM', () {
      deviceDetails.emission = "8M40G7E";
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission, 0, 0, deviceDetails.getSite().getTelco(), 0)
          .first;
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.GSM);
    });

    test('getLteType_Vodafone_4G_735', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 735500000;
      deviceDetails.bandwidth = 5000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_4G_790', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 790500000;
      deviceDetails.bandwidth = 5000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_TPG_4G_798', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 798000000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_5G_795', () {
      deviceDetails.emission = "15M0W7D";
      deviceDetails.frequency = 795650000;
      deviceDetails.bandwidth = 15000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Vodafone_LP_955', () {
      // Either this one or the test below is NB-IoT
      deviceDetails.emission = "8M20W7W";
      deviceDetails.frequency = 955900000;
      deviceDetails.bandwidth = 8200000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NB_IOT);
    });

    test('getLteType_Vodafone_UMTS_956', () {
      deviceDetails.emission = "4M20G7W";
      deviceDetails.frequency = 956200000;
      deviceDetails.bandwidth = 5000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_TPG_2625', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 2625000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_3G', () {
      deviceDetails.emission = "14M0W7WEC";
      deviceDetails.frequency = 2117600000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_Telstra_4G_2100', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 2162400000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Optus_4G_2100', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 2162400000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_4G_2100', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 2162400000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_5G_25300', () {
      deviceDetails.emission = "400MW7D";
      deviceDetails.frequency = 25300000000;
      deviceDetails.bandwidth = 400000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_5G_850', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 882500000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Optus_4G_2365', () {
      deviceDetails.emission = "70M0W7D";
      deviceDetails.frequency = 2365000000;
      deviceDetails.bandwidth = 70000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Optus_5G_2351', () {
      deviceDetails.emission = "98M0W7D";
      deviceDetails.frequency = 2349750000;
      deviceDetails.bandwidth = 98000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Optus_5G_26200', () {
      deviceDetails.emission = "1G00W7D";
      deviceDetails.frequency = 26200000000;
      deviceDetails.bandwidth = 1000000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Optus_5G_28000', () {
      deviceDetails.emission = "800MW7D";
      deviceDetails.frequency = 28500000000;
      deviceDetails.bandwidth = 800000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_5G_877', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 877250000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_5G_2662', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 2662950000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails.networkType = NetworkType.NR;
      deviceDetails.setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_4G_Christmas_Island', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 778000000;
      deviceDetails.bandwidth = 20000000;
      deviceDetails.networkType = DeviceDetails.getNetworkTypeStatic(
              deviceDetails.emission,
              deviceDetails.frequency!,
              deviceDetails.bandwidth!,
              deviceDetails.getSite().getTelco(),
              0)
          .first;
      deviceDetails.setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getHeight0', () {
      deviceDetails.height = 0;
      expect(deviceDetails.getTowerHeight(), 10);
    });

    test('getHeight30', () {
      deviceDetails.height = 30;
      expect(deviceDetails.getTowerHeight(), 30);
    });

    test('getPowerAtBearing1', () {
      deviceDetails.eirp = 1472.0;
      // Using null value of bearingToPowerMap variable. No azimuth = omni, which now includes
      // DeviceDetails.omniCalibrationDb (+13.5 dB, measured against real licence_hrp omni
      // patterns on 2026-08-23 — see radiation_pattern_test.dart).
      expect(deviceDetails.getPowerAtBearing(0), closeTo(22.979 + 13.5, 0.001));
    });

    test('getPowerAtBearing2', () {
      deviceDetails.eirp = 6760.0;
      // Using null value of bearingToPowerMap variable (omni: includes omniCalibrationDb).
      expect(deviceDetails.getPowerAtBearing(0), closeTo(29.599 + 13.5, 0.001));
    });

    test('getSite', () {
      expect(deviceDetails.getSite(), site);
    });

    test('testHashCode', () {
      deviceDetails.deviceRegistrationIdentifier = "10240601";
      expect(deviceDetails.hashCode, "10240601".hashCode);
    });

    test('testToString', () {
      deviceDetails.deviceRegistrationIdentifier = "10240601";
      expect(deviceDetails.toString(), "10240601");
    });

    // --- bead aptios-6i0 / keen-moser-3c3ce6-aqw: named-constant chain must reproduce the old
    // literal chain exactly. See DeviceDetails.rsrpConversionDb and .widebandToRsrpConversionDb
    // for why the theoretical, bandwidth-aware conversion is NOT wired into getPowerAtBearing -
    // EirpScaleIT's replay (Android commit 941c8697) found it scores worse than this calibrated
    // constant chain. These tests pin the net numeric behaviour so nobody accidentally
    // "simplifies" the constants into the theoretical value later. Mirrors
    // DeviceDetailsTest.java in the Android app with identical vectors.
    double oldLiteralChain(double eirpWatts, double gainDBi, bool directional) {
      double power = 10 * log10(eirpWatts) + 30;
      power += 3;
      if (directional) {
        power += gainDBi - 2.15;
      }
      power -= 41.7;
      if (!directional) {
        power += 13.5;
      }
      return power;
    }

    const eirpWattsVectors = [0.5, 1.0, 5.0, 20.0, 50.0, 120.0];
    const gainDbiVectors = [0.0, 6.0, 10.0, 16.0, 20.0];
    const bandwidthHzVectors = [1400000, 3000000, 5000000, 10000000, 15000000, 20000000, 100000000];

    test('namedConstantChain_matchesOldLiteralChain_directional', () {
      for (final eirpWatts in eirpWattsVectors) {
        for (final gainDBi in gainDbiVectors) {
          for (final bandwidthHz in bandwidthHzVectors) {
            final device = new DeviceDetails(networkType: NetworkType.LTE);
            device.setSite(site);
            device.eirp = eirpWatts;
            device.bandwidth = bandwidthHz;
            device.azimuth = 90;
            device.antenna = new Antenna()
              ..gain = gainDBi
              ..frontToBack = 25
              ..horizontalBeamwidth = 60;

            final expected = oldLiteralChain(eirpWatts, gainDBi, true);
            final actual = device.getPowerAtBearing(90);
            expect(actual, closeTo(expected, 0.1),
                reason: 'eirp=$eirpWatts gain=$gainDBi bw=$bandwidthHz');
          }
        }
      }
    });

    test('namedConstantChain_matchesOldLiteralChain_omni', () {
      for (final eirpWatts in eirpWattsVectors) {
        for (final bandwidthHz in bandwidthHzVectors) {
          final device = new DeviceDetails(networkType: NetworkType.LTE);
          device.setSite(site);
          device.eirp = eirpWatts;
          device.bandwidth = bandwidthHz;
          device.azimuth = null;

          final expected = oldLiteralChain(eirpWatts, 0.0, false);
          final actual = device.getPowerAtBearing(0);
          expect(actual, closeTo(expected, 0.1), reason: 'eirp=$eirpWatts bw=$bandwidthHz');
        }
      }
    });

    test('widebandToRsrpConversionDb_matchesStandardResourceBlockTable', () {
      // -10*log10(12*N_RB) for the standard LTE bandwidth/N_RB table (3GPP TS 36.101 5.6-1).
      expect(DeviceDetails.widebandToRsrpConversionDb(1400000), closeTo(-18.57, 0.01));
      expect(DeviceDetails.widebandToRsrpConversionDb(3000000), closeTo(-22.55, 0.01));
      expect(DeviceDetails.widebandToRsrpConversionDb(5000000), closeTo(-24.77, 0.01));
      expect(DeviceDetails.widebandToRsrpConversionDb(10000000), closeTo(-27.78, 0.01));
      expect(DeviceDetails.widebandToRsrpConversionDb(15000000), closeTo(-29.54, 0.01));
      expect(DeviceDetails.widebandToRsrpConversionDb(20000000), closeTo(-30.79, 0.01));
      // Bandwidths above 20 MHz clamp to the widest standard LTE table entry rather than
      // extrapolating.
      expect(DeviceDetails.widebandToRsrpConversionDb(100000000), closeTo(-30.79, 0.01));
    });

    test('rsrpConversionDb_isCalibratedNotTheoretical', () {
      // SETTLED 2026-08-25 (bead keen-moser-3c3ce6-aqw): the theoretical 20 MHz value (~-30.8 dB)
      // was tried against real observations and scored worse than the calibrated constant.
      expect(DeviceDetails.rsrpConversionDb,
          lessThan(DeviceDetails.widebandToRsrpConversionDb(20000000)));
    });

    // --- path-loss v2 brief F1: TransmitPower.estimatedPatternLossDb (lib/pathloss/
    // transmit_power.dart) is extracted from this method's inline radiation-pattern-loss
    // computation (spec section 3), and getPowerAtBearing is changed to call it instead of
    // computing the loss inline. These pin the exact numeric output of the CURRENT (pre-
    // refactor) formula -- computed independently from the literal formula, not guessed -- so
    // the refactor cannot change what tower matching sees (spec section 1: getPowerAtBearing
    // "keeps the legacy power and the legacy model"). Mirrors the Android app's DeviceDetailsTest
    // pin for the same call.
    test('getPowerAtBearing_patternLossPin_boresight', () {
      final device = new DeviceDetails(networkType: NetworkType.LTE);
      device.setSite(site);
      device.eirp = 1000.0;
      device.azimuth = 0;
      expect(device.getPowerAtBearing(0), closeTo(35.150000000000, 1e-9));
    });

    test('getPowerAtBearing_patternLossPin_midLobe45', () {
      final device = new DeviceDetails(networkType: NetworkType.LTE);
      device.setSite(site);
      device.eirp = 1000.0;
      device.azimuth = 0;
      expect(device.getPowerAtBearing(45), closeTo(29.059461076611, 1e-9));
    });

    test('getPowerAtBearing_patternLossPin_quarter90', () {
      final device = new DeviceDetails(networkType: NetworkType.LTE);
      device.setSite(site);
      device.eirp = 1000.0;
      device.azimuth = 0;
      expect(device.getPowerAtBearing(90), closeTo(10.150000000000, 1e-9));
    });

    test('getPowerAtBearing_patternLossPin_backLobe180_clamped', () {
      final device = new DeviceDetails(networkType: NetworkType.LTE);
      device.setSite(site);
      device.eirp = 1000.0;
      device.azimuth = 0;
      // Raw (1-cos(180deg))^1.15 * 25 = 2^1.15 * 25 = ~55.6 dB, clamped to frontToBackRatio
      // (25) -- same net result as quarter90 above, which sits exactly at the clamp boundary.
      expect(device.getPowerAtBearing(180), closeTo(10.150000000000, 1e-9));
    });

    test('getPowerAtBearing_patternLossPin_unwrappedAngleMatchesWrapped', () {
      // referenceAngle is not reduced to [0, 180] before cos() -- 340 deg is not wrapped to 20
      // deg -- but cos()'s own periodicity/evenness makes the two bearings physically
      // equivalent anyway. Pins that TransmitPower.estimatedPatternLossDb must not "fix" this
      // by adding a wraparound step that was never there.
      final unwrapped = new DeviceDetails(networkType: NetworkType.LTE);
      unwrapped.setSite(site);
      unwrapped.eirp = 1000.0;
      unwrapped.azimuth = 350;

      final wrapped = new DeviceDetails(networkType: NetworkType.LTE);
      wrapped.setSite(site);
      wrapped.eirp = 1000.0;
      wrapped.azimuth = 0;

      expect(unwrapped.getPowerAtBearing(10), closeTo(34.160613380367, 1e-9));
      expect(wrapped.getPowerAtBearing(20), closeTo(34.160613380367, 1e-9));
    });

    test('getPowerAtBearing_patternLossPin_customAntenna', () {
      final device = new DeviceDetails(networkType: NetworkType.LTE);
      device.setSite(site);
      device.eirp = 1000.0;
      device.azimuth = 0;
      device.antenna = new Antenna()
        ..gain = 10.0
        ..frontToBack = 18.0
        ..horizontalBeamwidth = 65.0;
      expect(device.getPowerAtBearing(60), closeTo(21.038745836503, 1e-9));
    });
  });
}
