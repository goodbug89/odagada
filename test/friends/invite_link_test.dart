// test/friends/invite_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/friends/invite_link.dart';

void main() {
  test('buildInviteLink는 https 초대 형식을 만든다', () {
    expect(buildInviteLink('ABCD2345'),
        'https://goodbug89.github.io/invite/?t=ABCD2345');
  });

  test('buildInviteLink → inviteTokenFromUri 왕복', () {
    final uri = Uri.parse(buildInviteLink('WXYZ6789'));
    expect(inviteTokenFromUri(uri), 'WXYZ6789');
  });

  test('https 초대 링크에서 토큰 추출', () {
    expect(
        inviteTokenFromUri(
            Uri.parse('https://goodbug89.github.io/invite/?t=ABCD2345')),
        'ABCD2345');
  });

  test('레거시 커스텀 스킴에서 토큰 추출', () {
    expect(
        inviteTokenFromUri(
            Uri.parse('io.supabase.odagada://invite/ABCD2345')),
        'ABCD2345');
  });

  test('Supabase 로그인 콜백은 초대가 아니다 → null', () {
    expect(
        inviteTokenFromUri(
            Uri.parse('io.supabase.odagada://login-callback/')),
        isNull);
  });

  test('다른 host의 /invite는 null', () {
    expect(
        inviteTokenFromUri(Uri.parse('https://example.com/invite/?t=ABCD2345')),
        isNull);
  });

  test('경로가 다르면 null', () {
    expect(
        inviteTokenFromUri(
            Uri.parse('https://goodbug89.github.io/other/?t=ABCD2345')),
        isNull);
  });

  test('t 파라미터가 없거나 비면 null', () {
    expect(inviteTokenFromUri(Uri.parse('https://goodbug89.github.io/invite/')),
        isNull);
    expect(
        inviteTokenFromUri(
            Uri.parse('https://goodbug89.github.io/invite/?t=')),
        isNull);
  });
}
