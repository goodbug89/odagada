import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/lat_lng_bounds.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/poi/poi_provider.dart';
import 'package:odagada/poi/tile_math.dart';
import 'package:odagada/poi/tiled_poi_source.dart';

/// 호출 횟수를 세고, 중심 좌표에 POI 한 개를 놓는 페이크 provider.
class _EchoProvider implements PoiProvider {
  int calls = 0;
  final bool empty;
  _EchoProvider({this.empty = false});
  @override
  String get id => 'echo';
  @override
  String get displayName => 'echo';
  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async {
    calls++;
    if (empty) return [];
    final c = loc.position;
    return [
      Poi(
        id: '${c.lat.toStringAsFixed(4)},${c.lng.toStringAsFixed(4)}',
        name: 'p', position: c, category: 'x', distanceMeters: 0,
      ),
    ];
  }
}

const _z = 14;

// 타일 k 내부로 좁힌 bounds(정확히 1타일).
LatLngBounds _insetOf(TileKey k) {
  final b = tileBounds(k);
  final dLat = b.ne.lat - b.sw.lat, dLng = b.ne.lng - b.sw.lng;
  return LatLngBounds(
    ne: LatLng(b.ne.lat - dLat * 0.25, b.ne.lng - dLng * 0.25),
    sw: LatLng(b.sw.lat + dLat * 0.25, b.sw.lng + dLng * 0.25),
  );
}

void main() {
  test('누락 타일만 검색하고, 같은 뷰포트 재요청은 호출 0', () async {
    final prov = _EchoProvider();
    final reg = ProviderRegistry()..register(prov);
    final src = TiledPoiSource(reg);
    final k = tileKeyOf(37.50, 127.00, _z);
    final bounds = _insetOf(k);

    final first = await src.load(bounds, _z.toDouble());
    expect(prov.calls, 1); // 1타일 × 1provider
    expect(first, isNotEmpty);

    final second = await src.load(bounds, _z.toDouble());
    expect(prov.calls, 1); // 캐시 히트 → 추가 호출 없음
    expect(second.map((p) => p.id).toSet(), first.map((p) => p.id).toSet());
  });

  test('새 구역으로 이동하면 그 타일만 검색해 누적', () async {
    final prov = _EchoProvider();
    final reg = ProviderRegistry()..register(prov);
    final src = TiledPoiSource(reg);
    final k1 = tileKeyOf(37.50, 127.00, _z);
    final k2 = TileKey(_z, k1.x + 3, k1.y); // 멀리 떨어진 다른 타일

    await src.load(_insetOf(k1), _z.toDouble());
    expect(prov.calls, 1);
    final r2 = await src.load(_insetOf(k2), _z.toDouble());
    expect(prov.calls, 2); // 새 타일 1개만 추가 검색
    expect(r2, isNotEmpty);
  });

  test('빈 결과 타일은 재검색하지 않음', () async {
    final prov = _EchoProvider(empty: true);
    final reg = ProviderRegistry()..register(prov);
    final src = TiledPoiSource(reg);
    final bounds = _insetOf(tileKeyOf(37.50, 127.00, _z));
    await src.load(bounds, _z.toDouble());
    await src.load(bounds, _z.toDouble());
    expect(prov.calls, 1); // 두 번째는 캐시된 빈 타일 → 호출 없음
  });

  test('줌이 minBrowseZoom 미만이면 검색 안 함', () async {
    final prov = _EchoProvider();
    final reg = ProviderRegistry()..register(prov);
    final src = TiledPoiSource(reg, minBrowseZoom: 14);
    final bounds = _insetOf(tileKeyOf(37.50, 127.00, 13));
    final r = await src.load(bounds, 13.0);
    expect(prov.calls, 0);
    expect(r, isEmpty);
  });

  test('덮는 타일 수가 maxTiles 초과면 검색 안 함', () async {
    final prov = _EchoProvider();
    final reg = ProviderRegistry()..register(prov);
    final src = TiledPoiSource(reg, maxTiles: 1);
    final k = tileKeyOf(37.50, 127.00, _z);
    final k2 = TileKey(_z, k.x + 1, k.y + 1);
    final c1 = tileCenter(k), c2 = tileCenter(k2);
    final span = LatLngBounds(
      ne: LatLng(c1.lat > c2.lat ? c1.lat : c2.lat, c1.lng > c2.lng ? c1.lng : c2.lng),
      sw: LatLng(c1.lat < c2.lat ? c1.lat : c2.lat, c1.lng < c2.lng ? c1.lng : c2.lng),
    );
    final r = await src.load(span, _z.toDouble()); // 4타일 > maxTiles 1
    expect(prov.calls, 0);
    expect(r, isEmpty);
  });
}
