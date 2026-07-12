import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../location/location_engine.dart';
import '../location/raw_fix.dart';
import '../poi/poi_provider.dart';
import '../recommend/recommend_engine.dart';

/// 한 위치 이벤트에 대한 추천 결과 묶음. 지도는 위치로 카메라를 따라가고
/// recommendations로 핀을 그린다.
class RecommendationUpdate {
  final LocationEvent location;
  final List<Recommendation> recommendations;
  const RecommendationUpdate(this.location, this.recommendations);
}

/// 위치 스트림을 받아 활성 Provider 호출→랭킹까지 배선한다.
class RecommendationPipeline {
  final LocationEngine locationEngine;
  final ProviderRegistry registry;
  final RecommendEngine recommendEngine;
  final double searchRadiusMeters;

  RecommendationPipeline({
    required this.locationEngine,
    required this.registry,
    required this.recommendEngine,
    this.searchRadiusMeters = 2000,
  });

  Stream<RecommendationUpdate> run(Stream<RawFix> fixes) async* {
    await for (final loc in locationEngine.process(fixes)) {
      final candidates = await _gather(loc);
      if (candidates == null) continue; // 전부 실패 → 직전 유지
      final ranked = recommendEngine.rank(loc, candidates);
      yield RecommendationUpdate(loc, ranked);
    }
  }

  /// 활성 Provider들을 병렬 호출. 개별 실패는 null로 표시.
  /// 모든 Provider가 실패하면 null 반환(직전 결과 유지). 하나라도 성공하면
  /// (결과가 비었더라도) 성공한 것들의 합집합 반환.
  Future<List<Poi>?> _gather(LocationEvent loc) async {
    final results = await Future.wait(registry.all.map((p) async {
      try {
        return await p.nearby(loc, radiusMeters: searchRadiusMeters);
      } catch (_) {
        return null; // 이 Provider는 실패
      }
    }));
    if (results.isEmpty || results.every((r) => r == null)) return null;
    return results.whereType<List<Poi>>().expand((e) => e).toList();
  }
}
