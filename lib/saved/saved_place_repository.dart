import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/poi.dart';
import 'saved_place.dart';

/// saved_places CRUD를 감싸는 얇은 저장소.
class SavedPlaceRepository {
  final SupabaseClient _client;
  SavedPlaceRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  static const _table = 'saved_places';

  /// Places 연결형 저장(중복이면 무시). place_id = Poi.id.
  Future<void> save({
    required String ownerId,
    required Poi poi,
    String? memo,
  }) async {
    await _client.from(_table).upsert(
      savedPlaceInsert(
        ownerId: ownerId,
        placeId: poi.id,
        name: poi.name,
        lat: poi.position.lat,
        lng: poi.position.lng,
        category: poi.category,
        memo: memo,
      ),
      onConflict: 'owner_id,place_id',
    );
  }

  Future<void> deleteByPlaceId({
    required String ownerId,
    required String placeId,
  }) async {
    await _client
        .from(_table)
        .delete()
        .eq('owner_id', ownerId)
        .eq('place_id', placeId);
  }

  /// 내 저장 목록(최신순).
  Future<List<SavedPlace>> listMine(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => savedPlaceFromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// 내가 저장한 place_id 집합(핀 '저장됨' 표시용).
  Future<Set<String>> savedPlaceIds(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select('place_id')
        .eq('owner_id', ownerId)
        .not('place_id', 'is', null);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['place_id'] as String)
        .toSet();
  }
}
