import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import 'kakao_client.dart';
import 'poi_provider.dart';

export 'kakao_client.dart' show KakaoApiException;

/// 카카오 로컬 API(음식점 카테고리 FD6) 기반 맛집 Provider.
class RestaurantProvider implements PoiProvider {
  final KakaoClient client;
  RestaurantProvider({required this.client});

  @override
  String get id => 'restaurant';
  @override
  String get displayName => '맛집';

  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async {
    final docs = await client.searchCategory(
      categoryCode: 'FD6',
      lat: loc.position.lat,
      lng: loc.position.lng,
      radiusMeters: radiusMeters.round(),
    );
    return docs.map(_toPoi).toList();
  }

  Poi _toPoi(Map<String, dynamic> d) {
    return Poi(
      id: d['id'] as String,
      name: d['place_name'] as String,
      position: LatLng(
        double.parse(d['y'] as String),
        double.parse(d['x'] as String),
      ),
      category: (d['category_name'] as String?) ?? '음식점',
      address: d['road_address_name'] as String?,
      phone: d['phone'] as String?,
      placeUrl: d['place_url'] as String?,
      distanceMeters: double.parse((d['distance'] as String?) ?? '0'),
      rating: 0, // 카카오 로컬 API는 평점 미제공
    );
  }
}
