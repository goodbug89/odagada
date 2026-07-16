import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/friends/friend.dart';

void main() {
  test('friendFromRow 매핑', () {
    final f = friendFromRow({
      'id': 'u1', 'display_name': '철수', 'avatar_url': 'http://x/a.png',
    });
    expect(f.id, 'u1');
    expect(f.displayName, '철수');
    expect(f.avatarUrl, 'http://x/a.png');
  });

  test('friendFromRow: display_name null이면 기본값', () {
    final f = friendFromRow({'id': 'u2', 'display_name': null, 'avatar_url': null});
    expect(f.displayName, '친구');
    expect(f.avatarUrl, isNull);
  });

  test('inviteInfoFromRow 매핑', () {
    final i = inviteInfoFromRow({'inviter_name': '영희', 'valid': true});
    expect(i.inviterName, '영희');
    expect(i.valid, true);
  });

  test('canonicalPair는 작은 값이 먼저', () {
    expect(canonicalPair('b', 'a'), ('a', 'b'));
    expect(canonicalPair('a', 'b'), ('a', 'b'));
  });

  test('generateInviteToken: 길이 8, 허용 문자만', () {
    const allowed = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for (var i = 0; i < 20; i++) {
      final t = generateInviteToken();
      expect(t.length, 8);
      expect(t.split('').every(allowed.contains), isTrue);
    }
  });
}
