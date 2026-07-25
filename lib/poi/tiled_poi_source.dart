import 'dart:math' as math;
import '../core/models/lat_lng_bounds.dart';
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import 'poi_provider.dart';
import 'tile_cache.dart';
import 'tile_math.dart';

/// 뷰포트를 슬리피 타일로 나눠 타일별로 provider를 호출·캐시하고,
/// 뷰포트에 걸친 타일들의 POI 누적 합집합을 반환한다.
/// ViewportSearcher(중심 가까운 20개)를 대체한다.
class TiledPoiSource {
  final ProviderRegistry registry;
  final TileCache cache;
  final int minBrowseZoom;
  final int maxTiles;
  final int concurrency;
  final int perTileCap;

  TiledPoiSource(
    this.registry, {
    TileCache? cache,
    this.minBrowseZoom = 14,
    this.maxTiles = 12,
    this.concurrency = 4,
    this.perTileCap = 20,
  }) : cache = cache ?? TileCache();

  /// 뷰포트(bounds)와 카메라 줌으로 ambient POI를 로드한다.
  /// 가드(줌 낮음/타일 과다)면 검색 없이 현재 캐시 합집합만 반환.
  Future<List<Poi>> load(LatLngBounds bounds, double cameraZoom) async {
    final z = cameraZoom.round();
    if (z < minBrowseZoom) return cache.poisIn(bounds);
    final covering = tilesCovering(bounds, z);
    if (covering.length > maxTiles) return cache.poisIn(bounds);

    final missing = cache.missingTiles(covering);
    for (var i = 0; i < missing.length; i += concurrency) {
      final chunk =
          missing.sublist(i, math.min(i + concurrency, missing.length));
      await Future.wait(chunk.map(_fetchTile));
    }
    cache.evict(bounds.center);
    return cache.poisIn(bounds);
  }

  Future<void> _fetchTile(TileKey key) async {
    final center = tileCenter(key);
    final radius = tileRadiusMeters(key);
    final loc = LocationEvent(
      position: center,
      headingDeg: -1,
      speedMps: 0,
      timestamp: DateTime.now(),
    );
    final lists = await Future.wait(registry.all.map((p) async {
      try {
        return await p.nearby(loc, radiusMeters: radius);
      } catch (_) {
        return <Poi>[];
      }
    }));
    final byId = <String, Poi>{};
    for (final list in lists) {
      for (final p in list) {
        byId[p.id] = p;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    cache.ingest(key, merged.take(perTileCap).toList());
  }
}
