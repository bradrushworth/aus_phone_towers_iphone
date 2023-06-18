import 'package:logger/logger.dart';
import 'package:phonetowers/model/antenna.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';

class GetAntenna {
  String url;
  DeviceDetails deviceDetails;
  static Map<int, Antenna> antennaCache = Map<int, Antenna>();
  Logger logger = new Logger();
  Api api = Api.initialize();

  GetAntenna({required this.url, required this.deviceDetails});

  Future getAntennaData() async {
    deviceDetails.antenna = Antenna();
    antennaCache[deviceDetails.antennaId!] = deviceDetails.antenna!;

    if (deviceDetails.antennaId == 0) {
      // logger.w(
      //     "GetAntenna", "The antennaId must be set to retrieve the record!");
      return;
    }

    // logger.d(
    //     'GetAntenna - GetAntenna(): u=$url antennaId=${deviceDetails.antennaId}');
    SiteResponse? rawResponse = await api.getAntennaDataApi(url);

    int totalLatLong = rawResponse?.restify?.rows?.length ?? 0;

    //If no data found for this telco then don't do anything
    if (totalLatLong == 0) {
      return;
    }

    //Fetch first row.
    Values? values = rawResponse!.restify!.rows![0].values;

    deviceDetails.antenna!.gain = double.tryParse(values!.gain!.value) ?? 0;
    deviceDetails.antenna!.frontToBack =
        double.tryParse(values!.frontToBack!.value) ?? 0;
    deviceDetails.antenna!.horizontalBeamwidth =
        double.tryParse(values.hBeamwidth!.value) ?? 0;

    // logger.d('GetAntenna processJSON(): antennaId=${deviceDetails.antennaId}'
    //     ' gain= ${deviceDetails.antenna.gain} '
    //     'frontToBack=${deviceDetails.antenna.frontToBack} '
    //     'horizontalBeamwidth= ${deviceDetails.antenna.horizontalBeamwidth}');
  }
}
