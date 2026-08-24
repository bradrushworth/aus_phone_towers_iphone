import 'dart:math' as math;
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

  /// Carrier colours, checked against each brand's published guidelines (2026-08-24).
  ///
  /// Telstra is "Blue Ribbon" #0D54FF and Vodafone is #E60000 (Pantone 485) — both were
  /// previously approximated (#000AFF and #FF0000). The Telstra correction also helps
  /// legibility: the old near-pure blue muddied against dark terrain at small sizes.
  ///
  /// Optus is a DELIBERATE deviation and should not be "corrected" to their brand yellow
  /// (#FECD03). Yellow has almost no contrast on a light terrain basemap, and yellow and
  /// orange are already taken here — yellow is the serving-cell/OpenCellID marker, orange
  /// is the observation trail. #007F87 is a darkened take on Optus's own secondary
  /// aquamarine (#39A8AF); their lighter value would lose contrast against the map.
  ///
  /// Keep in lockstep with the Java app's Telco.getColor / getHtmlColour / getColour.
  static Color getColor(Telco selectedEnum, int alpha) {
    switch (selectedEnum) {
      case Telco.Telstra:
        return Color.fromARGB(alpha, 13, 84, 255);
      case Telco.Optus:
        return Color.fromARGB(alpha, 0, 127, 135);
      case Telco.Vodafone:
        return Color.fromARGB(alpha, 230, 0, 0);
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

  // The rotated pin is identical for every site of a telco, and thousands of markers are
  // created while panning — decode/rotate/encode once per telco only.
  static final Map<Telco, Uint8List> _rotatedIconCache = {};
  static final Map<Telco, double> _rotatedIconWidthFactor = {};
  static final Map<Telco, ui.Offset> _rotatedIconAnchor = {};

  /// The telco's pin PNG pre-rotated about its TIP by [getRotation], cropped to the rotated
  /// pin's TIGHT bounding box, with the tip's position inside that box exposed via
  /// [rotatedIconAnchor] — the Marker must use that anchor and `rotation: 0`.
  ///
  /// The rotation is baked into the bitmap because google_maps_flutter_web ignores
  /// `Marker.rotation` entirely: on the web build every co-located telco pin rendered bolt
  /// upright on top of the others, completely hiding e.g. the Vodafone pin behind the
  /// Telstra one (the Java app fans them out at ±60° etc., which is what this restores).
  /// Because the lean is baked in, `Marker.rotation` must STAY 0 on every platform or
  /// Android/iOS would rotate the pin twice.
  ///
  /// The TIGHT crop is load-bearing for tap handling: markers hit-test on the whole icon
  /// bitmap (transparent pixels included). A first version drew every pin at the centre of
  /// the same swept-circle square, so all co-located telcos' tap targets were identical
  /// concentric rectangles and every tap landed on the top of the stack (always Telstra).
  /// Cropped, Telstra's bitmap extends only to the left of the shared tip and Vodafone's
  /// only to the right, so each pin's head is tappable in its own right.
  static Future<Uint8List> getRotatedIcon(Telco telco) async {
    Uint8List? cached = _rotatedIconCache[telco];
    if (cached != null) return cached;

    ByteData data = await rootBundle.load(getIconFullName(telco));
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.Image image = (await codec.getNextFrame()).image;
    final double w = image.width.toDouble();
    final double h = image.height.toDouble();
    final double theta = getRotation(telco) * math.pi / 180.0;
    final double cosT = math.cos(theta);
    final double sinT = math.sin(theta);

    // Rotate the pin rectangle's corners about the tip (the PNG's bottom-centre, our
    // origin) and take the bounding box. The tip (0,0) is one of the rectangle's edge
    // points, so it always lies within the box.
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    for (final corner in [
      [-w / 2, -h], [w / 2, -h], [w / 2, 0.0], [-w / 2, 0.0]
    ]) {
      final double rx = corner[0] * cosT - corner[1] * sinT;
      final double ry = corner[0] * sinT + corner[1] * cosT;
      minX = math.min(minX, rx); maxX = math.max(maxX, rx);
      minY = math.min(minY, ry); maxY = math.max(maxY, ry);
    }
    final int outW = (maxX - minX).ceil();
    final int outH = (maxY - minY).ceil();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    canvas.translate(-minX, -minY); // tip lands at (-minX, -minY) inside the box
    canvas.rotate(theta);
    canvas.drawImage(image, ui.Offset(-w / 2, -h), ui.Paint());
    final ui.Image out = await recorder.endRecording().toImage(outW, outH);
    final Uint8List bytes =
        (await out.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

    _rotatedIconCache[telco] = bytes;
    _rotatedIconWidthFactor[telco] = outW / w;
    _rotatedIconAnchor[telco] = ui.Offset(-minX / outW, -minY / outH);
    return bytes;
  }

  /// Multiplier for the Marker's `width` so the pin inside the (larger) rotated canvas
  /// renders at the same on-screen size the unrotated PNG did. Only valid after
  /// [getRotatedIcon] has completed for this telco.
  static double rotatedIconWidthFactor(Telco telco) {
    return _rotatedIconWidthFactor[telco] ?? 1.0;
  }

  /// Where the pin TIP sits inside the cropped rotated bitmap, as a fractional Marker
  /// anchor. Only valid after [getRotatedIcon] has completed for this telco.
  static ui.Offset rotatedIconAnchor(Telco telco) {
    return _rotatedIconAnchor[telco] ?? const ui.Offset(0.5, 1.0);
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
