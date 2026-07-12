import 'lat_lng.dart';

/// 모든 Provider가 공통으로 반환하는 관심지점.
class Poi {
  final String id;
  final String name;
  final LatLng position;
  final String category;
  final String? address;
  final String? phone;
  final String? placeUrl;
  final double distanceMeters; // 조회 기준점으로부터 거리
  final double rating;         // 평점 없으면 0

  const Poi({
    required this.id,
    required this.name,
    required this.position,
    required this.category,
    this.address,
    this.phone,
    this.placeUrl,
    required this.distanceMeters,
    this.rating = 0,
  });
}
