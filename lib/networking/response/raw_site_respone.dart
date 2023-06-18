class RawSiteResponse {
  Restify? restify;

  RawSiteResponse({required this.restify});

  RawSiteResponse.fromJson(Map<String, dynamic> json) {
    restify =
        json['restify'] != null ? new Restify.fromJson(json['restify']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.restify != null) {
      data['restify'] = this.restify!.toJson();
    }
    return data;
  }
}

class Restify {
  List<Rows>? rows;

  Restify({required this.rows});

  Restify.fromJson(Map<String, dynamic> json) {
    if (json['rows'] != null) {
      rows = [];
      json['rows'].forEach((v) {
        rows!.add(new Rows.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.rows != null) {
      data['rows'] = this.rows!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Rows {
  String? href;
  Values? values;

  Rows({this.href, this.values});

  Rows.fromJson(Map<String, dynamic> json) {
    href = json['href'];
    values =
        json['values'] != null ? new Values.fromJson(json['values']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    if (this.values != null) {
      data['values'] = this.values!.toJson();
    }
    return data;
  }
}

class Values {
  //SiteId siteId;
  Latitude? latitude;
  Longitude? longitude;
//  Name name;
//  SiteState state;
//  LicensingAreaId licensingAreaId;
//  Postcode postcode;
//  SitePrecision sitePrecision;
//  Elevation elevation;
//  HcisL2 hcisL2;
//  SiteGeohash geohash;

  Values({
    //this.siteId,
    required this.latitude,
    required this.longitude,
//      this.name,
//      this.state,
//      this.licensingAreaId,
//      this.postcode,
//      this.sitePrecision,
//      this.elevation,
//      this.hcisL2,
//      this.geohash
  });

  Values.fromJson(Map<String, dynamic> json) {
//    siteId =
//        json['site_id'] != null ? new SiteId.fromJson(json['site_id']) : null;
    latitude = json['latitude'] != null
        ? new Latitude.fromJson(json['latitude'])
        : null;
    longitude = json['longitude'] != null
        ? new Longitude.fromJson(json['longitude'])
        : null;
//    name = json['name'] != null ? new Name.fromJson(json['name']) : null;
//    state =
//        json['state'] != null ? new SiteState.fromJson(json['state']) : null;
//    licensingAreaId = json['licensing_area_id'] != null
//        ? new LicensingAreaId.fromJson(json['licensing_area_id'])
//        : null;
//    postcode = json['postcode'] != null
//        ? new Postcode.fromJson(json['postcode'])
//        : null;
//    sitePrecision = json['site_precision'] != null
//        ? new SitePrecision.fromJson(json['site_precision'])
//        : null;
//    elevation = json['elevation'] != null
//        ? new Elevation.fromJson(json['elevation'])
//        : null;
//    hcisL2 =
//        json['hcis_l2'] != null ? new HcisL2.fromJson(json['hcis_l2']) : null;
//    geohash = json['geohash'] != null
//        ? new SiteGeohash.fromJson(json['geohash'])
//        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
//
//    if (this.siteId != null) {
//      data['site_id'] = this.siteId.toJson();
//    }

    if (this.latitude != null) {
      data['latitude'] = this.latitude!.toJson();
    }
    if (this.longitude != null) {
      data['longitude'] = this.longitude!.toJson();
    }

//    if (this.name != null) {
//      data['name'] = this.name.toJson();
//    }
//    if (this.state != null) {
//      data['state'] = this.state.toJson();
//    }
//    if (this.licensingAreaId != null) {
//      data['licensing_area_id'] = this.licensingAreaId.toJson();
//    }
//    if (this.postcode != null) {
//      data['postcode'] = this.postcode.toJson();
//    }
//    if (this.sitePrecision != null) {
//      data['site_precision'] = this.sitePrecision.toJson();
//    }
//    if (this.elevation != null) {
//      data['elevation'] = this.elevation.toJson();
//    }
//    if (this.hcisL2 != null) {
//      data['hcis_l2'] = this.hcisL2.toJson();
//    }
//    if (this.geohash != null) {
//      data['geohash'] = this.geohash.toJson();
//    }

    return data;
  }
}

class Latitude {
  late String value;

  Latitude({required this.value});

  Latitude.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Longitude {
  late String value;

  Longitude({required this.value});

  Longitude.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

//class SiteId {
//  String value;
//
//  SiteId({this.value});
//
//  SiteId.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class Name {
//  String value;
//
//  Name({this.value});
//
//  Name.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class SiteState {
//  String value;
//
//  SiteState({this.value});
//
//  SiteState.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class LicensingAreaId {
//  String value;
//
//  LicensingAreaId({this.value});
//
//  LicensingAreaId.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class Postcode {
//  String value;
//
//  Postcode({this.value});
//
//  Postcode.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class SitePrecision {
//  String value;
//
//  SitePrecision({this.value});
//
//  SitePrecision.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class Elevation {
//  String value;
//
//  Elevation({this.value});
//
//  Elevation.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class HcisL2 {
//  String value;
//
//  HcisL2({this.value});
//
//  HcisL2.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
//
//class SiteGeohash {
//  String value;
//
//  SiteGeohash({this.value});
//
//  SiteGeohash.fromJson(Map<String, dynamic> json) {
//    value = json['value'];
//  }
//
//  Map<String, dynamic> toJson() {
//    final Map<String, dynamic> data = new Map<String, dynamic>();
//    data['value'] = this.value;
//    return data;
//  }
//}
