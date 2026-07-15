import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/poi/poi_provider.dart';
import 'package:odagada/poi/viewport_searcher.dart';

Poi _poi(String id, double dist) => Poi(
      id: id, name: id, position: const LatLng(37.5, 127.0),
      category: 'x', distanceMeters: dist,
    );

class _FakeProvider implements PoiProvider {
  final List<Poi> result;
  final bool throwing;
  _FakeProvider(this.result, {this.throwing = false});
  @override
  String get id => 'fake';
  @override
  String get displayName => 'fake';
  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async {
    if (throwing) throw Exception('boom');
    return result;
  }
}

void main() {
  test('여러 Provider 결과를 합치고 id로 dedupe, 거리순 정렬', () async {
    final reg = ProviderRegistry()
      ..register(_FakeProvider([_poi('a', 300), _poi('b', 100)]))
      ..register(_FakeProvider([_poi('b', 100), _poi('c', 200)])); // b 중복
    final pois = await ViewportSearcher(reg).search(const LatLng(37.5, 127.0), 500);
    expect(pois.map((p) => p.id).toList(), ['b', 'c', 'a']); // 100,200,300
  });

  test('cap으로 개수 제한(거리순 앞에서)', () async {
    final reg = ProviderRegistry()
      ..register(_FakeProvider([_poi('a', 10), _poi('b', 20), _poi('c', 30)]));
    final pois = await ViewportSearcher(reg, cap: 2).search(const LatLng(37.5, 127.0), 500);
    expect(pois.map((p) => p.id).toList(), ['a', 'b']);
  });

  test('한 Provider가 실패해도 나머지 결과는 반환', () async {
    final reg = ProviderRegistry()
      ..register(_FakeProvider([], throwing: true))
      ..register(_FakeProvider([_poi('a', 10)]));
    final pois = await ViewportSearcher(reg).search(const LatLng(37.5, 127.0), 500);
    expect(pois.map((p) => p.id).toList(), ['a']);
  });
}
