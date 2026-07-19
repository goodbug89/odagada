import '../core/geo/geo_math.dart';
import '../core/models/lat_lng.dart';
import '../core/models/lat_lng_bounds.dart';
import '../core/models/poi.dart';
import 'tile_math.dart';

/// 타일별 검색 결과를 담는 세션 메모리 캐시.
/// 키가 존재하면(빈 리스트 포함) 그 타일은 검색 완료된 것으로 본다.
class TileCache {
  final int maxTiles;
  final Map<TileKey, List<Poi>> _tiles = {};
  TileCache({this.maxTiles = 80});

  bool contains(TileKey key) => _tiles.containsKey(key);
  int get length => _tiles.length;

  /// covering 중 아직 검색 안 된 타일만.
  List<TileKey> missingTiles(List<TileKey> covering) =>
      covering.where((k) => !_tiles.containsKey(k)).toList();

  /// 타일 결과 저장(0개여도 저장 → 빈 타일 재검색 방지).
  void ingest(TileKey key, List<Poi> pois) => _tiles[key] = pois;

  /// 캐시된 모든 타일의 POI 중 bounds 안에 드는 것을 id로 dedupe해 반환.
  List<Poi> poisIn(LatLngBounds bounds) {
    final byId = <String, Poi>{};
    for (final list in _tiles.values) {
      for (final p in list) {
        final la = p.position.lat, lo = p.position.lng;
        if (la < bounds.sw.lat || la > bounds.ne.lat) continue;
        if (lo < bounds.sw.lng || lo > bounds.ne.lng) continue;
        byId[p.id] = p;
      }
    }
    return byId.values.toList();
  }

  /// 상한 초과 시 center에서 먼 타일부터 제거.
  void evict(LatLng center) {
    if (_tiles.length <= maxTiles) return;
    final keys = _tiles.keys.toList()
      ..sort((a, b) => GeoMath.distanceMeters(center, tileCenter(a))
          .compareTo(GeoMath.distanceMeters(center, tileCenter(b))));
    for (final k in keys.skip(maxTiles).toList()) {
      _tiles.remove(k);
    }
  }
}
