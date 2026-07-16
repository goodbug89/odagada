import 'dart:math';

/// 친구(상대방 프로필).
class Friend {
  final String id;
  final String displayName;
  final String? avatarUrl;
  const Friend({required this.id, required this.displayName, this.avatarUrl});
}

/// 수락 전 확인용 초대 정보.
class InviteInfo {
  final String inviterName;
  final bool valid;
  const InviteInfo({required this.inviterName, required this.valid});
}

Friend friendFromRow(Map<String, dynamic> row) {
  final name = row['display_name'] as String?;
  return Friend(
    // null뿐 아니라 빈 문자열도 기본값으로(아바타 이니셜 .characters.first 크래시 방지).
    id: row['id'] as String,
    displayName: (name == null || name.isEmpty) ? '친구' : name,
    avatarUrl: row['avatar_url'] as String?,
  );
}

InviteInfo inviteInfoFromRow(Map<String, dynamic> row) => InviteInfo(
      inviterName: (row['inviter_name'] as String?) ?? '친구',
      valid: (row['valid'] as bool?) ?? false,
    );

/// 정규화된 친구 쌍(작은 id가 user_a). friendships PK check(user_a<user_b)와 일치.
(String, String) canonicalPair(String a, String b) =>
    a.compareTo(b) < 0 ? (a, b) : (b, a);

const _tokenAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 헷갈리는 0/O/1/I 제외
final _rng = Random.secure();

/// 8자 랜덤 초대 토큰.
String generateInviteToken() =>
    List.generate(8, (_) => _tokenAlphabet[_rng.nextInt(_tokenAlphabet.length)])
        .join();
