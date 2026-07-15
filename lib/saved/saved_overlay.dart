import '../core/geo/geo_math.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import 'saved_place.dart';

/// 보이는 영역(중심·반경) 안의 내 저장 장소를 지도 핀용 Poi로 변환한다.
/// 뷰포트 검색 결과와 별개로 항상 오버레이되도록 하기 위함.
List<Poi> savedPoisInViewport(
    List<SavedPlace> saved, LatLng center, double radiusMeters) {
  final out = <Poi>[];
  for (final s in saved) {
    final pos = LatLng(s.lat, s.lng);
    final d = GeoMath.distanceMeters(center, pos);
    if (d > radiusMeters) continue;
    out.add(Poi(
      id: s.placeId ?? '${s.lat},${s.lng}',
      name: s.name,
      position: pos,
      category: s.bucket.label,
      bucket: s.bucket,
      distanceMeters: d,
    ));
  }
  return out;
}
