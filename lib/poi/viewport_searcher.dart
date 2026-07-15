import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import 'poi_provider.dart';

/// 지도에 보이는 영역(중심·반경)으로 활성 Provider를 병렬 호출해
/// dedupe·거리순·상한을 적용하는 브라우즈 검색기.
class ViewportSearcher {
  final ProviderRegistry registry;
  final int cap;
  ViewportSearcher(this.registry, {this.cap = 20});

  Future<List<Poi>> search(LatLng center, double radiusMeters) async {
    final loc = LocationEvent(
      position: center,
      headingDeg: -1,
      speedMps: 0,
      timestamp: DateTime.now(),
    );
    final lists = await Future.wait(registry.all.map((p) async {
      try {
        return await p.nearby(loc, radiusMeters: radiusMeters);
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
    return merged.take(cap).toList();
  }
}
