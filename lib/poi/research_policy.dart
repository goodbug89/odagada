// lib/poi/research_policy.dart
import '../core/geo/geo_math.dart';
import '../core/models/lat_lng_bounds.dart';

/// 재검색을 건너뛸 최소 이동 거리(미터).
const double researchMinMoveMeters = 30;

/// 재검색을 건너뛸 최대 줌 변화량.
const double researchMinZoomDelta = 0.1;

/// 카메라가 정지했을 때 뷰포트를 다시 검색해야 하는지 판단하는 순수 정책 함수.
/// 이전 검색이 있고, 중심 이동이 [researchMinMoveMeters] 미만이며,
/// 줌 변화가 [researchMinZoomDelta] 미만이면 재검색을 건너뛴다(false).
/// 그 외에는 항상 재검색한다(true).
bool shouldResearch({
  required LatLngBounds? lastBounds,
  required double? lastZoom,
  required LatLngBounds bounds,
  required double zoom,
}) {
  if (lastBounds == null || lastZoom == null) return true;
  final moved = GeoMath.distanceMeters(lastBounds.center, bounds.center);
  if (moved < researchMinMoveMeters &&
      (zoom - lastZoom).abs() < researchMinZoomDelta) {
    return false;
  }
  return true;
}
