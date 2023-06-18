import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

enum Telco {
  Telstra,
  Optus,
  Vodafone,
  Dense_Air,
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
        selectedEnum == Telco.Dense_Air ||
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
      case Telco.Dense_Air:
        return Color.fromARGB(alpha, 17, 53, 79);
      case Telco.Other:
        return Color.fromARGB(alpha, 0, 127, 255);
      default:
        return Color.fromARGB(alpha, 255, 177, 216);
    }
  }

  static Future<Uint8List> getBytesFromAsset({required String path, int? width}) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.FrameInfo fi = await codec.getNextFrame();
    return await (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  static String getIconName(Telco telco) {
    switch (telco) {
      case Telco.Telstra:
        return 'telstra.png';
      case Telco.Optus:
        return 'optus.png';
      case Telco.Vodafone:
        return 'vodafone.png';
      case Telco.NBN:
        return 'nbn.png';
      case Telco.Dense_Air:
        return 'dense_air.png';
      case Telco.Other:
        return 'other.png';
      default:
        return 'non_telco.png';
    }
  }

  static String getIconFullName(Telco telco) {
    // Different paths is a weird incompatibility
    return (kIsWeb ? 'assets/icons_web' : 'assets/icons') + '/' + getIconName(telco);
  }

  static Future<Uint8List> getIconByString(String name) {
    return getBytesFromAsset(path: name);
  }

  static Future<Uint8List> getIcon(Telco telco) {
    return getIconByString(getIconFullName(telco));
  }

  // static double getColour(Telco telco) {
  //   double colour;
  //   if (telco == Telco.Telstra) {
  //     colour = BitmapDescriptor.hueBlue;
  //   } else if (telco == Telco.Optus) {
  //     colour = BitmapDescriptor.hueCyan;
  //   } else if (telco == Telco.Vodafone) {
  //     colour = BitmapDescriptor.hueRed;
  //   } else if (telco == Telco.NBN) {
  //     colour = BitmapDescriptor.hueViolet;
  //   } else if (telco == Telco.Other) {
  //     colour = BitmapDescriptor.hueAzure;
  //   } else {
  //     colour = BitmapDescriptor.hueRose;
  //   }
  //   return colour;
  // }

  static double getRotation(Telco telco) {
    double rotation = 0;
    if (telco == Telco.Telstra) {
      rotation = -60;
    } else if (telco == Telco.Optus) {
      rotation = 0;
    } else if (telco == Telco.Vodafone) {
      rotation = 60;
    } else if (telco == Telco.NBN) {
      rotation = 120;
    } else if (telco == Telco.Dense_Air) {
      rotation = 75;
    } else if (telco == Telco.Other) {
      rotation = -120;
    } else {
      if (telco == Telco.Radio) {
        rotation = 160;
      } else if (telco == Telco.TV) {
        rotation = -160;
      } else if (telco == Telco.CBRS) {
        rotation = -120;
      } else if (telco == Telco.Civil) {
        rotation = 120;
      } else if (telco == Telco.Aviation) {
        rotation = -25;
      } else if (telco == Telco.Pager) {
        rotation = 25;
      }
    }
    return rotation;
  }

  static double getAlpha(Telco telco) {
    double alpha = 0.95;
    if (telco == Telco.Telstra) {
    } else if (telco == Telco.Optus) {
    } else if (telco == Telco.Vodafone) {
    } else if (telco == Telco.NBN) {
    } else if (telco == Telco.Dense_Air) {
    } else if (telco == Telco.Other) {
    } else {}
    return alpha;
  }

  static int getMnc(Telco selectedEnum) {
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

  static Telco? getTelco(int mnc) {
    switch (mnc) {
      case 1:
      case 19: // Lycamobile
      case 90:
        return Telco.Telstra;
      case 2:
      case 17: // Vivid Wireless
        return Telco.Optus;
      case 3:
      case 14: // TPG Telecom
        return Telco.Vodafone;
      case 13: // RailCorp
      case 16: // VicTrack
      case 23: // Challenge Networks Pty Ltd
      case 34: // Santos Limited
      case 38: // Truphone
      case 52: // OptiTel Australia
        return Telco.Other;
      case 62: // NBN
      case 68: // NBN
        return Telco.NBN;
      default:
        return null;
    }
  }

  static String getName(Telco telco) {
    return telco.toString().split('.').last.replaceAll('_', ' ');
  }

  static String getNameForApi(Telco telco) {
    return telco.toString().split('.').last.toLowerCase();
  }
}
