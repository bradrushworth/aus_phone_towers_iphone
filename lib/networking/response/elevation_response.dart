class ElevationResponse {
  List<Results>? results;
  late String status;

  ElevationResponse({required this.results, required this.status});

  ElevationResponse.fromJson(Map<String, dynamic> json) {
    if (json['results'] != null) {
      results = [];
      json['results'].forEach((v) {
        results!.add(new Results.fromJson(v));
      });
    }
    status = json['status'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.results != null) {
      data['results'] = this.results!.map((v) => v.toJson()).toList();
    }
    data['status'] = this.status;
    return data;
  }
}

class Results {
  late num elevation;
  Location? location;
  late double resolution;

  Results({required this.elevation, required this.location, required this.resolution});

  Results.fromJson(Map<String, dynamic> json) {
    elevation = json['elevation'];
    location = json['location'] != null
        ? new Location.fromJson(json['location'])
        : null;
    resolution = json['resolution'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['elevation'] = this.elevation;
    if (this.location != null) {
      data['location'] = this.location!.toJson();
    }
    data['resolution'] = this.resolution;
    return data;
  }
}

class Location {
  late num lat;
  late num lng;

  Location({required this.lat, required this.lng});

  Location.fromJson(Map<String, dynamic> json) {
    lat = json['lat'];
    lng = json['lng'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['lat'] = this.lat;
    data['lng'] = this.lng;
    return data;
  }
}
