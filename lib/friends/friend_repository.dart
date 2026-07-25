import 'package:supabase_flutter/supabase_flutter.dart';
import 'friend.dart';
import 'invite_link.dart';

/// 친구 그래프 저장소 인터페이스(화면은 이걸 의존 → 가짜로 위젯테스트 가능).
abstract class FriendRepository {
  Future<({String token, String link})> createInvite();
  Future<InviteInfo> inviteInfo(String token);
  Future<void> acceptInvite(String token);
  Future<List<Friend>> listFriends();
  Future<void> removeFriend(String otherId);
}

/// Supabase 구현. 수락·목록은 SECURITY DEFINER 함수로.
class SupabaseFriendRepository implements FriendRepository {
  final SupabaseClient _client;
  SupabaseFriendRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<({String token, String link})> createInvite() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    final token = generateInviteToken();
    await _client.from('invites').insert({'token': token, 'inviter_id': uid});
    return (token: token, link: buildInviteLink(token));
  }

  @override
  Future<InviteInfo> inviteInfo(String token) async {
    final rows =
        await _client.rpc('get_invite_info', params: {'p_token': token}) as List;
    if (rows.isEmpty) {
      return const InviteInfo(inviterName: '', valid: false);
    }
    return inviteInfoFromRow(rows.first as Map<String, dynamic>);
  }

  @override
  Future<void> acceptInvite(String token) async {
    await _client.rpc('accept_invite', params: {'p_token': token});
  }

  @override
  Future<List<Friend>> listFriends() async {
    final rows = await _client.rpc('list_my_friends') as List;
    return rows
        .map((r) => friendFromRow(r as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> removeFriend(String otherId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('로그인이 필요합니다.');
    final (a, b) = canonicalPair(uid, otherId);
    await _client.from('friendships').delete().eq('user_a', a).eq('user_b', b);
  }
}
