import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum Telco {
  Telstra,
  Optus,
  Vodafone,
  NBN,
  Dense_Air,
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

  static Future<Uint8List> getBytesFromAsset({String path, int width}) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return await (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        .buffer
        .asUint8List();
  }

  static String getIconName(Telco telco) {
    switch (telco) {
      case Telco.Telstra:
        return 'icons/telstra.png';
      case Telco.Optus:
        return 'icons/optus.png';
      case Telco.Vodafone:
        return 'icons/vodafone.png';
      case Telco.NBN:
        return 'icons/nbn.png';
      case Telco.Dense_Air:
        return 'icons/denseair.png';
      case Telco.Other:
        return 'icons/other.png';
      default:
        return 'icons/nontelco.png';
    }
  }

  static Future<Uint8List> getIcon(Telco telco, int width) {
    return getBytesFromAsset(
        path: 'assets/' + getIconName(telco), width: width);
  }

  static double getColour(Telco telco) {
    double colour;
    if (telco == Telco.Telstra) {
      colour = BitmapDescriptor.hueBlue;
    } else if (telco == Telco.Optus) {
      colour = BitmapDescriptor.hueCyan;
    } else if (telco == Telco.Vodafone) {
      colour = BitmapDescriptor.hueRed;
    } else if (telco == Telco.NBN) {
      colour = BitmapDescriptor.hueViolet;
    } else if (telco == Telco.Other) {
      colour = BitmapDescriptor.hueAzure;
    } else {
      colour = BitmapDescriptor.hueRose;
    }
    return colour;
  }

  static double getRotation(Telco telco) {
    double rotation = 0;
    if (telco == Telco.Telstra) {
      rotation = -50;
    } else if (telco == Telco.Optus) {
      rotation = 0;
    } else if (telco == Telco.Vodafone) {
      rotation = 50;
    } else if (telco == Telco.NBN) {
      rotation = 100;
    } else if (telco == Telco.Other) {
      rotation = -100;
    } else {
      if (telco == Telco.Radio) {
        rotation = 150;
      } else if (telco == Telco.TV) {
        rotation = -150;
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
    double alpha = 0.70;
    if (telco == Telco.Telstra) {} else if (telco == Telco.Optus) {} else
    if (telco == Telco.Vodafone) {} else
    if (telco == Telco.NBN) {} else if (telco == Telco.Other) {} else {}
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

  static Telco getTelco(int mnc) {
    switch (mnc) {
      case 1:
        return Telco.Telstra;
      case 2:
        return Telco.Optus;
      case 3:
        return Telco.Vodafone;
      case 13:
      case 14:
        return Telco.Other;
      default:
        return null;
    }
  }

  static String getName(Telco telco) {
    return telco
        .toString()
        .split('.')
        .last
        .replaceAll('_', ' ');
  }

  static String getNameLowerCase(Telco telco) {
    return getName(telco).toLowerCase();
  }
}
