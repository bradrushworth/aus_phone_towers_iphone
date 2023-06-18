import 'dart:math' as math;

import 'package:logger/logger.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';
import 'package:phonetowers/helpers/let_type_helper.dart';
import 'package:phonetowers/helpers/network_type_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/helpers/translate_frequencies.dart';
import 'package:phonetowers/model/antenna.dart';
import 'package:phonetowers/model/license.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/utils/app_constants.dart';

import 'client.dart';

class DeviceDetails {
  // Details from the database

  String? sddId,
      deviceRegistrationIdentifier,
      siteId,
      emission,
      licenceCategoryName,
      polarisation,
      callSign,
      active = '';
  int? frequency, bandwidth;
  NetworkType networkType;
  int? height, azimuth, antennaId;
  double? eirp;
  late Licence licence;
  late Client client;

//  Licence licence;
//  Client client;

  // Details from the phone
  int? psc;

  // Details from the cell mapping
  double? score;

  //TreeMap<Double, Double> bearingToPowerMap;
  Site? site;
  late Logger logger;
  late Map<double, double> bearingToPowerMap;
  Antenna? antenna;

  DeviceDetails(
      {this.sddId,
      this.deviceRegistrationIdentifier,
      this.siteId,
      this.emission,
      this.licenceCategoryName = '',
      this.polarisation,
      this.callSign,
      this.active,
      this.frequency,
      this.bandwidth,
      required this.networkType,
      this.height,
      this.azimuth,
      this.eirp,
      this.site,
      this.psc,
      this.score,
      this.antennaId}) {
    this.logger = new Logger();
  }

  void setSite(Site site) {
    this.site = site;
  }

  bool isActive() {
    // The device is active if licence_hrp entries exist or if it isn't a telco we don't know
    return this.active!.isNotEmpty || !TelcoHelper.isTelecommunications(site!.telco);
  }

  Licence getLicence() {
    return licence;
  }

  Client getClient() {
    return client;
  }

  bool isMultiConditionCode() {
    if (emission == null || emission!.length <= 7) return false;
    String type = emission![7];
    switch (type) {
      case 'E':
        // Multi-condition code (more than four) in which each condition represents a signal element (of one or more bits)
        return true;
      default:
        return false;
    }
  }

  bool isMIMO() {
    bool mimo = polarisation!.startsWith("S");
    return mimo;
  }

  int getAntennaCapacity() {
    double speed = 0;
    if (networkType == NetworkType.NR) {
      // http://www.techplayon.com/spectral-efficiency-5g-nr-and-4g-lte/
      // http://www.techplayon.com/5g-nr-new-radio-throughput-capabilities/
      speed = ((2337 * 1024 * 1024) * (1.0 * bandwidth! / 100000000));
    } else if (networkType == NetworkType.LTE || networkType == NetworkType.NB_IOT) {
      LteType lteType = getLteType();

      // https://en.wikipedia.org/wiki/List_of_LTE_networks#Oceania
      // Cat.15, 4x4 MIMO, 256 QAM, 64 QAM 2CA UL

      // http://www.telecomsource.net/showthread.php?5869-How%20to%20calculate%20Peak%20Data%20Rate%20in%20LTE
      // http://www.telecomsource.net/showthread.php?3155-LTE-UL-and-DL-peak-data-rate-with-different-bandwidth-and-techniques
      // 8 bps/Hz are transferred in 256 QAM modulation
      // Pilot overhead (4 Tx antennas) = 14.29%
      // Common channel overhead (adequate to serve 1 UE/subframe) = 10%
      // CP overhead = 6.66%
      // Guard band overhead = 10%
      speed = (8 * bandwidth! * (1 - 0.1429) * (1 - 0.10) * (1 - 0.0666) * (1 - 0.10));

      // Alternatively, Downlink: 30bps/Hz (128QAM, 8x8 MIMO).
      // http://www.unwiredinsight.com/2013/evolved-hspa-lte-advanced-overview

      if (lteType == LteType.TD_LTE) {
        // http://www.slideshare.net/veermalik121/throughput-calculation-for-lte-tdd-and-fdd-system
        speed = (speed * (0.6 + 0.2 * (10.0 / 14)));
      }
    } else if (networkType == NetworkType.UMTS) {
      // 42.2Mbps per 5MHz channel MIMO and dual channel
      speed = ((1.0 * 42.2 / 2 * 1024 * 1024) * (bandwidth! / 5000000.0));

      // Alternatively, Downlink: 16.8bps/Hz (64QAM, 4x4 MIMO).
      // http://www.unwiredinsight.com/2013/evolved-hspa-lte-advanced-overview
    } else if (networkType == NetworkType.GSM) {
      // GSM bitrate of 1.3545 bit/s per Hz.
      // http://www.telecomsource.net/showthread.php?475-How%20Gross%20Trasmission%20Rate%20of%20270Kbps%20calculate%20in%20GSM?
      // Each 8 users gets 200 kHz channel = 270.9Kbps per user
      // http://www.wirelesscommunication.nl/reference/chaptr01/telephon/gsm/gsm.htm
      speed = (1.3545 * bandwidth!);
    }
    return speed.toInt();
  }

  NetworkType getNetworkType() {
    return networkType;
  }

  static Set<int> antennas3G4G = Set.of([
    84074, 81303, 92389 // Optus
  ]);
  static Set<int> antennas3G4G5G = Set.of([
    80562, // Telstra
    92391, 93659, 93661, 90023, 90025 // Optus
  ]);
  static Set<int> antennas3G5G = Set.of([
    81170 // Telstra
  ]);
  static Set<int> antennas4G = Set.of([
    80854, // Telstra
    90025, // Optus
    13198 // Vodafone
  ]);
  static Set<int> antennas4G5G = Set.of([
    // Telstra. Not: 81204
    93658, 93789, 90022, 93664, 92388, // Optus
    93907, 93908, 93910, 93911, 93364, 93365, 93366, 93368, 93369, 92174 // Vodafone
  ]);

  static List<NetworkType> getNetworkTypeStatic(
      String? emission, int frequency, int bandwidth, Telco telco, int antennaId) {
    if (antennas3G4G.contains(antennaId)) {
      return [NetworkType.UMTS, NetworkType.LTE];
    }
    if (antennas3G4G5G.contains(antennaId)) {
      return [NetworkType.UMTS, NetworkType.LTE, NetworkType.NR];
    }
    if (antennas3G5G.contains(antennaId)) {
      return [NetworkType.UMTS, NetworkType.NR];
    }
    if (antennas4G.contains(antennaId)) {
      return [NetworkType.LTE];
    }
    if (antennas4G5G.contains(antennaId)) {
      return [NetworkType.LTE, NetworkType.NR];
    }
    if (emission == null || emission.length <= 6) return [NetworkType.UNKNOWN];

    String type = emission[6];
    switch (type) {
      case 'D': // Data, telemetry, telecommand
        // If emission doesn't explicitly specify LTE type
        if (emission.length <= 8) {
          // If it a 5G frequency
          // https://www.spectrummonitoring.com/frequencies.php/frequencies.php?market=AUS
          // https://whirlpool.net.au/wiki/mobile_phone_frequencies
          // https://en.wikipedia.org/wiki/List_of_5G_NR_networks
          // https://en.wikipedia.org/wiki/5G_NR_frequency_bands
          // https://halberdbastion.com/intelligence/mobile-networks/optus
          if (telco != Telco.NBN && frequency >= 3300000000 && frequency < 3800000000) {
            // n78 (3500 MHz), <= 100 MHz BW, TDD
            return [NetworkType.NR];
          } else if (frequency >= 24250000000 && frequency < 29500000000) {
            // n257, n258 (covering 24.25 to 29.5 GHz), <=1000 MHz BW, TDD, LMDS
            return [NetworkType.NR];
          }
        }
        return [NetworkType.LTE];
      case 'W': // Combination
        if (emission.startsWith("8M20W7W") && telco == Telco.Vodafone) {
          // This is just a guess
          return [NetworkType.NB_IOT, NetworkType.UMTS];
        }
        return [NetworkType.UMTS];
      case 'E': // Telephony, voice, sound broadcasting
        if (telco == Telco.Vodafone && frequency >= 900000000 && frequency < 999000000) {
          // Vodafone
          return [NetworkType.UMTS];
        }
        return [NetworkType.GSM];
      default:
        return [NetworkType.UNKNOWN];
    }
  }

  LteType getLteType() {
    if (networkType != NetworkType.LTE) return LteType.NOT_LTE;

    // If emission doesn't explicitly specify LTE type
    if (emission!.length <= 8) {
      if (frequency! >= 2300000000 && frequency! < 2400000000) {
        // NBN
        return LteType.TD_LTE;
      }
      if (frequency! >= 3400000000 && frequency! < 3600000000) {
        // NBN
        return LteType.TD_LTE;
      }
      if (frequency! >= 24250000000 && frequency! < 29500000000) {
        // n257, n258
        return LteType.TD_LTE;
      }
      return LteType.FD_LTE;
    }

    // Decide emission for LTE type
    String type = emission![8];
    switch (type) {
      case 'C': // Code division
        return LteType.NOT_LTE;
      case 'F': // Frequency division
        return LteType.FD_LTE;
      case 'T': // Time division
        return LteType.TD_LTE;
      case 'W': // Combination of above
        return LteType.TD_LTE;
      default: // All other types
        return LteType.NOT_LTE;
    }
  }

  int getTowerHeight() {
    int towerHeight = 0;
    towerHeight = this.height!;
    if (towerHeight < 10) {
      // Sensible default value
      towerHeight = 10;
    }
    return towerHeight;
  }

  void setBearingToPowerMap(Map<double, double> bearingToPowerMap) {
    this.bearingToPowerMap = bearingToPowerMap;
  }

  double getPowerAtBearing(double bearing) {
    double gainDBi = 16.0;
    double frontToBackRatio = 25;
    double beamwidth = 60;
    if (antenna != null) {
      gainDBi = antenna!.gain;
      frontToBackRatio = antenna!.frontToBack;
      beamwidth = antenna!.horizontalBeamwidth;
    }

    if (AppConstants.isDebug)
      logger.d(
          'from get power bearing gainDBi=$gainDBi frontToBackRatio=$frontToBackRatio beamwidth=$beamwidth');

    double power_dBm = 10 * log10(eirp!) + 30; // Convert Watts to dBm
    power_dBm += 3; // Seems to give closer answers to LicenceHRP

    if (NetworkTypeHelper.isRsrp(networkType)) {
      //power_dBm += TranslateFrequencies.convertLteRsrpToRssi(bandwidth); // Convert RSRP to RSSI
    }

    //power_dBm += 30; // Extra FM radio sensitivity (over mobiles)
    //if (getNetworkType() == NetworkType.LTE) power_dBm += 20; // Convert RSRP to RSSI by adding 20 dBm
    if (azimuth != null && (beamwidth > 0 && beamwidth < 360)) {
      // Only add directional gain if we know where the gain is pointing
      power_dBm += gainDBi - 2.15; // -2.15 converts from dBi to dBd
    }
    power_dBm -=
        41.7; // https://www.phys.hawaii.edu/~anita/new/papers/militaryHandbook/antennas.pdf

    if (azimuth == null) {
      // This is an omnidirectional antenna
      logger.d(
          'DeviceDetails - getPowerAtBearing(): bearing=$bearing antennaId=$antennaId gainDBi=$gainDBi frontToBackRatio=$frontToBackRatio beamwidth=$beamwidth azimuth=$azimuth');
      return power_dBm;
    }

    double referenceAngle = (bearing - azimuth!).abs();
    // Gives approximately a 60-70 degree beamwidth... i.e. off 32 deg boresight is -3dB
    double radiationPatternLoss =
        (math.pow(1 - math.cos(GetLicenceHRP.toRadians(referenceAngle)), 1.15)).abs() *
            frontToBackRatio;
    if (double.nan == (radiationPatternLoss)) {
      radiationPatternLoss = frontToBackRatio;
    }

    if (AppConstants.isDebug)
      logger.d(
          'DeviceDetails = getPowerAtBearing(): bearing=$bearing antennaId=$antennaId gainDBi=$gainDBi frontToBackRatio=$frontToBackRatio beamwidth=$beamwidth radiationPatternLoss=$radiationPatternLoss');

    power_dBm -= radiationPatternLoss;
    //Log.d("DeviceDetails", "eirp="+eirp+" power_dBm="+power_dBm);
    return power_dBm;
  }

  Site getSite() {
    return this.site!;
  }

//  Position getPosition() {
//    return new Position(site.getLatLng().latitude, site.getLatLng().doubleitude);
//  }

  static String formatNetworkSpeed(int speed) {
    if (speed >= 1 * 1024 * 1024 * 1024) {
      return '${(1.0 * speed / 1024 / 1024 / 1024).toStringAsFixed(1)} Gbps';
    }
    if (speed >= 1024 * 1024) {
      return '${(1.0 * speed / 1024 / 1024).toStringAsFixed(0)} Mbps';
    }
    if (speed >= 1024) {
      return '${(1.0 * speed / 1024).toStringAsFixed(0)} kbps';
    }
    return '${speed.toStringAsFixed(0)}  bps';
  }

  @override
  bool operator ==(o) => o is DeviceDetails && toString() == o.toString();

  @override
  int get hashCode => toString().hashCode;

  @override
  String toString() {
    return deviceRegistrationIdentifier!;
  }

  @override
  int compareTo(DeviceDetails other) {
    return deviceRegistrationIdentifier!.compareTo(other.deviceRegistrationIdentifier!);
  }
}
