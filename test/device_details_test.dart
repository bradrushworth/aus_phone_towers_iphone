import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/get_licenceHRP.dart';
import 'package:phonetowers/helpers/let_type_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/site.dart';

void main() {
  group('DeviceDetailsTest', () {
    late Site site;
    late DeviceDetails deviceDetails;

    setUp(() {
      site = new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN);

      deviceDetails = new DeviceDetails();
      deviceDetails.setSite(site);
    });

    test('formatNetworkSpeed', () {
      expect(DeviceDetails.formatNetworkSpeed(207618048), "198 Mbps");
      expect(DeviceDetails.formatNetworkSpeed(33554432), "32 Mbps");
      expect(DeviceDetails.formatNetworkSpeed(1073741824), "1024 Mbps");
      expect(DeviceDetails.formatNetworkSpeed(923795456), "881 Mbps");
      expect(DeviceDetails.formatNetworkSpeed(2362232012), "2253 Mbps");
      expect(DeviceDetails.formatNetworkSpeed(57344), "56 kbps");
      expect(DeviceDetails.formatNetworkSpeed(128), "128  bps");
    });

    test('isActiveTrueNotTelecoms', () {
      deviceDetails.active = "";
      deviceDetails.setSite(
          new Site(telco: Telco.Aviation, cityDensity: CityDensity.OPEN));
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

    test('getAntennaCapacityGSM', () { // Still at Christmas Island
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "8M40G7E";
      deviceDetails.frequency = 1840000000;
      expect(deviceDetails.getAntennaCapacity(), 13545000);
    });

    test('getAntennaCapacityUMTS', () {
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "9M00W7WEC";
      deviceDetails.frequency = 1840000000;
      expect(deviceDetails.getAntennaCapacity(), 44249907);
    });

    test('getAntennaCapacityFD_LTE', () {
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 1840000000;
      expect(deviceDetails.getAntennaCapacity(), 51841110);
    });

    test('getAntennaCapacityTD_LTE', () {
      deviceDetails.bandwidth = 10000000;
      deviceDetails.emission = "19M9W7DEW";
      deviceDetails.frequency = 1840000000;
      expect(deviceDetails.getAntennaCapacity(), 38510539);
    });

    test('getAntennaCapacityTD_NR', () {
      deviceDetails.bandwidth = 20000000;
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 3565000000;
      expect(deviceDetails.getAntennaCapacity(), 490104422);
    });

    test('getAntennaCapacityTD_NR_mmWave', () {
      deviceDetails.bandwidth = 20000000;
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 26000000000;
      expect(deviceDetails.getAntennaCapacity(), 490104422);
    });

    test('getNetworkTypeNR', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 3565000000;
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
    });

    test('getNetworkTypeNR_mmWave', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 26000000000;
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
    });

    test('getNetworkTypeLTE', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 1840000000;
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getNetworkTypeLTE_AmbigiousWithNR', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 1840000000;
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getNetworkTypeUMTS', () {
      deviceDetails.emission = "3M84G7W--";
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getNetworkTypeUMTS1', () {
      deviceDetails.emission = "10M0W7W";
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getNetworkTypeUMTS2', () {
      deviceDetails.emission = "9M00W7WEC";
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getNetworkTypeGSM', () {
      deviceDetails.emission = "8M40G7E";
      expect(deviceDetails.getNetworkType(), NetworkType.GSM);
    });

    test('getLteType_FD_LTE', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 1840000000;
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getLteType_FD_LTE_Optus', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 763000000;
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
    });

    test('getLteType_TD_LTE_Optus', () {
      deviceDetails.emission = "80M0W7D";
      deviceDetails.frequency = 2342000000;
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
    });

    test('getLteType_TD_LTE_NBN', () {
      deviceDetails.emission = "19M9W7DEW";
      deviceDetails.frequency = 3507000000;
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_5G_NR', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 3565000000;
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_UMTS', () {
      deviceDetails.emission = "3M84G7W--";
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_UMTS2', () {
      deviceDetails.emission = "9M00W7WEC";
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_UMTS3', () {
      deviceDetails.emission = "9M90G7WEC";
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_GSM', () {
      deviceDetails.emission = "8M40G7E";
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.GSM);
    });

    test('getLteType_Vodafone_4G_735', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 735500000;
      deviceDetails.bandwidth = 5000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_4G_790', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 790500000;
      deviceDetails.bandwidth = 5000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_TPG_4G_798', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 798000000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_5G_795', () {
      deviceDetails.emission = "15M0W7D";
      deviceDetails.frequency = 795650000;
      deviceDetails.bandwidth = 15000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Vodafone_LP_955', () {
      // Either this one or the test below is NB-IoT
      deviceDetails.emission = "8M20W7W";
      deviceDetails.frequency = 955900000;
      deviceDetails.bandwidth = 8200000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NB_IOT);
    });

    test('getLteType_Vodafone_UMTS_956', () {
      deviceDetails.emission = "4M20G7W";
      deviceDetails.frequency = 956200000;
      deviceDetails.bandwidth = 5000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_TPG_2625', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 2625000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_3G', () {
      deviceDetails.emission = "14M0W7WEC";
      deviceDetails.frequency = 2117600000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.NOT_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.UMTS);
    });

    test('getLteType_Telstra_4G_2100', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 2162400000;
      deviceDetails.setSite(
          new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Optus_4G_2100', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 2162400000;
      deviceDetails.setSite(
          new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_4G_2100', () {
      deviceDetails.emission = "5M00W7D";
      deviceDetails.frequency = 2162400000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Vodafone_5G_25300', () {
      deviceDetails.emission = "400MW7D";
      deviceDetails.frequency = 25300000000;
      deviceDetails.bandwidth = 400000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Vodafone, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_5G_850', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 882500000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails.setSite(
          new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Optus_4G_2365', () {
      deviceDetails.emission = "70M0W7D";
      deviceDetails.frequency = 2365000000;
      deviceDetails.bandwidth = 70000000;
      deviceDetails
          .setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.LTE);
    });

    test('getLteType_Optus_5G_2351', () {
      deviceDetails.emission = "98M0W7D";
      deviceDetails.frequency = 2349750000;
      deviceDetails.bandwidth = 98000000;
      deviceDetails
          .setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Optus_5G_26200', () {
      deviceDetails.emission = "1G00W7D";
      deviceDetails.frequency = 26200000000;
      deviceDetails.bandwidth = 1000000000;
      deviceDetails
          .setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Optus_5G_28000', () {
      deviceDetails.emission = "800MW7D";
      deviceDetails.frequency = 28500000000;
      deviceDetails.bandwidth = 800000000;
      deviceDetails
          .setSite(new Site(telco: Telco.Optus, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.TD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_5G_877', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 877250000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails
          .setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_5G_2662', () {
      deviceDetails.emission = "10M0W7D";
      deviceDetails.frequency = 2662950000;
      deviceDetails.bandwidth = 10000000;
      deviceDetails
          .setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
      expect(deviceDetails.getLteType(), LteType.FD_LTE);
      expect(deviceDetails.getNetworkType(), NetworkType.NR);
    });

    test('getLteType_Telstra_4G_Christmas_Island', () {
      deviceDetails.emission = "20M0W7D";
      deviceDetails.frequency = 778000000;
      deviceDetails.bandwidth = 20000000;
      deviceDetails
          .setSite(new Site(telco: Telco.Telstra, cityDensity: CityDensity.OPEN));
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
      // Using null value of bearingToPowerMap variable
      expect(deviceDetails.getPowerAtBearing(0), closeTo(22.979, 0.001));
    });

    test('getPowerAtBearing2', () {
      deviceDetails.eirp = 6760.0;
      // Using null value of bearingToPowerMap variable
      expect(deviceDetails.getPowerAtBearing(0), closeTo(29.599, 0.001));
    });

    test('getSite', () {
      expect(deviceDetails.getSite(), site);
    });

    test('testHashCode', () {
      deviceDetails.sddId = "10240601";
      expect(deviceDetails.hashCode, "10240601".hashCode);
    });

    test('testToString', () {
      deviceDetails.sddId = "10240601";
      expect(deviceDetails.toString(), "10240601");
    });
  });
}
