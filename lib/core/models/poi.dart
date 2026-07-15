import 'lat_lng.dart';
import 'place_category.dart';

/// 모든 Provider가 공통으로 반환하는 관심지점.
class Poi {
  final String id;
  final String name;
  final LatLng position;
  final String category;      // Google primaryTypeDisplayName 원문(표시 보조)
  final PlaceCategory bucket; // 7종 분류(색·아이콘)
  final String? address;
  final String? phone;
  final String? placeUrl;
  final bool? openNow;              // 영업중 여부(모르면 null)
  final List<String>? weekdayHours; // 요일별 영업시간 설명(없으면 null)
  final double distanceMeters; // 조회 기준점으로부터 거리
  final double rating;         // 평점 없으면 0

  const Poi({
    required this.id,
    required this.name,
    required this.position,
    required this.category,
    this.bucket = PlaceCategory.other,
    this.address,
    this.phone,
    this.placeUrl,
    this.openNow,
    this.weekdayHours,
    required this.distanceMeters,
    this.rating = 0,
  });
}
