import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../core/geo/geo_math.dart';

/// 후보 POI를 진행방향·거리·평점으로 랭킹하고, 이미 본 곳을 억제하는 순수 엔진.
class RecommendEngine {
  final double forwardHalfAngleDeg;
  final double maxDistanceMeters;
  final int maxResults;
  final Set<String> _shown = {};

  RecommendEngine({
    this.forwardHalfAngleDeg = 60,
    this.maxDistanceMeters = 3000,
    this.maxResults = 10,
  });

  void markShown(Iterable<String> ids) => _shown.addAll(ids);
  void reset() => _shown.clear();

  List<Recommendation> rank(LocationEvent loc, List<Poi> candidates) {
    final scored = <Recommendation>[];
    for (final p in candidates) {
      if (_shown.contains(p.id)) continue;
      if (p.distanceMeters > maxDistanceMeters) continue;
      scored.add(Recommendation(poi: p, score: _score(loc, p)));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).toList();
  }

  double _score(LocationEvent loc, Poi p) {
    // 거리 가점: 가까울수록 1에 가깝게(0~1).
    final distScore = 1.0 - (p.distanceMeters / maxDistanceMeters).clamp(0.0, 1.0);

    // 전방 가점: heading 유효 시, 전방 부채꼴 안이면 1, 밖이면 각도차 비례 감점.
    double forwardScore = 0.5; // heading 미상일 때 중립값
    if (loc.headingDeg >= 0) {
      final bearing = GeoMath.bearingDeg(loc.position, p.position);
      final diff = GeoMath.angularDifferenceDeg(loc.headingDeg, bearing);
      if (diff <= forwardHalfAngleDeg) {
        forwardScore = 1.0;
      } else {
        forwardScore = (1.0 - (diff - forwardHalfAngleDeg) / (180 - forwardHalfAngleDeg))
            .clamp(0.0, 1.0);
      }
    }

    // 평점 가점(0~5 → 0~1). 데이터 없으면 0.
    final ratingScore = (p.rating / 5.0).clamp(0.0, 1.0);

    // 가중합: 전방 0.5, 거리 0.35, 평점 0.15.
    return forwardScore * 0.5 + distScore * 0.35 + ratingScore * 0.15;
  }
}
