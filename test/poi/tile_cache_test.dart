// test/poi/tile_cache_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/lat_lng_bounds.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/poi/tile_cache.dart';
import 'package:odagada/poi/tile_math.dart';

Poi _poi(String id, double lat, double lng) => Poi(
      id: id, name: id, position: LatLng(lat, lng),
      category: 'x', distanceMeters: 0,
    );

void main() {
  test('missingTiles는 캐시 안 된 타일만 반환', () {
    final c = TileCache();
    const a = TileKey(14, 1, 1), b = TileKey(14, 1, 2), d = TileKey(14, 1, 3);
    c.ingest(a, []);
    expect(c.missingTiles([a, b, d]), [b, d]);
  });

  test('ingest 후 contains true, 빈 결과도 캐시(재검색 방지)', () {
    final c = TileCache();
    const a = TileKey(14, 5, 5);
    expect(c.contains(a), isFalse);
    c.ingest(a, []);
    expect(c.contains(a), isTrue);
    expect(c.missingTiles([a]), isEmpty);
  });

  test('poisIn은 bounds 안 POI만 반환하고 id로 dedupe', () {
    final c = TileCache();
    c.ingest(const TileKey(14, 1, 1), [_poi('a', 37.50, 127.00)]);
    // 두 타일에 같은 id 'a'가 겹쳐도 한 번만
    c.ingest(const TileKey(14, 1, 2), [
      _poi('a', 37.50, 127.00),
      _poi('b', 37.90, 127.00), // bounds 밖(위도 큼)
    ]);
    const bounds = LatLngBounds(ne: LatLng(37.6, 127.1), sw: LatLng(37.4, 126.9));
    final ids = c.poisIn(bounds).map((p) => p.id).toList();
    expect(ids, ['a']);
  });

  test('evict는 maxTiles 초과 시 center에서 먼 타일 제거', () {
    final c = TileCache(maxTiles: 2);
    final near1 = tileKeyOf(37.50, 127.00, 14);
    final near2 = tileKeyOf(37.60, 127.00, 14); // ~11km 떨어져 확실히 다른 z14 타일
    final far = tileKeyOf(39.00, 129.00, 14);
    c.ingest(near1, []);
    c.ingest(near2, []);
    c.ingest(far, []);
    expect(c.length, 3);
    c.evict(const LatLng(37.50, 127.00));
    expect(c.length, 2);
    expect(c.contains(far), isFalse);
    expect(c.contains(near1), isTrue);
  });
}
