import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/poi.dart';
import 'saved_place.dart';

/// saved_places CRUD를 감싸는 얇은 저장소.
class SavedPlaceRepository {
  final SupabaseClient _client;
  SavedPlaceRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  static const _table = 'saved_places';

  /// Places 연결형 저장. 이미 저장된 곳(unique 위반)이면 멱등 처리한다.
  /// (부분 유니크 인덱스는 upsert onConflict 타깃으로 못 쓰므로 insert + 중복 무시.)
  Future<void> save({
    required String ownerId,
    required Poi poi,
    String? memo,
  }) async {
    try {
      await _client.from(_table).insert(
        savedPlaceInsert(
          ownerId: ownerId,
          placeId: poi.id,
          name: poi.name,
          lat: poi.position.lat,
          lng: poi.position.lng,
          category: poi.category,
          memo: memo,
        ),
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // 이미 저장됨 → 멱등
      rethrow;
    }
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
