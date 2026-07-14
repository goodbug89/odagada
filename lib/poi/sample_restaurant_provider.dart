import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import '../core/geo/geo_math.dart';
import 'poi_provider.dart';

/// 웹/데모용 맛집 Provider. 실제 API 없이 고정된 서울 도심 샘플을 반환한다.
/// (웹 브라우저에서는 Google Places REST가 CORS로 막혀, 흐름 확인용 샘플을 쓴다.)
class SampleRestaurantProvider implements PoiProvider {
  @override
  String get id => 'restaurant';
  @override
  String get displayName => '맛집(샘플)';

  static const _places = <(String, double, double, String)>[
    ('소문난 손칼국수', 37.5680, 126.9788, '음식점 > 한식 > 칼국수'),
    ('교대 이층집', 37.5652, 126.9805, '음식점 > 한식 > 고기'),
    ('광화문 국밥', 37.5700, 126.9769, '음식점 > 한식 > 국밥'),
    ('북촌 손만두', 37.5691, 126.9752, '음식점 > 분식 > 만두'),
    ('시청앞 파스타', 37.5648, 126.9773, '음식점 > 양식 > 파스타'),
    ('무교동 낙지', 37.5674, 126.9812, '음식점 > 한식 > 해물'),
  ];

  @override
  Future<List<Poi>> nearby(LocationEvent loc,
      {required double radiusMeters}) async {
    return _places.map((p) {
      final pos = LatLng(p.$2, p.$3);
      return Poi(
        id: 'sample-${p.$1.hashCode}',
        name: p.$1,
        position: pos,
        category: p.$4,
        distanceMeters: GeoMath.distanceMeters(loc.position, pos),
      );
    }).toList();
  }
}
