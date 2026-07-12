import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../location/location_engine.dart';
import '../location/raw_fix.dart';
import '../poi/poi_provider.dart';
import '../recommend/recommend_engine.dart';

/// 위치 스트림을 받아 활성 Provider 호출→랭킹→중복억제까지 배선한다.
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

  Stream<List<Recommendation>> run(Stream<RawFix> fixes) async* {
    await for (final loc in locationEngine.process(fixes)) {
      final candidates = await _gather(loc);
      if (candidates == null) continue; // 모든 Provider 실패 → 방출 안 함
      final ranked = recommendEngine.rank(loc, candidates);
      recommendEngine.markShown(ranked.map((r) => r.poi.id));
      yield ranked;
    }
  }

  /// 활성 Provider들을 병렬 호출해 합친 후보를 반환한다. 후보가 하나도 없으면(레지스트리가
  /// 비었거나, 모든 Provider가 예외를 던졌거나, 모든 Provider가 빈 결과를 반환한 경우를
  /// 구분하지 않고 모두) null을 반환한다.
  Future<List<Poi>?> _gather(LocationEvent loc) async {
    final futures = registry.all.map((p) async {
      try {
        return await p.nearby(loc, radiusMeters: searchRadiusMeters);
      } catch (_) {
        return <Poi>[]; // 개별 Provider 실패는 빈 결과로
      }
    });
    final results = await Future.wait(futures);
    final merged = results.expand((e) => e).toList();
    if (merged.isEmpty) return null;
    return merged;
  }
}
