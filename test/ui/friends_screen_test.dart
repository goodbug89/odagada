import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/friends/friend.dart';
import 'package:odagada/friends/friend_repository.dart';
import 'package:odagada/ui/friends_screen.dart';

class _FakeRepo implements FriendRepository {
  final List<Friend> friends;
  InviteInfo infoToReturn;
  _FakeRepo(this.friends,
      {this.infoToReturn = const InviteInfo(inviterName: '영희', valid: true)});
  @override
  Future<({String token, String link})> createInvite() async =>
      (token: 'ABCD2345', link: 'io.supabase.odagada://invite/ABCD2345');
  @override
  Future<InviteInfo> inviteInfo(String token) async => infoToReturn;
  @override
  Future<void> acceptInvite(String token) async {
    friends.add(const Friend(id: 'ux', displayName: '영희'));
  }
  @override
  Future<List<Friend>> listFriends() async => List.of(friends);
  @override
  Future<void> removeFriend(String otherId) async =>
      friends.removeWhere((f) => f.id == otherId);
}

Future<void> _pump(WidgetTester t, FriendRepository repo) => t.pumpWidget(
      MaterialApp(home: FriendsScreen(repo: repo)),
    );

void main() {
  testWidgets('초대 만들기 → 코드 노출', (t) async {
    await _pump(t, _FakeRepo([]));
    await t.pumpAndSettle();
    await t.tap(find.text('초대 링크 만들기'));
    await t.pumpAndSettle();
    expect(find.textContaining('ABCD2345'), findsOneWidget);
  });

  testWidgets('친구 목록 렌더', (t) async {
    await _pump(t, _FakeRepo([const Friend(id: 'u1', displayName: '철수')]));
    await t.pumpAndSettle();
    expect(find.text('철수'), findsOneWidget);
  });

  testWidgets('유효하지 않은 초대 코드 → 토스트', (t) async {
    await _pump(
        t,
        _FakeRepo([],
            infoToReturn: const InviteInfo(inviterName: '', valid: false)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'BADCODE1');
    await t.tap(find.text('추가'));
    await t.pumpAndSettle();
    expect(find.text('유효하지 않은 초대예요.'), findsOneWidget);
  });

  testWidgets('유효한 초대 코드 → 확인 다이얼로그 → 수락 → 목록 갱신', (t) async {
    await _pump(
        t,
        _FakeRepo([],
            infoToReturn: const InviteInfo(inviterName: '영희', valid: true)));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'ABCD2345');
    await t.tap(find.text('추가'));
    await t.pumpAndSettle();
    expect(find.textContaining('영희'), findsWidgets);
    expect(find.text('수락'), findsOneWidget);
    await t.tap(find.text('수락'));
    await t.pumpAndSettle();
    expect(find.text('영희'), findsOneWidget);
  });
}
