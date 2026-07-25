import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/lat_lng.dart';
import 'friend_save.dart';

/// 소셜(친구 저장) 조회 저장소 인터페이스.
abstract class SocialRepository {
  Future<List<FriendSave>> friendSavesNear(LatLng center, double radiusMeters);
}

class SupabaseSocialRepository implements SocialRepository {
  final SupabaseClient _client;
  SupabaseSocialRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<FriendSave>> friendSavesNear(
      LatLng center, double radiusMeters) async {
    final rows = await _client.rpc('friend_saves_near', params: {
      'p_lat': center.lat,
      'p_lng': center.lng,
      'p_radius': radiusMeters,
    }) as List;
    return rows
        .map((r) => friendSaveFromRow(r as Map<String, dynamic>))
        .toList();
  }
}
