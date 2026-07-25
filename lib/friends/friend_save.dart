import '../core/geo/geo_math.dart';
import '../core/models/lat_lng.dart';
import '../core/models/place_category.dart';
import '../core/models/poi.dart';

/// 친구가 저장한 곳(place_id로 집계). 지도 소셜 오버레이용.
class FriendSave {
  final String placeId;
  final double lat;
  final double lng;
  final String name;
  final PlaceCategory bucket;
  final int friendCount;
  final List<String> friendNames;
  final List<String> memos;
  const FriendSave({
    required this.placeId,
    required this.lat,
    required this.lng,
    required this.name,
    required this.bucket,
    required this.friendCount,
    required this.friendNames,
    required this.memos,
  });
}

FriendSave friendSaveFromRow(Map<String, dynamic> row) => FriendSave(
      placeId: row['place_id'] as String,
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
      name: (row['name'] as String?) ?? '이름 없음',
      bucket: PlaceCategory.fromId(row['category'] as String?),
      friendCount: (row['friend_count'] as num?)?.toInt() ?? 0,
      friendNames: ((row['friend_names'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      memos: ((row['memos'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
    );

/// 친구-저장을 지도 핀에 병합할 재료를 만든다.
/// friendCounts: place_id별 친구 수(모든 친구-저장). extraPins: 지도에 아직
/// 없는(검색결과·내저장에 없는) 친구-only 장소를 Poi로 변환한 것.
({List<Poi> extraPins, Map<String, int> friendCounts}) friendOverlay(
    List<FriendSave> friendSaves, Set<String> existingIds, LatLng center) {
  final counts = <String, int>{};
  final extra = <Poi>[];
  for (final fs in friendSaves) {
    counts[fs.placeId] = fs.friendCount;
    if (!existingIds.contains(fs.placeId)) {
      final pos = LatLng(fs.lat, fs.lng);
      extra.add(Poi(
        id: fs.placeId,
        name: fs.name,
        position: pos,
        category: fs.bucket.label,
        bucket: fs.bucket,
        distanceMeters: GeoMath.distanceMeters(center, pos),
      ));
    }
  }
  return (extraPins: extra, friendCounts: counts);
}
