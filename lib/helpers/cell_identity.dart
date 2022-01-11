//import 'package:flt_telephony_info/flt_telephony_info.dart';
import 'package:intl/intl.dart';
import 'package:phonetowers/helpers/telco_helper.dart';

class CellIdentity {
  static int CONNECTED_NETWORK_TYPE = 0;
  static int CONNECTED_ARFCN = 0;
  static int TIMING_ADVANCE;
  static DateFormat SDF = new DateFormat("yyyy-MM-dd HH:mm:ss");

  /* static {
  SDF.setTimeZone(TimeZone.getTimeZone("UTC"));
}*/

/*
  static Telco getTelcoInUse() {
    FltTelephonyInfo.info.then((infoValue) {
      String network = infoValue.networkOperator;
      if (network != null) {
        if (network == "50501" || network == "50571" || network == "50572") {
          return Telco.Telstra;
        } else if (network == "50502" || network == "50590") {
          return Telco.Optus;
        } else if (network == "50503" ||
            network == "50506" ||
            network == "50512" ||
            network == "50538") {
          return Telco.Vodafone;
        } else if (network == "50562" || network == "50568") {
          return Telco.NBN;
        }
      }
      return null;
    });
  }
*/

  /*   @SuppressLint("MissingPermission")
    static JSONArray getCellInfo(TelephonyManager tel) {
      JSONArray cellList = new JSONArray();

      // Type of phone
      int phoneTypeInt = tel.getPhoneType();
      String phoneType = null;
      phoneType =
      phoneTypeInt == TelephonyManager.PHONE_TYPE_GSM ? "GSM" : phoneType;
      phoneType =
      phoneTypeInt == TelephonyManager.PHONE_TYPE_CDMA ? "CDMA" : phoneType;

      // Type of network
      CONNECTED_NETWORK_TYPE = tel.getNetworkType();
      // Clear the CONNECTED_ARFCN before it is set again below
      CONNECTED_ARFCN = 0;
      // Clear the timing advance because it is only for LTE
      TIMING_ADVANCE = null;

      try {
        JSONObject phoneObj = new JSONObject();
        phoneObj.put("build", Build.VERSION.SDK_INT);
        phoneObj.put("device", Build.DEVICE);
        phoneObj.put("manufacturer", Build.MANUFACTURER);
        phoneObj.put("brand", Build.BRAND);
        phoneObj.put("model", Build.MODEL);
        phoneObj.put("phone_type", phoneType);
        phoneObj.put("call_state", tel.getCallState());
        phoneObj.put("cell_location", tel.getCellLocation());
        phoneObj.put("data_activity", tel.getDataActivity());
        phoneObj.put("data_state", tel.getDataState());
        //phoneObj.put("DeviceId", tel.getDeviceId());
        //phoneObj.put("DeviceSoftwareVersion", tel.getDeviceSoftwareVersion());
        //phoneObj.put("GroupIdLevel1", tel.getGroupIdLevel1());
        //phoneObj.put("Line1Number", tel.getLine1Number());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
          phoneObj.put("mms_ua_prof_url", tel.getMmsUAProfUrl());
          phoneObj.put("mms_user_agent", tel.getMmsUserAgent());
        }
        phoneObj.put("network_country_iso", tel.getNetworkCountryIso());
        phoneObj.put("network_operator", tel.getNetworkOperator());
        phoneObj.put("network_operator_name", tel.getNetworkOperatorName());
        phoneObj.put("network_type", CONNECTED_NETWORK_TYPE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          phoneObj.put("phone_count", tel.getPhoneCount());
        }
        phoneObj.put("sim_country_iso", tel.getSimCountryIso());
        phoneObj.put("sim_operator", tel.getSimOperator());
        phoneObj.put("sim_operator_name", tel.getSimOperatorName());
        //phoneObj.put("SimSerialNumber", tel.getSimSerialNumber());
        phoneObj.put("sim_state", tel.getSimState());
        //phoneObj.put("SubscriberId", tel.getSubscriberId());
        //phoneObj.put("VoiceMailAlphaTag", tel.getVoiceMailAlphaTag());
        //phoneObj.put("VoiceMailNumber", tel.getVoiceMailNumber());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
          phoneObj.put("carrier_privileges", tel.hasCarrierPrivileges());
        }
        phoneObj.put("network_roaming", tel.isNetworkRoaming());
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
          phoneObj.put("sms_capable", tel.isSmsCapable());
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
          phoneObj.put("voice_capable", tel.isVoiceCapable());
        }
        //phoneObj.put("WorldPhone", tel.isWorldPhone());
        cellList.put(phoneObj);

        // From Android 18 and up, you should use getAllCellInfo()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.JELLY_BEAN_MR2) {
          List<NeighboringCellInfo> neighCells = tel.getNeighboringCellInfo();
          for (int i = 0; i < neighCells.size(); i++) {
            JSONObject cellObj = new JSONObject();
            NeighboringCellInfo thisCell = neighCells.get(i);
            //if (thisCell.getCid() == NeighboringCellInfo.UNKNOWN_CID) continue;
            cellObj.put(
                "measured_at",
                SDF.format(new Date(System.currentTimeMillis())));
            cellObj.put(
                "type", getNetworkGeneration(thisCell.getNetworkType()));
            cellObj.put("act", getNetworkTypeName(thisCell.getNetworkType()));
            cellObj.put("psc", thisCell.getPsc());
            cellObj.put("cellid", thisCell.getCid());
            cellObj.put("lac", thisCell.getLac());
            Integer dBm = thisCell.getRssi();
            if (dBm == NeighboringCellInfo.UNKNOWN_RSSI) {
              dBm = null;
            }
            cellObj.put("signal", dBm);
            cellList.put(cellObj);
            Log.d("CellIdentity", "NeighboringCellInfo: " + cellObj.toString());
          }
        } else {
          List<CellInfo> infos = tel.getAllCellInfo();
          //Log.d("CellIdentity", "getCellInfo: size="+infos.size()+" infos="+infos);
          for (int i = 0; i < infos.size(); ++i) {
            JSONObject cellObj = new JSONObject();
            CellInfo info = infos.get(i);
            cellObj.put(
                "measured_at",
                SDF.format(new Date(System.currentTimeMillis())));
            cellObj.put("registered", info.isRegistered());
            if (info instanceof CellInfoGsm) {
              CellSignalStrengthGsm gsm = ((CellInfoGsm) info)
                  .getCellSignalStrength();
              CellIdentityGsm identityGsm = ((CellInfoGsm) info)
                  .getCellIdentity();
              //if (identityGsm.getLac() == 0) continue;
              //if (identityGsm.getCid() == Integer.MAX_VALUE) continue;
              cellObj.put("type", NetworkType.GSM.getValue());
              cellObj.put("act", getNetworkTypeName(tel.getNetworkType()));
              cellObj.put("rnc", identityGsm.getCid() / 65536);
              cellObj.put("short_cellid", identityGsm.getCid() % 65536);
              cellObj.put("cellid", identityGsm.getCid());
              cellObj.put("lac", identityGsm.getLac());
              cellObj.put("mnc", identityGsm.getMnc() < Integer.MAX_VALUE
                  ? identityGsm.getMnc()
                  : Integer.parseInt(tel.getNetworkOperator().substring(3)));
              cellObj.put("mcc", identityGsm.getMcc() < Integer.MAX_VALUE
                  ? identityGsm.getMcc()
                  : Integer.parseInt(tel.getNetworkOperator().substring(0, 3)));
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                int ta = gsm.getTimingAdvance();
                if (ta >= 0 && ta < Integer.MAX_VALUE) {
                  cellObj.put("ta", ta);
                  TIMING_ADVANCE = ta;
                }
              }
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                int arfcn = identityGsm.getArfcn();
                cellObj.put("arfcn", arfcn);
                if (arfcn > 0) {
                  CONNECTED_ARFCN = arfcn;
                  cellObj.put("frequency", calculateGsmFrequency(arfcn));
                  cellObj.put("band", calculateGsmBand(arfcn));
                  cellObj.put("band_name", calculateGsmBandName(arfcn));
                } else {
                  cellObj.put("frequency", "0");
                  cellObj.put("band", "0");
                  cellObj.put("band_name", "Unsupported");
                }
              }

              Integer dBm = gsm.getDbm();
              Integer asu = gsm.getAsuLevel();
              // http://wiki.opencellid.org/wiki/FAQ#Signal_strength_details
              if (dBm < 113 && dBm > 51) {
                // My Samsung S6 seems to have the correct signal, but without being negative
                dBm = -dBm;
                asu = (dBm + 113) / 2;
              } else if (dBm <= -113 || dBm >= -51) {
                dBm = null;
              }
              if (asu <= 0 || asu >= 31) {
                asu = null;
              }
              cellObj.put("signal", dBm);
              cellObj.put("level", gsm.getLevel());
              cellObj.put("asu", asu);
              cellList.put(cellObj);
            } else if (info instanceof CellInfoLte) {
              CellSignalStrengthLte lte = ((CellInfoLte) info)
                  .getCellSignalStrength();
              CellIdentityLte identityLte = ((CellInfoLte) info)
                  .getCellIdentity();
              //if (identityLte.getTac() == 0) continue;
              //if (identityLte.getCi() == Integer.MAX_VALUE) continue;
              cellObj.put("type", NetworkType.NETWORK_TYPE_LTE.getValue());
              cellObj.put("act", getNetworkTypeName(tel.getNetworkType()));
              cellObj.put("rnc", identityLte.getCi() / 65536);
              cellObj.put("short_cellid", identityLte.getCi() % 65536);
              cellObj.put("cellid", identityLte.getCi());
              cellObj.put("lac", identityLte.getTac());
              cellObj.put("mnc", identityLte.getMnc() < Integer.MAX_VALUE
                  ? identityLte.getMnc()
                  : Integer.parseInt(tel.getNetworkOperator().substring(3)));
              cellObj.put("mcc", identityLte.getMcc() < Integer.MAX_VALUE
                  ? identityLte.getMcc()
                  : Integer.parseInt(tel.getNetworkOperator().substring(0, 3)));
              cellObj.put("pci", identityLte.getPci());
              int ta = lte.getTimingAdvance();
              if (ta >= 0 && ta < Integer.MAX_VALUE) {
                cellObj.put("ta", ta);
                TIMING_ADVANCE = ta;
              }
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                int arfcn = identityLte.getEarfcn();
                cellObj.put("arfcn", arfcn);
                if (arfcn > 0) {
                  CONNECTED_ARFCN = arfcn;
                  cellObj.put("frequency", calculateLteFrequency(arfcn));
                  cellObj.put("band", calculateLteBand(arfcn));
                  cellObj.put("band_name", calculateLteBandName(arfcn));
                } else {
                  cellObj.put("frequency", "0");
                  cellObj.put("band", "0");
                  cellObj.put("band_name", "Unsupported");
                }
              }
              Integer dBm = lte.getDbm();
              Integer asu = lte.getAsuLevel();
              // http://wiki.opencellid.org/wiki/FAQ#Signal_strength_details
              if (dBm < 137 && dBm > 45) {
                // My Samsung S6 seems to have the correct signal, but without being negative
                dBm = -dBm;
                asu = dBm + 140;
              } else if (dBm <= -137 || dBm >= -45) {
                dBm = null;
              }
              if (dBm != null) {
                dBm += 20; // Convert RSRP to RSSI by adding 20 dBm
              }
              if (asu <= 0 || asu >= 95) {
                asu = null;
              }
              cellObj.put("signal", dBm);
              cellObj.put("level", lte.getLevel());
              cellObj.put("asu", asu);
              cellList.put(cellObj);
            } else if (info instanceof CellInfoWcdma) {
              CellSignalStrengthWcdma wcdma = ((CellInfoWcdma) info)
                  .getCellSignalStrength();
              CellIdentityWcdma identityWcdma = ((CellInfoWcdma) info)
                  .getCellIdentity();
              //if (identityWcdma.getLac() == 0) continue;
              //if (identityWcdma.getCid() == Integer.MAX_VALUE) continue;
              cellObj.put("type", NetworkType.NETWORK_TYPE_UMTS.getValue());
              cellObj.put("act", getNetworkTypeName(tel.getNetworkType()));
              cellObj.put("rnc", identityWcdma.getCid() / 65536);
              cellObj.put("short_cellid", identityWcdma.getCid() % 65536);
              cellObj.put("cellid", identityWcdma.getCid());
              cellObj.put("lac", identityWcdma.getLac());
              cellObj.put("mnc",
                  identityWcdma.getMnc() < Integer.MAX_VALUE ? identityWcdma
                      .getMnc() : Integer.parseInt(
                      tel.getNetworkOperator().substring(3)));
              cellObj.put("mcc",
                  identityWcdma.getMcc() < Integer.MAX_VALUE ? identityWcdma
                      .getMcc() : Integer.parseInt(
                      tel.getNetworkOperator().substring(0, 3)));
              cellObj.put("psc", identityWcdma.getPsc());
              if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                int arfcn = identityWcdma.getUarfcn();
                cellObj.put("arfcn", arfcn);
                if (arfcn > 0) {
                  CONNECTED_ARFCN = arfcn;
                  cellObj.put("frequency", calculateUmtsFrequency(arfcn));
                  cellObj.put("band", calculateUmtsBand(arfcn));
                  cellObj.put("band_name", calculateUmtsBandName(arfcn));
                } else {
                  cellObj.put("frequency", "0");
                  cellObj.put("band", "0");
                  cellObj.put("band_name", "Unsupported");
                }
              }
              Integer dBm = wcdma.getDbm();
              Integer asu = wcdma.getAsuLevel();
              // http://wiki.opencellid.org/wiki/FAQ#Signal_strength_details
              if (dBm < 121 && dBm > 25) {
                // My Samsung S6 seems to have the correct signal, but without being negative
                dBm = -dBm;
                asu = (dBm + 113) / 2;
              } else if (dBm <= -121 || dBm >= -25 ||
                  dBm ==
                      -51) { // -51 dBm seems to be an error code on Samsung S6
                dBm = null;
              }
              if (asu <= -5 || asu >= 91 ||
                  asu == 31) { // 31 ASU seems to be an error code on Samsung S6
                asu = null;
              }
              cellObj.put("signal", dBm);
              cellObj.put("level", wcdma.getLevel());
              cellObj.put("asu", asu);
              cellList.put(cellObj);
            } else if (info instanceof CellInfoCdma) {
              // No CDMA in Australia any more
              CellSignalStrengthCdma cdma = ((CellInfoCdma) info)
                  .getCellSignalStrength();
              CellIdentityCdma identityCdma = ((CellInfoCdma) info)
                  .getCellIdentity();
              //if (identityCdma.getNetworkId() == 0) continue;
              //if (identityCdma.getSystemId() == Integer.MAX_VALUE) continue;
              cellObj.put("type", NetworkType.CDMA.getValue());
              cellObj.put("act", getNetworkTypeName(tel.getNetworkType()));
              cellObj.put("bid", identityCdma.getBasestationId());
              cellObj.put("lat", identityCdma.getLatitude());
              cellObj.put("lon", identityCdma.getLongitude());
              cellObj.put("nid", identityCdma.getNetworkId());
              cellObj.put("sid", identityCdma.getSystemId());
              cellObj.put("signal", cdma.getDbm());
              cellObj.put("level", cdma.getLevel());
              cellObj.put("asu", cdma.getAsuLevel());
              cellObj.put("cdma_dbm", cdma.getCdmaDbm());
              cellObj.put("cdma_ecio", cdma.getCdmaEcio());
              cellObj.put("cdma_level", cdma.getCdmaLevel());
              cellObj.put("evdo_dbm", cdma.getEvdoDbm());
              cellObj.put("evdo_ecio", cdma.getEvdoEcio());
              cellObj.put("evdo_level", cdma.getEvdoLevel());
              cellObj.put("evdo_snr", cdma.getEvdoSnr());
              cellList.put(cellObj);
            }
            Log.d("CellIdentity", "CellInfo[" + i + "]: " + cellObj.toString());
          }
        }
      }
      catch
      (
      Exception ex) {
      Log.e("MapsActivity", "getCellInfo(): Caught exception", ex);
      ex.printStackTrace();
      FirebaseCrash.report(ex);
      }
      return
      cellList;
    }
*/

/*  static int getNetworkGeneration(int type) {
    switch (type) {
      case NetworkType.NETWORK_TYPE_GPRS:
      case NetworkType.NETWORK_TYPE_EDGE:
      case NetworkType.NETWORK_TYPE_GSM:
        return NetworkType.NETWORK_TYPE_GSM;
      case NetworkType.NETWORK_TYPE_UMTS:
      case NetworkType.NETWORK_TYPE_HSDPA:
      case NetworkType.NETWORK_TYPE_HSUPA:
      case NetworkType.NETWORK_TYPE_HSPA:
      case NetworkType.NETWORK_TYPE_EHRPD:
      case NetworkType.NETWORK_TYPE_HSPAP:
      case NetworkType.NETWORK_TYPE_TD_SCDMA:
        return NetworkType.NETWORK_TYPE_UMTS;
      case NetworkType.NETWORK_TYPE_LTE:
      case 19: // NETWORK_TYPE_LTE_CA
        return NetworkType.NETWORK_TYPE_LTE;
      case NetworkType.NETWORK_TYPE_CDMA:
      case NetworkType.NETWORK_TYPE_EVDO_0:
      case NetworkType.NETWORK_TYPE_EVDO_A:
      case NetworkType.NETWORK_TYPE_EVDO_B:
      case NetworkType.NETWORK_TYPE_1xRTT:
        return NetworkType.NETWORK_TYPE_CDMA;
      case NetworkType.NETWORK_TYPE_IDEN:
      case NetworkType.NETWORK_TYPE_IWLAN:
      default:
        return NetworkType.NETWORK_TYPE_UNKNOWN;
    }
  }*/

//  Network access type; currently supported:
// 1xRTT, CDMA, eHRPD, IS95A, IS95B, EVDO_0, EVDO_A, EVDO_B, UMTS, HSPA+, HSDPA, HSUPA, HSPA, LTE, EDGE, GPRS, GSM
/*  static String getNetworkTypeName(int type) {
    switch (type) {
      case NetworkType.NETWORK_TYPE_GPRS:
        return "GPRS";
      case NetworkType.NETWORK_TYPE_EDGE:
        return "EDGE";
      case NetworkType.NETWORK_TYPE_UMTS:
        return "UMTS";
      case NetworkType.NETWORK_TYPE_HSDPA:
        return "HSDPA";
      case NetworkType.NETWORK_TYPE_HSUPA:
        return "HSUPA";
      case NetworkType.NETWORK_TYPE_HSPA:
        return "HSPA";
      case NetworkType.NETWORK_TYPE_CDMA:
        return "CDMA";
      case NetworkType.NETWORK_TYPE_EVDO_0:
        return "EVDO_0";
      case NetworkType.NETWORK_TYPE_EVDO_A:
        return "EVDO_A";
      case NetworkType.NETWORK_TYPE_EVDO_B:
        return "EVDO_B";
      case NetworkType.NETWORK_TYPE_1xRTT:
        return "1xRTT";
      case NetworkType.NETWORK_TYPE_LTE:
        return "LTE";
      case NetworkType.NETWORK_TYPE_EHRPD:
        return "eHRPD";
      case NetworkType.NETWORK_TYPE_IDEN:
        return "iDEN";
      case NetworkType.NETWORK_TYPE_HSPAP:
        return "HSPA+";
      case 16:
        return "GSM";
      default:
        return "";
    }
  }*/

  static double calculateGsmFrequency(int N) {
    double c1 = 0;
    double c2 = 0;
    if (N >= 259 && N <= 293) {
      c1 = 450.6 + 0.2 * (N - 259);
      c2 = c1 + 10;
    } else if (N >= 306 && N <= 340) {
      c1 = 479 + 0.2 * (N - 306);
      c2 = c1 + 10;
    } else if (N >= 438 && N <= 511) {
      c1 = 747.2 + 0.2 * (N - 438);
      c2 = c1 + 30;
    } else if (N >= 128 && N <= 251) {
      c1 = 824.2 + 0.2 * (N - 128);
      c2 = c1 + 45;
    } else if (N >= 1 && N <= 124) {
      c1 = 890 + 0.2 * N;
      c2 = c1 + 45;
    } else if (N >= 975 && N <= 1023) {
      c1 = 890 + 0.2 * (N - 1024);
      c2 = c1 + 45;
    } else if (N >= 940 && N <= 974) {
      c1 = 890 + 0.2 * (N - 1024);
      c2 = c1 + 45;
    } else if (N >= 512 && N <= 810) {
      c1 = 1710.2 + 0.2 * (N - 512);
      c2 = c1 + 95;
      // Also for PCS 1900, but formula is different. Not used in Australia.
      //c3 = 1850.2 + 0.2 * (N - 512);
      //c4 = c1 + 80;
    } else if (N >= 811 && N <= 885) {
      c1 = 1710.2 + 0.2 * (N - 512);
      c2 = c1 + 95;
    }
    return (c1 * 1000 * 1000);
  }

  static int calculateGsmBand(int N) {
    if (N >= 259 && N <= 293) {
      return 450;
    } else if (N >= 306 && N <= 340) {
      return 480;
    } else if (N >= 438 && N <= 511) {
      return 750;
    } else if (N >= 128 && N <= 251) {
      return 850;
    } else if (N >= 1 && N <= 124) {
      return 900;
    } else if (N >= 975 && N <= 1023) {
      return 900;
    } else if (N >= 940 && N <= 974) {
      return 900;
    } else if (N >= 512 && N <= 810) {
      return 1800; // Also 1900 but not in Australia
    } else if (N >= 811 && N <= 885) {
      return 1800;
    }
    return null;
  }

  static String calculateGsmBandName(int N) {
    if (N >= 259 && N <= 293) {
      return "450 GSM";
    } else if (N >= 306 && N <= 340) {
      return "480 GSM";
    } else if (N >= 438 && N <= 511) {
      return "750 GSM";
    } else if (N >= 128 && N <= 251) {
      return "850 GSM";
    } else if (N >= 1 && N <= 124) {
      return "900 P-GSM";
    } else if (N >= 975 && N <= 1023) {
      return "900 E-GSM";
    } else if (N >= 940 && N <= 974) {
      return "900 GSM-R";
    } else if (N >= 512 && N <= 810) {
      return "1800 DCS"; // Also PCS 1900 but not in Australia
    } else if (N >= 811 && N <= 885) {
      return "1800 DCS";
    }
    return null;
  }

// http://analog.intgckts.com/lte-carrier-frequency-and-earfcn/
  static double calculateLteFrequency(int N) {
    double FDL_Low = 0;
    int NDL_Offset = 0;
    double FUL_Low = 0;
    int NUL_Offset = 0;
    int N1 = 0;
    int NUL = 0;
    if (N >= 0 && N <= 599) {
      FDL_Low = 2110;
      NDL_Offset = 0;
      FUL_Low = 1920;
      NUL_Offset = 18000;
      N1 = N - 0;
      NUL = 18000 + N1;
    } else if (N >= 600 && N <= 1199) {
      FDL_Low = 1930;
      NDL_Offset = 600;
      FUL_Low = 1850;
      NUL_Offset = 18600;
      N1 = N - 600;
      NUL = 18600 + N1;
    } else if (N >= 1200 && N <= 1949) {
      FDL_Low = 1805;
      NDL_Offset = 1200;
      FUL_Low = 1710;
      NUL_Offset = 19200;
      N1 = N - 1200;
      NUL = 19200 + N1;
    } else if (N >= 1950 && N <= 2399) {
      FDL_Low = 2110;
      NDL_Offset = 1950;
      FUL_Low = 1710;
      NUL_Offset = 19950;
      N1 = N - 1950;
      NUL = 19950 + N1;
    } else if (N >= 2400 && N <= 2649) {
      FDL_Low = 869;
      NDL_Offset = 2400;
      FUL_Low = 824;
      NUL_Offset = 20400;
      N1 = N - 2400;
      NUL = 20400 + N1;
    } else if (N >= 2650 && N <= 2749) {
      FDL_Low = 875;
      NDL_Offset = 2650;
      FUL_Low = 830;
      NUL_Offset = 20650;
      N1 = N - 2650;
      NUL = 20650 + N1;
    } else if (N >= 2750 && N <= 3449) {
      FDL_Low = 2620;
      NDL_Offset = 2750;
      FUL_Low = 2500;
      NUL_Offset = 20750;
      N1 = N - 2750;
      NUL = 20750 + N1;
    } else if (N >= 3450 && N <= 3799) {
      FDL_Low = 925;
      NDL_Offset = 3450;
      FUL_Low = 880;
      NUL_Offset = 21450;
      N1 = N - 3450;
      NUL = 21450 + N1;
    } else if (N >= 3800 && N <= 4149) {
      FDL_Low = 1844.9;
      NDL_Offset = 3800;
      FUL_Low = 1749.9;
      NUL_Offset = 21800;
      N1 = N - 3800;
      NUL = 21800 + N1;
    } else if (N >= 4150 && N <= 4749) {
      FDL_Low = 2110;
      NDL_Offset = 4150;
      FUL_Low = 1710;
      NUL_Offset = 22150;
      N1 = N - 4150;
      NUL = 22150 + N1;
    } else if (N >= 4750 && N <= 4999) {
      FDL_Low = 1475.9;
      NDL_Offset = 4750;
      FUL_Low = 1427.9;
      NUL_Offset = 22750;
      N1 = N - 4750;
      NUL = 22750 + N1;
    } else if (N >= 5000 && N <= 5179) {
      FDL_Low = 728;
      NDL_Offset = 5000;
      FUL_Low = 698;
      NUL_Offset = 23000;
      N1 = N - 5000;
      NUL = 23000 + N1;
    } else if (N >= 5180 && N <= 5279) {
      FDL_Low = 746;
      NDL_Offset = 5180;
      FUL_Low = 777;
      NUL_Offset = 23180;
      N1 = N - 5180;
      NUL = 23180 + N1;
    } else if (N >= 5280 && N <= 5379) {
      FDL_Low = 758;
      NDL_Offset = 5280;
      FUL_Low = 788;
      NUL_Offset = 23280;
      N1 = N - 5280;
      NUL = 23280 + N1;
    } else if (N >= 5730 && N <= 5849) {
      FDL_Low = 734;
      NDL_Offset = 5730;
    } else if (N >= 5850 && N <= 5999) {
      FDL_Low = 860;
      NDL_Offset = 5850;
    } else if (N >= 6000 && N <= 6149) {
      FDL_Low = 875;
      NDL_Offset = 6000;
    } else if (N >= 6150 && N <= 6449) {
      FDL_Low = 791;
      NDL_Offset = 6150;
    } else if (N >= 6450 && N <= 6599) {
      FDL_Low = 1495.9;
      NDL_Offset = 6450;
    } else if (N >= 6600 && N <= 7399) {
      FDL_Low = 3510;
      NDL_Offset = 6600;
    } else if (N >= 7500 && N <= 7699) {
      FDL_Low = 2180;
      NDL_Offset = 7500;
    } else if (N >= 7700 && N <= 8039) {
      FDL_Low = 1525;
      NDL_Offset = 7700;
    } else if (N >= 8040 && N <= 8689) {
      FDL_Low = 1930;
      NDL_Offset = 8040;
    } else if (N >= 8690 && N <= 9039) {
      FDL_Low = 859;
      NDL_Offset = 8690;
    } else if (N >= 9040 && N <= 9209) {
      FDL_Low = 852;
      NDL_Offset = 9040;
    } else if (N >= 9210 && N <= 9659) {
      FDL_Low = 758;
      NDL_Offset = 9210;
    } else if (N >= 9660 && N <= 9769) {
      FDL_Low = 717;
      NDL_Offset = 9660;
    } else if (N >= 9870 && N <= 9919) {
      FDL_Low = 462.5;
      NDL_Offset = 9870;
    } else if (N >= 36000 && N <= 36199) {
      FDL_Low = 1900;
      NDL_Offset = 36000;
    } else if (N >= 36200 && N <= 36349) {
      FDL_Low = 2010;
      NDL_Offset = 36200;
    } else if (N >= 36350 && N <= 36949) {
      FDL_Low = 1850;
      NDL_Offset = 36350;
    } else if (N >= 36950 && N <= 37549) {
      FDL_Low = 1930;
      NDL_Offset = 36950;
    } else if (N >= 37550 && N <= 37749) {
      FDL_Low = 1910;
      NDL_Offset = 37550;
    } else if (N >= 37750 && N <= 38249) {
      FDL_Low = 2570;
      NDL_Offset = 37750;
    } else if (N >= 38250 && N <= 38649) {
      FDL_Low = 1880;
      NDL_Offset = 38250;
    } else if (N >= 38650 && N <= 39649) {
      FDL_Low = 2300;
      NDL_Offset = 38650;
    } else if (N >= 39650 && N <= 41589) {
      FDL_Low = 2496;
      NDL_Offset = 39650;
    } else if (N >= 41590 && N <= 43589) {
      FDL_Low = 3400;
      NDL_Offset = 41590;
    } else if (N >= 43590 && N <= 45589) {
      FDL_Low = 3600;
      NDL_Offset = 43590;
    } else if (N >= 45590 && N <= 46589) {
      FDL_Low = 703;
      NDL_Offset = 45590;
    }
    double downlinkMHz = (FDL_Low + (0.1 * (N - NDL_Offset)));
    double downlinkFrequency = downlinkMHz * 1000 * 1000;
    return downlinkFrequency;
  }

  static int calculateLteBand(int N) {
    if (N >= 0 && N <= 599) {
      return 1;
    } else if (N >= 600 && N <= 1199) {
      return 2;
    } else if (N >= 1200 && N <= 1949) {
      return 3;
    } else if (N >= 1950 && N <= 2399) {
      return 4;
    } else if (N >= 2400 && N <= 2649) {
      return 5;
    } else if (N >= 2650 && N <= 2749) {
      return 6;
    } else if (N >= 2750 && N <= 3449) {
      return 7;
    } else if (N >= 3450 && N <= 3799) {
      return 8;
    } else if (N >= 3800 && N <= 4149) {
      return 9;
    } else if (N >= 4150 && N <= 4749) {
      return 10;
    } else if (N >= 4750 && N <= 4999) {
      return 11;
    } else if (N >= 5000 && N <= 5179) {
      return 12;
    } else if (N >= 5180 && N <= 5279) {
      return 13;
    } else if (N >= 5280 && N <= 5379) {
      return 14;
    } else if (N >= 5730 && N <= 5849) {
      return 17;
    } else if (N >= 5850 && N <= 5999) {
      return 18;
    } else if (N >= 6000 && N <= 6149) {
      return 19;
    } else if (N >= 6150 && N <= 6449) {
      return 20;
    } else if (N >= 6450 && N <= 6599) {
      return 21;
    } else if (N >= 6600 && N <= 7399) {
      return 22;
    } else if (N >= 7500 && N <= 7699) {
      return 23;
    } else if (N >= 7700 && N <= 8039) {
      return 24;
    } else if (N >= 8040 && N <= 8689) {
      return 25;
    } else if (N >= 8690 && N <= 9039) {
      return 26;
    } else if (N >= 9040 && N <= 9209) {
      return 27;
    } else if (N >= 9210 && N <= 9659) {
      return 28;
    } else if (N >= 9660 && N <= 9769) {
      return 29;
    } else if (N >= 9870 && N <= 9919) {
      return 31;
    } else if (N >= 36000 && N <= 36199) {
      return 33;
    } else if (N >= 36200 && N <= 36349) {
      return 34;
    } else if (N >= 36350 && N <= 36949) {
      return 35;
    } else if (N >= 36950 && N <= 37549) {
      return 36;
    } else if (N >= 37550 && N <= 37749) {
      return 37;
    } else if (N >= 37750 && N <= 38249) {
      return 38;
    } else if (N >= 38250 && N <= 38649) {
      return 39;
    } else if (N >= 38650 && N <= 39649) {
      return 40;
    } else if (N >= 39650 && N <= 41589) {
      return 41;
    } else if (N >= 41590 && N <= 43589) {
      return 42;
    } else if (N >= 43590 && N <= 45589) {
      return 43;
    } else if (N >= 45590 && N <= 46589) {
      return 44;
    }
    return null;
  }

  static String calculateLteBandName(int N) {
    if (N >= 0 && N <= 599) {
      return "2100 IMT";
    } else if (N >= 600 && N <= 1199) {
      return "1900 PCS blocks A-F";
    } else if (N >= 1200 && N <= 1949) {
      return "1800 DCS";
    } else if (N >= 1950 && N <= 2399) {
      return "1700 AWS blocks A-F (AWS-1)";
    } else if (N >= 2400 && N <= 2649) {
      return "850 CLR";
    } else if (N >= 2650 && N <= 2749) {
      return "850 Japan UMTS 800";
    } else if (N >= 2750 && N <= 3449) {
      return "2600 IMT-E";
    } else if (N >= 3450 && N <= 3799) {
      return "900 E-GSM";
    } else if (N >= 3800 && N <= 4149) {
      return "1800 Japan UMTS 1700 DCS";
    } else if (N >= 4150 && N <= 4749) {
      return "1700 Extended AWS blocks A-I";
    } else if (N >= 4750 && N <= 4999) {
      return "1500 Lower PDC";
    } else if (N >= 5000 && N <= 5179) {
      return "700 Lower SMH blocks A/B/C";
    } else if (N >= 5180 && N <= 5279) {
      return "700 Upper SMH block C";
    } else if (N >= 5280 && N <= 5379) {
      return "700 Upper SMH block D";
    } else if (N >= 5730 && N <= 5849) {
      return "700 Lower SMH blocks B/C";
    } else if (N >= 5850 && N <= 5999) {
      return "850 Japan lower 800";
    } else if (N >= 6000 && N <= 6149) {
      return "850 Japan upper 800";
    } else if (N >= 6150 && N <= 6449) {
      return "800 EU Digital Dividend";
    } else if (N >= 6450 && N <= 6599) {
      return "1500 Upper PDC";
    } else if (N >= 6600 && N <= 7399) {
      return "3500";
    } else if (N >= 7500 && N <= 7699) {
      return "2000 S-Band (AWS-4)";
    } else if (N >= 7700 && N <= 8039) {
      return "1600 L-Band (US)";
    } else if (N >= 8040 && N <= 8689) {
      return "1900 Extended PCS blocks A-G";
    } else if (N >= 8690 && N <= 9039) {
      return "850 Extended CLR";
    } else if (N >= 9040 && N <= 9209) {
      return "850 SMR (adjacent to band 5)";
    } else if (N >= 9210 && N <= 9659) {
      return "700 APT";
    } else if (N >= 9660 && N <= 9769) {
      return "700 Lower SMH blocks D/E";
    } else if (N >= 9870 && N <= 9919) {
      return "450";
    } else if (N >= 36000 && N <= 36199) {
      return "2100 IMT";
    } else if (N >= 36200 && N <= 36349) {
      return "2100 IMT";
    } else if (N >= 36350 && N <= 36949) {
      return "1900 PCS (Uplink)";
    } else if (N >= 36950 && N <= 37549) {
      return "1900 PCS (Downlink)";
    } else if (N >= 37550 && N <= 37749) {
      return "1900 PCS (Duplex spacing)";
    } else if (N >= 37750 && N <= 38249) {
      return "2600 IMT-E (Duplex Spacing)";
    } else if (N >= 38250 && N <= 38649) {
      return "1900 DCS-IMT gap";
    } else if (N >= 38650 && N <= 39649) {
      return "2300";
    } else if (N >= 39650 && N <= 41589) {
      return "2500 BRS / EBS";
    } else if (N >= 41590 && N <= 43589) {
      return "3500";
    } else if (N >= 43590 && N <= 45589) {
      return "3700";
    } else if (N >= 45590 && N <= 46589) {
      return "700 APT";
    }
    return null;
  }

// http://www.rfwireless-world.com/Terminology/UMTS-UARFCN-to-frequency-conversion.html
  static double calculateUmtsFrequency(int Ndl) {
    int FDL_offset = 0;
    int FUL_offset = 0;
    int diff = 0;
    int Nul = 0;
    if (Ndl >= 10562 && Ndl <= 10838) {
      FDL_offset = 0;
      FUL_offset = 0;
      diff = Ndl - 10562;
      Nul = 9612 + diff;
    } else if (Ndl >= 9662 && Ndl <= 9938) {
      FDL_offset = 0;
      FUL_offset = 0;
      diff = Ndl - 9662;
      Nul = 9262 + diff;
    } else if (Ndl >= 1162 && Ndl <= 1513) {
      FDL_offset = 1575;
      FUL_offset = 1525;
      diff = Ndl - 1162;
      Nul = 937 + diff;
    } else if (Ndl >= 1537 && Ndl <= 1738) {
      FDL_offset = 1805;
      FUL_offset = 1450;
      diff = Ndl - 1537;
      Nul = 1312 + diff;
    } else if (Ndl >= 4357 && Ndl <= 4458) {
      FDL_offset = 0;
      FUL_offset = 0;
      diff = Ndl - 4357;
      Nul = 4132 + diff;
    } else if (Ndl >= 4387 && Ndl <= 4413) {
      FDL_offset = 0;
      FUL_offset = 0;
      diff = Ndl - 4387;
      Nul = 4162 + diff;
    } else if (Ndl >= 2237 && Ndl <= 2563) {
      FDL_offset = 2175;
      FUL_offset = 2100;
      diff = Ndl - 2237;
      Nul = 2012 + diff;
    } else if (Ndl >= 2937 && Ndl <= 3088) {
      FDL_offset = 340;
      FUL_offset = 340;
      diff = Ndl - 2937;
      Nul = 2712 + diff;
    } else if (Ndl >= 9237 && Ndl <= 9387) {
      FDL_offset = 0;
      FUL_offset = 0;
      diff = Ndl - 9237;
      Nul = 8762 + diff;
    } else if (Ndl >= 3112 && Ndl <= 3388) {
      FDL_offset = 1490;
      FUL_offset = 1135;
      diff = Ndl - 3112;
      Nul = 2887 + diff;
    } else if (Ndl >= 3712 && Ndl <= 3787) {
      FDL_offset = 736;
      FUL_offset = 733;
      diff = Ndl - 3712;
      Nul = 3487 + diff;
    } else if (Ndl >= 3842 && Ndl <= 3903) {
      FDL_offset = -37;
      FUL_offset = -22;
      diff = Ndl - 3842;
      Nul = 3617 + diff;
    } else if (Ndl >= 4017 && Ndl <= 4043) {
      FDL_offset = -55;
      FUL_offset = 21;
      diff = Ndl - 4017;
      Nul = 3792 + diff;
    } else if (Ndl >= 4117 && Ndl <= 4143) {
      FDL_offset = -63;
      FUL_offset = 12;
      diff = Ndl - 4117;
      Nul = 3892 + diff;
    } else if (Ndl >= 712 && Ndl <= 763) {
      FDL_offset = 735;
      FUL_offset = 770;
      diff = Ndl - 712;
      Nul = 312 + diff;
    } else if (Ndl >= 4512 && Ndl <= 4638) {
      FDL_offset = -109;
      FUL_offset = -23;
      diff = Ndl - 4512;
      Nul = 4287 + diff;
    } else if (Ndl >= 862 && Ndl <= 912) {
      FDL_offset = 1326;
      FUL_offset = 1358;
      diff = Ndl - 862;
      Nul = 462 + diff;
    } else if (Ndl >= 4662 && Ndl <= 5038) {
      FDL_offset = 2580;
      FUL_offset = 2525;
      diff = Ndl - 4662;
      Nul = 4437 + diff;
    } else if (Ndl >= 5112 && Ndl <= 5413) {
      FDL_offset = 910;
      FUL_offset = 875;
      diff = Ndl - 5112;
      Nul = 4887 + diff;
    } else if (Ndl >= 5762 && Ndl <= 5913) {
      FDL_offset = -291;
      FUL_offset = -291;
      diff = Ndl - 5762;
      Nul = 5537 + diff;
    } else if (Ndl >= 6617 && Ndl <= 6813) {
      FDL_offset = 131;
    } else if (Ndl >= 9500 && Ndl <= 9600) {
      FDL_offset = 0;
    } else if (Ndl >= 10050 && Ndl <= 10125) {
      FDL_offset = 0;
    } else if (Ndl >= 9250 && Ndl <= 9550) {
      FDL_offset = 0;
    } else if (Ndl >= 9650 && Ndl <= 9950) {
      FDL_offset = 0;
    } else if (Ndl >= 9550 && Ndl <= 9650) {
      FDL_offset = 0;
    } else if (Ndl >= 12850 && Ndl <= 13100) {
      FDL_offset = 0;
    } else if (Ndl >= 9400 && Ndl <= 9600) {
      FDL_offset = 0;
    } else if (Ndl >= 11500 && Ndl <= 12000) {
      FDL_offset = 0;
    }
    double downlinkMHz = FDL_offset + (0.2 * Ndl);
    double downlinkFrequency = (downlinkMHz * 1000 * 1000);
    return downlinkFrequency;
  }

// http://www.rfwireless-world.com/Tutorials/UMTS-frequency-bands-UARFCN.html
  static int calculateUmtsBand(int Ndl) {
    if (Ndl >= 10562 && Ndl <= 10838) {
      // FDD
      return 1;
    } else if (Ndl >= 9662 && Ndl <= 9938) {
      return 2;
    } else if (Ndl >= 1162 && Ndl <= 1513) {
      return 3;
    } else if (Ndl >= 1537 && Ndl <= 1738) {
      return 4;
    } else if (Ndl >= 4357 && Ndl <= 4458) {
      return 5;
    } else if (Ndl >= 4387 && Ndl <= 4413) {
      return 6;
    } else if (Ndl >= 2237 && Ndl <= 2563) {
      return 7;
    } else if (Ndl >= 2937 && Ndl <= 3088) {
      return 8;
    } else if (Ndl >= 9237 && Ndl <= 9387) {
      return 9;
    } else if (Ndl >= 3112 && Ndl <= 3388) {
      return 10;
    } else if (Ndl >= 3712 && Ndl <= 3787) {
      return 11;
    } else if (Ndl >= 3842 && Ndl <= 3903) {
      return 12;
    } else if (Ndl >= 4017 && Ndl <= 4043) {
      return 13;
    } else if (Ndl >= 4117 && Ndl <= 4143) {
      return 14;
    } else if (Ndl >= 712 && Ndl <= 763) {
      return 19;
    } else if (Ndl >= 4512 && Ndl <= 4638) {
      return 20;
    } else if (Ndl >= 862 && Ndl <= 912) {
      return 21;
    } else if (Ndl >= 4662 && Ndl <= 5038) {
      return 22;
    } else if (Ndl >= 5112 && Ndl <= 5413) {
      return 25;
    } else if (Ndl >= 5762 && Ndl <= 5913) {
      return 26;
    } else if (Ndl >= 6617 && Ndl <= 6813) {
      return 32;
    } else if (Ndl >= 9500 && Ndl <= 9600) {
      // TDD
      return 33;
    } else if (Ndl >= 10050 && Ndl <= 10125) {
      return 34;
    } else if (Ndl >= 9250 && Ndl <= 9550) {
      return 35;
    } else if (Ndl >= 9650 && Ndl <= 9950) {
      return 36;
    } else if (Ndl >= 9550 && Ndl <= 9650) {
      return 37;
    } else if (Ndl >= 12850 && Ndl <= 13100) {
      return 38;
    } else if (Ndl >= 9400 && Ndl <= 9600) {
      return 39;
    } else if (Ndl >= 11500 && Ndl <= 12000) {
      return 40;
    }
    return null;
  }

// http://www.rfwireless-world.com/Tutorials/UMTS-frequency-bands-UARFCN.html
  static String calculateUmtsBandName(int Ndl) {
    if (Ndl >= 10562 && Ndl <= 10838) {
      // FDD
      return "2100 IMT";
    } else if (Ndl >= 9662 && Ndl <= 9938) {
      return "1900 PCS A-F";
    } else if (Ndl >= 1162 && Ndl <= 1513) {
      return "1800 DCS";
    } else if (Ndl >= 1537 && Ndl <= 1738) {
      return "1700 AWS A-F";
    } else if (Ndl >= 4357 && Ndl <= 4458) {
      return "850 CLR";
    } else if (Ndl >= 4387 && Ndl <= 4413) {
      return "800";
    } else if (Ndl >= 2237 && Ndl <= 2563) {
      return "2600 IMT-E";
    } else if (Ndl >= 2937 && Ndl <= 3088) {
      return "900 E-GSM";
    } else if (Ndl >= 9237 && Ndl <= 9387) {
      return "1700";
    } else if (Ndl >= 3112 && Ndl <= 3388) {
      return "1700 EAWS A-G";
    } else if (Ndl >= 3712 && Ndl <= 3787) {
      return "1500 LPDC";
    } else if (Ndl >= 3842 && Ndl <= 3903) {
      return "700 LSMH A/B/C";
    } else if (Ndl >= 4017 && Ndl <= 4043) {
      return "700 USMH C";
    } else if (Ndl >= 4117 && Ndl <= 4143) {
      return "700 USMH D";
    } else if (Ndl >= 712 && Ndl <= 763) {
      return "800";
    } else if (Ndl >= 4512 && Ndl <= 4638) {
      return "800 EUDD";
    } else if (Ndl >= 862 && Ndl <= 912) {
      return "800 EUDD";
    } else if (Ndl >= 4662 && Ndl <= 5038) {
      return "3500";
    } else if (Ndl >= 5112 && Ndl <= 5413) {
      return "1900 EPCS A-G";
    } else if (Ndl >= 5762 && Ndl <= 5913) {
      return "850 ECLR";
    } else if (Ndl >= 6617 && Ndl <= 6813) {
      return "1500 L-band";
    } else if (Ndl >= 9500 && Ndl <= 9600) {
      // TDD
      return "1900 TDD A (lower) IMT";
    } else if (Ndl >= 10050 && Ndl <= 10125) {
      return "2010 TDD A (upper) IMT";
    } else if (Ndl >= 9250 && Ndl <= 9550) {
      return "1850 TDD B (lower) PCS";
    } else if (Ndl >= 9650 && Ndl <= 9950) {
      return "1930 TDD B (upper) PCS";
    } else if (Ndl >= 9550 && Ndl <= 9650) {
      return "1910 TDD C PCS (Duplex-Gap)";
    } else if (Ndl >= 12850 && Ndl <= 13100) {
      return "2570 TDD D IMT-E";
    } else if (Ndl >= 9400 && Ndl <= 9600) {
      return "2300 TDD E";
    } else if (Ndl >= 11500 && Ndl <= 12000) {
      return "2300 TDD F";
    }
    return null;
  }

/*
  static double getFrequencyInt(int networkTypeInt, int arfcn) {
    return getFrequency(
        CellIdentity.getNetworkGeneration(networkTypeInt), arfcn);
  }

  static double getFrequency(int networkType, int arfcn) {
    double frequency = 0;
    if (arfcn == 0) return 0;

    if (networkType == NetworkType.NETWORK_TYPE_GSM) {
      frequency = CellIdentity.calculateGsmFrequency(arfcn);
    } else if (networkType == NetworkType.NETWORK_TYPE_UMTS) {
      frequency = CellIdentity.calculateUmtsFrequency(arfcn);
    } else if (networkType == NetworkType.NETWORK_TYPE_LTE) {
      frequency = CellIdentity.calculateLteFrequency(arfcn);
    }
    return frequency;
  }

  static int getFrequencyBand(int networkType, int arfcn) {
    int frequencyBand = 0;
    if (arfcn == 0) return null;

    if (networkType == NetworkType.NETWORK_TYPE_GSM) {
      frequencyBand = CellIdentity.calculateGsmBand(arfcn);
    } else if (networkType == NetworkType.NETWORK_TYPE_UMTS) {
      frequencyBand = CellIdentity.calculateUmtsBand(arfcn);
    } else if (networkType == NetworkType.NETWORK_TYPE_LTE) {
      frequencyBand = CellIdentity.calculateLteBand(arfcn);
    }
    return frequencyBand;
  }

// Returns metres (doubled for return distance)
  static int getTimingAdvanceDistance(int nt, int ta) {
    if (ta < 0) ta = 0;
    if (nt == NetworkType.NETWORK_TYPE_GSM) {
      // http://www.gsm-modem.de/gsm-location.html
      double timingAdvanceDistance =
          (299792.458 * ta * 3.69 / 1000 / 2); // metres
      return timingAdvanceDistance.round();
    } else if (nt == NetworkType.NETWORK_TYPE_LTE) {
      double timingAdvanceDistance =
          (299792.458 * ta * 16 * (1.0 / (15000 * 2048)) / 2) * 1000; // metres
      return timingAdvanceDistance.round();
    }
    return double.maxFinite.toInt();
  }


  static String getTimingAdvanceDistanceString(int nt, int ta) {
    int timingAdvanceDistance = getTimingAdvanceDistance(nt, ta);
    return formatDistanceString(timingAdvanceDistance);
  }

  static String formatDistanceString(int distance) {
//DecimalFormat nf = new DecimalFormat("0.0"); // Show one decimal place as needed

    final formatter = new NumberFormat("#,#");
    if (distance >= 10 * 1000) return "${distance / 1000} km";
    if (distance >= 1 * 1000)
      return "${formatter.format(distance / 1000.0)} km";
    return "$distance m";
  }
  */
}
