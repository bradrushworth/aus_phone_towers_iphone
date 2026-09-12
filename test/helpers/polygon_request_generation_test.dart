import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/polygon_request_generation.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';
import 'package:phonetowers/model/site.dart';
import 'package:phonetowers/restful/get_licenceHRP.dart';

void main() {
  test('invalidating a generation cancels every site request', () {
    final PolygonRequestGeneration requests = PolygonRequestGeneration();
    final int originalGeneration = requests.current;
    final first = requests.createToken();
    final second = requests.createToken();

    requests.invalidate('Follow GPS changed');

    expect(first.isCancelled, isTrue);
    expect(second.isCancelled, isTrue);
    expect(requests.isCurrent(originalGeneration), isFalse);
    expect(requests.activeCount, 0);
  });

  test('finishing a stale request cannot remove a new-generation request', () {
    final PolygonRequestGeneration requests = PolygonRequestGeneration();
    final stale = requests.createToken();
    requests.invalidate('refresh');
    final current = requests.createToken();

    requests.complete(stale);

    expect(requests.activeCount, 1);
    expect(current.isCancelled, isFalse);
  });

  test('a stale site completion cannot unlock a current site request', () {
    final Site site = Site(
      telco: Telco.Telstra,
      cityDensity: CityDensity.URBAN,
    );
    final Object stale = Object();
    final Object current = Object();
    SiteHelper.siteDownloadSinceLastClick.clear();
    SiteHelper.startSiteDownload(site, stale);

    // A refresh clears the old generation and immediately starts the replacement.
    SiteHelper.siteDownloadSinceLastClick.clear();
    SiteHelper.startSiteDownload(site, current);
    SiteHelper.finishSiteDownload(site, stale);

    expect(SiteHelper.isSiteDownloadInFlight(site), isTrue);
    SiteHelper.finishSiteDownload(site, current);
    expect(SiteHelper.isSiteDownloadInFlight(site), isFalse);
  });
}
