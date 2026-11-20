import 'package:flutter_test/flutter_test.dart';
import 'package:phonetowers/restful/site_terrain_batch.dart';

void main() {
  test('filter text ORs the ids', () {
    expect(SiteTerrainBatchFetcher.buildFilter(<String?>['1000', '10000']),
        'site_id==1000||site_id==10000');
  });

  test('unusable ids are skipped', () {
    expect(SiteTerrainBatchFetcher.buildFilter(<String?>[null, '', '  ', 'a==b', '1||2', '7']),
        'site_id==7');
    expect(SiteTerrainBatchFetcher.buildFilter(<String?>[null, '']), isNull);
  });

  test('a bare zero is zero padded', () {
    expect(SiteTerrainBatchFetcher.buildFilter(<String?>['0', '5']), 'site_id==00||site_id==5');
  });

  test('batches are distinct, usable and at most the size', () {
    final List<String> ids = <String>[for (int i = 1; i <= 120; i++) '$i', '5', 'bad id'];
    final List<List<String>> b = SiteTerrainBatchFetcher.batches(ids, 50);
    expect(b.map((List<String> x) => x.length).toList(), <int>[50, 50, 20]);
    expect(SiteTerrainBatchFetcher.batches(<String?>[], 50), isEmpty);
  });

  test('url encodes the filter and asks only for id and ground', () {
    final String? url = SiteTerrainBatchFetcher.urlFor(<String>['1', '2']);
    expect(
        url,
        '/towers/site_terrain/?_view=json&_expand=no&_count=2'
        '&_filter=site_id%3D%3D1%7C%7Csite_id%3D%3D2&_fields=site_id%2Cground_m');
  });

  test('rows parse to site id and ground, skipping incomplete rows', () {
    final Map<String, int> m = SiteTerrainBatchFetcher.parseRows(<String, dynamic>{
      'restify': <String, dynamic>{
        'rows': <dynamic>[
          <String, dynamic>{
            'values': <String, dynamic>{
              'site_id': <String, dynamic>{'value': '1'},
              'ground_m': <String, dynamic>{'value': '580'},
            }
          },
          <String, dynamic>{
            'values': <String, dynamic>{
              'site_id': <String, dynamic>{'value': '2'},
            }
          },
        ]
      }
    });
    expect(m, <String, int>{'1': 580});
    expect(SiteTerrainBatchFetcher.parseRows(null), isEmpty);
  });
}
