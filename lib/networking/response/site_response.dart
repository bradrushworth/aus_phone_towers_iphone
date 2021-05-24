import 'package:json_annotation/json_annotation.dart';

class SiteReponse {
  Restify restify;

  SiteReponse({this.restify});

  SiteReponse.fromJson(Map<String, dynamic> json) {
    restify =
        json['restify'] != null ? new Restify.fromJson(json['restify']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.restify != null) {
      data['restify'] = this.restify.toJson();
    }
    return data;
  }
}

class Restify {
  Self self;
  Parent parent;
  int rowCount;
  int start;
  int offset;
  int currentPage;
  int pageCount;
  NextPage nextPage;
  FirstPage firstPage;
  LastPage lastPage;
  String ownFields;
  List<Rows> rows;

  Restify(
      {this.self,
      this.parent,
      this.rowCount,
      this.start,
      this.offset,
      this.currentPage,
      this.pageCount,
      this.nextPage,
      this.firstPage,
      this.lastPage,
      this.ownFields,
      this.rows});

  Restify.fromJson(Map<String, dynamic> json) {
    self = json['self'] != null ? new Self.fromJson(json['self']) : null;
    parent =
        json['parent'] != null ? new Parent.fromJson(json['parent']) : null;
    rowCount = json['rowCount'];
    start = json['start'];
    offset = json['offset'];
    currentPage = json['currentPage'];
    pageCount = json['pageCount'];
    nextPage = json['nextPage'] != null
        ? new NextPage.fromJson(json['nextPage'])
        : null;
    firstPage = json['firstPage'] != null
        ? new FirstPage.fromJson(json['firstPage'])
        : null;
    lastPage = json['lastPage'] != null
        ? new LastPage.fromJson(json['lastPage'])
        : null;
    ownFields = json['ownFields'];
    if (json['rows'] != null) {
      rows = new List<Rows>();
      json['rows'].forEach((v) {
        rows.add(new Rows.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.self != null) {
      data['self'] = this.self.toJson();
    }
    if (this.parent != null) {
      data['parent'] = this.parent.toJson();
    }
    data['rowCount'] = this.rowCount;
    data['start'] = this.start;
    data['offset'] = this.offset;
    data['currentPage'] = this.currentPage;
    data['pageCount'] = this.pageCount;
    if (this.nextPage != null) {
      data['nextPage'] = this.nextPage.toJson();
    }
    if (this.firstPage != null) {
      data['firstPage'] = this.firstPage.toJson();
    }
    if (this.lastPage != null) {
      data['lastPage'] = this.lastPage.toJson();
    }
    data['ownFields'] = this.ownFields;
    if (this.rows != null) {
      data['rows'] = this.rows.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Self {
  String href;
  String name;

  Self({this.href, this.name});

  Self.fromJson(Map<String, dynamic> json) {
    href = json['href'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    data['name'] = this.name;
    return data;
  }
}

class Parent {
  String href;
  String name;

  Parent({this.href, this.name});

  Parent.fromJson(Map<String, dynamic> json) {
    href = json['href'];
    name = json['name'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    data['name'] = this.name;
    return data;
  }
}

class NextPage {
  String href;
  NextPage({this.href});

  NextPage.fromJson(Map<String, dynamic> json) {
    href = json['href'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    return data;
  }
}

class FirstPage {
  String href;

  FirstPage({this.href});

  FirstPage.fromJson(Map<String, dynamic> json) {
    href = json['href'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    return data;
  }
}

class LastPage {
  String href;

  LastPage({this.href});

  LastPage.fromJson(Map<String, dynamic> json) {
    href = json['href'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['href'] = this.href;
    return data;
  }
}

class Rows {
  String href;
  Values values;

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
      data['values'] = this.values.toJson();
    }
    return data;
  }
}

class Values {
  SiteId siteId;
  Latitude latitude;
  Longitude longitude;
  @JsonKey(name: 'name')
  SiteName name;
  @JsonKey(name: 'state')
  SiteState state;
  LicensingAreaId licensingAreaId;
  Postcode postcode;
  SitePrecision sitePrecision;
  Elevation elevation;
  HcisL2 hcisL2;
  @JsonKey(name: 'geohash')
  SiteGeohash geohash;
  SddId sddId;
  DeviceRegistrationIdentifier deviceRegistrationIdentifier;
  Frequency frequency;
  Bandwidth bandwidth;
  Emission emission;
  Polarisation polarisation;
  Azimuth azimuth;
  Height height;
  Eirp eirp;
  CallSign callSign;
  Active active;
  StartAngle startAngle;
  Power power;
  AntennaId antennaId;
  FrontToBack frontToBack;
  Gain gain;
  HBeamWidth hBeamwidth;

  Values(
      {this.siteId,
      this.latitude,
      this.longitude,
      this.name,
      this.state,
      this.licensingAreaId,
      this.postcode,
      this.sitePrecision,
      this.elevation,
      this.hcisL2,
      this.geohash,
      this.sddId,
      this.deviceRegistrationIdentifier,
      this.frequency,
      this.bandwidth,
      this.emission,
      this.polarisation,
      this.azimuth,
      this.height,
      this.eirp,
      this.callSign,
      this.active,
      this.antennaId,
      this.frontToBack,
      this.gain,
      this.hBeamwidth});

  Values.fromJson(Map<String, dynamic> json) {
    siteId =
        json['site_id'] != null ? new SiteId.fromJson(json['site_id']) : null;
    latitude = json['latitude'] != null
        ? new Latitude.fromJson(json['latitude'])
        : null;
    longitude = json['longitude'] != null
        ? new Longitude.fromJson(json['longitude'])
        : null;
    name = json['name'] != null ? new SiteName.fromJson(json['name']) : null;
    state =
        json['state'] != null ? new SiteState.fromJson(json['state']) : null;
    licensingAreaId = json['licensing_area_id'] != null
        ? new LicensingAreaId.fromJson(json['licensing_area_id'])
        : null;
    postcode = json['postcode'] != null
        ? new Postcode.fromJson(json['postcode'])
        : null;
    sitePrecision = json['site_precision'] != null
        ? new SitePrecision.fromJson(json['site_precision'])
        : null;
    elevation = json['elevation'] != null
        ? new Elevation.fromJson(json['elevation'])
        : null;
    hcisL2 =
        json['hcis_l2'] != null ? new HcisL2.fromJson(json['hcis_l2']) : null;
    geohash = json['geohash'] != null
        ? new SiteGeohash.fromJson(json['geohash'])
        : null;
    sddId = json['sdd_id'] != null ? new SddId.fromJson(json['sdd_id']) : null;
    deviceRegistrationIdentifier =
        json['device_registration_identifier'] != null
            ? new DeviceRegistrationIdentifier.fromJson(
                json['device_registration_identifier'])
            : null;
    frequency = json['frequency'] != null
        ? new Frequency.fromJson(json['frequency'])
        : null;
    bandwidth = json['bandwidth'] != null
        ? new Bandwidth.fromJson(json['bandwidth'])
        : null;
    emission = json['emission'] != null
        ? new Emission.fromJson(json['emission'])
        : null;
    polarisation = json['polarisation'] != null
        ? new Polarisation.fromJson(json['polarisation'])
        : null;
    azimuth =
        json['azimuth'] != null ? new Azimuth.fromJson(json['azimuth']) : null;
    height =
        json['height'] != null ? new Height.fromJson(json['height']) : null;
    eirp = json['eirp'] != null ? new Eirp.fromJson(json['eirp']) : null;
    callSign = json['call_sign'] != null
        ? new CallSign.fromJson(json['call_sign'])
        : null;
    active =
        json['active'] != null ? new Active.fromJson(json['active']) : null;
    startAngle = json['start_angle'] != null
        ? new StartAngle.fromJson(json['start_angle'])
        : null;
    power = json['power'] != null ? new Power.fromJson(json['power']) : null;
    antennaId = json['antenna_id'] != null
        ? new AntennaId.fromJson(json['antenna_id'])
        : null;
    frontToBack = json['front_to_back'] != null
        ? new FrontToBack.fromJson(json['front_to_back'])
        : null;
    gain = json['gain'] != null ? new Gain.fromJson(json['gain']) : null;
    hBeamwidth = json['h_beamwidth'] != null
        ? new HBeamWidth.fromJson(json['h_beamwidth'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.siteId != null) {
      data['site_id'] = this.siteId.toJson();
    }
    if (this.latitude != null) {
      data['latitude'] = this.latitude.toJson();
    }
    if (this.longitude != null) {
      data['longitude'] = this.longitude.toJson();
    }
    if (this.name != null) {
      data['name'] = this.name.toJson();
    }
    if (this.state != null) {
      data['state'] = this.state.toJson();
    }
    if (this.licensingAreaId != null) {
      data['licensing_area_id'] = this.licensingAreaId.toJson();
    }
    if (this.postcode != null) {
      data['postcode'] = this.postcode.toJson();
    }
    if (this.sitePrecision != null) {
      data['site_precision'] = this.sitePrecision.toJson();
    }
    if (this.elevation != null) {
      data['elevation'] = this.elevation.toJson();
    }
    if (this.hcisL2 != null) {
      data['hcis_l2'] = this.hcisL2.toJson();
    }
    if (this.geohash != null) {
      data['geohash'] = this.geohash.toJson();
    }
    if (this.sddId != null) {
      data['sdd_id'] = this.sddId.toJson();
    }
    if (this.deviceRegistrationIdentifier != null) {
      data['device_registration_identifier'] =
          this.deviceRegistrationIdentifier.toJson();
    }
    if (this.frequency != null) {
      data['frequency'] = this.frequency.toJson();
    }
    if (this.bandwidth != null) {
      data['bandwidth'] = this.bandwidth.toJson();
    }
    if (this.emission != null) {
      data['emission'] = this.emission.toJson();
    }
    if (this.polarisation != null) {
      data['polarisation'] = this.polarisation.toJson();
    }
    if (this.azimuth != null) {
      data['azimuth'] = this.azimuth.toJson();
    }
    if (this.height != null) {
      data['height'] = this.height.toJson();
    }
    if (this.eirp != null) {
      data['eirp'] = this.eirp.toJson();
    }
    if (this.callSign != null) {
      data['call_sign'] = this.callSign.toJson();
    }
    if (this.active != null) {
      data['active'] = this.active.toJson();
    }
    if (this.startAngle != null) {
      data['start_angle'] = this.startAngle.toJson();
    }
    if (this.power != null) {
      data['power'] = this.power.toJson();
    }
    if (this.antennaId != null) {
      data['antenna_id'] = this.antennaId.toJson();
    }
    if (this.frontToBack != null) {
      data['front_to_back'] = this.frontToBack.toJson();
    }
    if (this.gain != null) {
      data['gain'] = this.gain.toJson();
    }
    if (this.hBeamwidth != null) {
      data['h_beamwidth'] = this.hBeamwidth.toJson();
    }
    return data;
  }
}

class SiteId {
  String value;

  SiteId({this.value});

  SiteId.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Latitude {
  String value;

  Latitude({this.value});

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
  String value;

  Longitude({this.value});

  Longitude.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class SiteName {
  String value;

  SiteName({this.value});

  SiteName.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class SiteState {
  String value;

  SiteState({this.value});

  SiteState.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class LicensingAreaId {
  String value;

  LicensingAreaId({this.value});

  LicensingAreaId.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Postcode {
  String value;

  Postcode({this.value});

  Postcode.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class SitePrecision {
  String value;

  SitePrecision({this.value});

  SitePrecision.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class HcisL2 {
  String value;

  HcisL2({this.value});

  HcisL2.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Elevation {
  String value;

  Elevation({this.value});

  Elevation.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class SiteGeohash {
  String value;

  SiteGeohash({this.value});

  SiteGeohash.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class SddId {
  String value;

  SddId({this.value});

  SddId.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class DeviceRegistrationIdentifier {
  String value;

  DeviceRegistrationIdentifier({this.value});

  DeviceRegistrationIdentifier.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Frequency {
  String value;

  Frequency({this.value});

  Frequency.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Bandwidth {
  String value;

  Bandwidth({this.value});

  Bandwidth.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Emission {
  String value;

  Emission({this.value});

  Emission.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Polarisation {
  String value;

  Polarisation({this.value});

  Polarisation.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Azimuth {
  String value;

  Azimuth({this.value});

  Azimuth.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Height {
  String value;

  Height({this.value});

  Height.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Eirp {
  String value;

  Eirp({this.value});

  Eirp.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class CallSign {
  String value;

  CallSign({this.value});

  CallSign.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Active {
  String value;

  Active({this.value});

  Active.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class StartAngle {
  String value;

  StartAngle({this.value});

  StartAngle.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Power {
  String value;

  Power({this.value});

  Power.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class AntennaId {
  String value;

  AntennaId({this.value});

  AntennaId.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class Gain {
  String value;

  Gain({this.value});

  Gain.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class FrontToBack {
  String value;

  FrontToBack({this.value});

  FrontToBack.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}

class HBeamWidth {
  String value;

  HBeamWidth({this.value});

  HBeamWidth.fromJson(Map<String, dynamic> json) {
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['value'] = this.value;
    return data;
  }
}
