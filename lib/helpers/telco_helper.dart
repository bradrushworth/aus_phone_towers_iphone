import 'package:flutter/material.dart';

enum Telco {
  Telstra,
  Optus,
  Vodafone,
  NBN,
  Other,
  Radio,
  TV,
  CBRS,
  Aviation,
  Civil,
  Pager,
}

class TelcoHelper {
  static bool isTelecommunications(Telco selectedEnum) {
    if (selectedEnum == Telco.Telstra ||
        selectedEnum == Telco.Optus ||
        selectedEnum == Telco.Vodafone ||
        selectedEnum == Telco.NBN ||
        selectedEnum == Telco.Other) {
      return true;
    }
    return false;
  }

  static Color getColor(Telco selectedEnum, int alpha) {
    switch (selectedEnum) {
      case Telco.Telstra:
        return Color.fromARGB(alpha, 0, 10, 255);
      case Telco.Optus:
        return Color.fromARGB(alpha, 0, 127, 135);
      case Telco.Vodafone:
        return Color.fromARGB(alpha, 255, 0, 0);
      case Telco.NBN:
        return Color.fromARGB(alpha, 145, 15, 145);
      case Telco.Other:
        return Color.fromARGB(alpha, 0, 127, 255);
      default:
        return Color.fromARGB(alpha, 255, 177, 216);
    }
  }

  int getMnc(Telco selectedEnum) {
    switch (selectedEnum) {
      case Telco.Telstra:
        return 1;
      case Telco.Optus:
        return 2;
      case Telco.Vodafone:
        return 3;
      default:
        return 0;
    }
  }

  static Telco getTelco(int mnc) {
    switch (mnc) {
      case 1:
        return Telco.Telstra;
      case 2:
        return Telco.Optus;
      case 3:
        return Telco.Vodafone;
      default:
        return null;
    }
  }

  static String getName(Telco telco) {
    return telco.toString().split('.').last;
  }

  static String getNameLowerCase(Telco telco) {
    return telco.toString().split('.').last.toLowerCase();
  }
}
