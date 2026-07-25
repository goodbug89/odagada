import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/friends/friend.dart';
import 'package:odagada/friends/friend_repository.dart';
import 'package:odagada/ui/accept_invite_flow.dart';

class _FakeRepo implements FriendRepository {
  final InviteInfo info;
  int acceptCalls = 0;
  _FakeRepo({this.info = const InviteInfo(inviterName: '영희', valid: true)});
  @override
  Future<({String token, String link})> createInvite() async =>
      (token: 'T', link: 'L');
  @override
  Future<InviteInfo> inviteInfo(String token) async => info;
  @override
  Future<void> acceptInvite(String token) async => acceptCalls++;
  @override
  Future<List<Friend>> listFriends() async => const [];
  @override
  Future<void> removeFriend(String otherId) async {}
}

/// 버튼을 눌러 플로우를 실행하고 결과를 담아둔다.
Future<void> _pumpRunner(
    WidgetTester t, FriendRepository repo, List<bool> out) async {
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => ElevatedButton(
          onPressed: () async {
            out.add(await runAcceptInviteFlow(ctx, repo, 'ABCD2345'));
          },
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('유효한 초대 → 확인 다이얼로그 → 수락 시 acceptInvite 호출·true', (t) async {
    final repo = _FakeRepo();
    final out = <bool>[];
    await _pumpRunner(t, repo, out);
    expect(find.textContaining('영희'), findsOneWidget); // 확인 다이얼로그
    await t.tap(find.text('수락'));
    await t.pumpAndSettle();
    expect(repo.acceptCalls, 1);
    expect(out.single, isTrue);
  });

  testWidgets('취소하면 수락하지 않고 false', (t) async {
    final repo = _FakeRepo();
    final out = <bool>[];
    await _pumpRunner(t, repo, out);
    await t.tap(find.text('취소'));
    await t.pumpAndSettle();
    expect(repo.acceptCalls, 0);
    expect(out.single, isFalse);
  });

  testWidgets('무효한 초대 → 다이얼로그 없이 false + 안내', (t) async {
    final repo = _FakeRepo(info: const InviteInfo(inviterName: '', valid: false));
    final out = <bool>[];
    await _pumpRunner(t, repo, out);
    expect(find.text('수락'), findsNothing);
    expect(repo.acceptCalls, 0);
    expect(out.single, isFalse);
    expect(find.text('유효하지 않은 초대예요.'), findsOneWidget);
  });
}
