import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:logger/logger.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/device_detail.dart';
import 'package:phonetowers/model/overlay.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/networking/api.dart';
import 'package:phonetowers/networking/response/site_response.dart';

import '../helpers/network_type_helper.dart';
import '../restful/get_antenna.dart';

typedef void TowerInfoChanged({String message});
typedef void ShowSnackBar({String message});

class GetDevices {
  String url;
  Telco telco;
  List<MapOverlay> listOfTowersForSingleTelco = [];
  Logger logger = new Logger();
  Api api = Api.initialize();
  Set<Site> siteSeen = Set<Site>();
  Set<DeviceDetails> devicesSeen = Set<DeviceDetails>();
  final ShowSnackBar showSnackBar;
  final TowerInfoChanged onTowerInfoChanged;

  GetDevices(
      {required this.url,
      required this.telco,
      required this.listOfTowersForSingleTelco,
      required this.showSnackBar,
      required this.onTowerInfoChanged});

  Future getDevicesData() async {
    //logger.d('get device url $url');

    //showSnackBar(message: "Downloading tower frequencies...");

    SiteResponse? rawReponse = await api.getDevicesData(url);

    int totalLatLong = rawReponse?.restify?.rows?.length ?? 0;

    //If no data found for this telco then don't do anything
    if (totalLatLong == 0) {
      return;
    }

    for (int i = 0; i <= totalLatLong - 1; i++) {
      //Get the row
      Values? values = rawReponse!.restify!.rows![i].values;

      String siteId = values!.siteId!.value;
      String emission = values.emission!.value;
      String polarisation = values.polarisation!.value;
      String callSign = values.callSign != null ? values.callSign!.value : '';
      String active = values.active != null ? values.active!.value : '';
      int frequency = values.frequency != null ? int.tryParse(values.frequency!.value) ?? 0 : 0;
      int bandwidth = values.bandwidth != null ? int.tryParse(values.bandwidth!.value) ?? 0 : 0;
      int height = values.height != null ? int.tryParse(values.height!.value) ?? 0 : 0;
      int azimuth = values.azimuth != null ? int.tryParse(values.azimuth!.value) ?? 0 : 0;
      double eirp = values.eirp != null ? double.tryParse(values.eirp!.value) ?? 0.0 : 0.0;
      int antennaId = values.antennaId != null ? int.tryParse(values.antennaId!.value) ?? 0 : 0;

      for (NetworkType networkType
          in DeviceDetails.getNetworkTypeStatic(emission, frequency, bandwidth, telco, antennaId)) {
        //Prepare device details
        DeviceDetails device = DeviceDetails(
          sddId: values.sddId!.value,
          deviceRegistrationIdentifier: values.deviceRegistrationIdentifier!.value,
          siteId: siteId,
          emission: emission,
          polarisation: polarisation,
          callSign: callSign,
          active: active,
          frequency: frequency,
          bandwidth: bandwidth,
          networkType: networkType,
          height: height,
          azimuth: azimuth,
          eirp: eirp,
          antennaId: antennaId,
        );

        //TODO Prepare license and client

        Site? site = getSite(siteId, telco);
        if (site != null) {
          device.setSite(site);
          site.getDeviceDetailsMobile().add(device);
          site.appendActive(device.isActive());
          siteSeen.add(site);
          devicesSeen.add(device);
        }
      }
    }

//    logger.d('siteSeen length is ${siteSeen.length}');

    // If the frequency etc should be filtered out, hide it now
    for (Site site in siteSeen) {
      for (int i = 0; i < SiteHelper.globalListMapOverlay.length; i++) {
        if (SiteHelper.globalListMapOverlay[i].site != null) {
          if (SiteHelper.globalListMapOverlay[i].site!.siteId == site.siteId &&
              SiteHelper.globalListMapOverlay[i].site!.getTelco() == telco) {
            final Marker? marker = SiteHelper.globalListMapOverlay[i].marker;

            SiteHelper.globalListMapOverlay[i].marker = marker!.copyWith(
              visibleParam: site.shouldBeVisible(),
            );

            if (!site.active) {
              SiteHelper.globalListMapOverlay[i].marker = marker.copyWith(
                alphaParam: marker.alpha / 2,
              );
            }

            break;
          }
        }
      }
    }
    //Refresh main UI
    onTowerInfoChanged(message: "Refresh main UI after get devices");

    NextPage? nextPage = rawReponse!.restify!.nextPage;
    if (nextPage != null) {
      //logger.d("next page exist for telco ${telco} and url $url");
      GetDevices(
              url: nextPage.href,
              telco: telco,
              listOfTowersForSingleTelco: listOfTowersForSingleTelco,
              showSnackBar: this.showSnackBar,
              onTowerInfoChanged: this.onTowerInfoChanged)
          .getDevicesData();
    } else {
      // Get the details on each of the antennas
      for (DeviceDetails device in devicesSeen) {
        // Don't get the antenna more than once
        if (GetAntenna.antennaCache.containsKey(device.antennaId)) {
          device.antenna = GetAntenna.antennaCache[device.antennaId];
          // logger.d(
          //     'GetAntenna antennaCache.containsKey(): antennaId= ${device.antennaId}  gain=${device.antenna.gain}  frontToBack=${device.antenna.frontToBack}  horizontalBeamwidth=${device.antenna.horizontalBeamwidth}');
        } else {
          // Reduce bandwidth by only downloading required fields
          String fields = "gain%2Cfront_to_back%2Ch_beamwidth";
          String filter = "antenna_id%3D%3D${device.antennaId}";
          //logger.d('GetAntenna : Getting antennaId=${device.antennaId}');

          String url =
              '/towers/antenna/?_view=json&_expand=no&_count=1&_filter=$filter&_fields=$fields';
          GetAntenna(url: url, deviceDetails: device).getAntennaData();
        }
      }

      // Check to see if any of the downloaded towers are our connected tower
      //if (telco == CellIdentity.getTelcoInUse()) {
      //CustomPhoneStateListener.recordTower(false);//TODO implement this
      //}
    }
  }

  Site? getSite(String siteId, Telco telco) {
    MapOverlay? mapOverlay = listOfTowersForSingleTelco.firstWhere((MapOverlay mo) =>
        mo.site != null && mo.site!.siteId == siteId && mo.site!.getTelco() == telco);
    return mapOverlay.site;
  }

  Marker? getMarker(Site site) {
    MapOverlay? mapOverlay =
        listOfTowersForSingleTelco.firstWhere((MapOverlay mo) => mo.site == site);
    return mapOverlay.marker;
  }
}
