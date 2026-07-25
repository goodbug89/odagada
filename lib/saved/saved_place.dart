import '../core/models/place_category.dart';

/// 저장된 장소(내 저장). Supabase saved_places 행과 1:1.
class SavedPlace {
  final String id;
  final String? placeId; // Google place id (연결형). null이면 직접추가형.
  final String name;
  final double lat;
  final double lng;
  final String? category;
  final String? memo;

  const SavedPlace({
    required this.id,
    this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    this.category,
    this.memo,
  });

  PlaceCategory get bucket => PlaceCategory.fromId(category);
}

double _toDouble(Object? v) => (v as num).toDouble();

/// Supabase row(map) → SavedPlace.
SavedPlace savedPlaceFromRow(Map<String, dynamic> row) {
  return SavedPlace(
    id: row['id'] as String,
    placeId: row['place_id'] as String?,
    name: row['name'] as String,
    lat: _toDouble(row['lat']),
    lng: _toDouble(row['lng']),
    category: row['category'] as String?,
    memo: row['memo'] as String?,
  );
}

/// insert용 map. is_public은 생략 → DB 기본값(true).
Map<String, dynamic> savedPlaceInsert({
  required String ownerId,
  required String? placeId,
  required String name,
  required double lat,
  required double lng,
  String? category,
  String? memo,
}) {
  return {
    'owner_id': ownerId,
    'place_id': placeId,
    'name': name,
    'lat': lat,
    'lng': lng,
    'category': category,
    'memo': memo,
  };
}
