import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/helpers/site_helper.dart';
import 'package:phonetowers/helpers/telco_helper.dart';

// I3: a failed download must be able to forget the areas it had marked as downloaded.
void main() {
  setUp(() => SiteHelper.downloadedGeohashes.clear());

  test('forgetGeohashes un-marks the area for that carrier only', () {
    expect(SiteHelper.downloadedGeohashAlready('r3dp1', Telco.Optus), isFalse);
    expect(SiteHelper.downloadedGeohashAlready('r3dp1', Telco.Telstra), isFalse);
    expect(SiteHelper.downloadedGeohashAlready('r3dp1', Telco.Optus), isTrue);

    SiteHelper.forgetGeohashes(['r3dp1'], Telco.Optus);

    expect(SiteHelper.downloadedGeohashAlready('r3dp1', Telco.Telstra), isTrue);
    expect(SiteHelper.downloadedGeohashAlready('r3dp1', Telco.Optus), isFalse);
  });

  test('forgetting an area that was never marked is harmless', () {
    SiteHelper.forgetGeohashes(['r3dp2', 'r3dp3'], Telco.Optus);
    expect(SiteHelper.downloadedGeohashAlready('r3dp2', Telco.Optus), isFalse);
  });
}
