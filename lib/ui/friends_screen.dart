import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../friends/friend.dart';
import '../friends/friend_repository.dart';
import 'accept_invite_flow.dart';

/// 친구 초대·추가·목록 화면. (계정 메뉴로만 진입 → 로그인 상태 가정, uid는 repo가 처리)
class FriendsScreen extends StatefulWidget {
  final FriendRepository repo;
  const FriendsScreen({super.key, required this.repo});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _codeCtrl = TextEditingController();
  List<Friend> _friends = const [];
  String? _createdLink;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final f = await widget.repo.listFriends();
      if (mounted) setState(() => _friends = f);
    } catch (_) {
      // 목록 실패는 조용히(빈 상태)
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _createInvite() async {
    try {
      final inv = await widget.repo.createInvite();
      if (!mounted) return;
      setState(() => _createdLink = inv.link);
    } catch (_) {
      _toast('초대 링크 생성에 실패했어요.');
    }
  }

  Future<void> _addByCode() async {
    final token = _codeCtrl.text.trim();
    if (token.isEmpty) return;
    final ok = await runAcceptInviteFlow(context, widget.repo, token);
    if (!ok || !mounted) return;
    _codeCtrl.clear();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 초대
          Text('친구 초대',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _createInvite,
            icon: const Icon(Icons.link),
            label: const Text('초대 링크 만들기'),
          ),
          if (_createdLink != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: SelectableText(_createdLink!,
                    style: const TextStyle(fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: '복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _createdLink!));
                  _toast('복사됐어요. 친구에게 보내세요.');
                },
              ),
            ]),
          ],
          const Divider(height: 32),
          // 추가
          Text('친구 추가',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _codeCtrl,
                decoration: const InputDecoration(
                  hintText: '초대 코드 입력',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _addByCode, child: const Text('추가')),
          ]),
          const Divider(height: 32),
          // 목록
          Text('내 친구',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator()))
          else if (_friends.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('아직 친구가 없어요. 초대 링크를 보내보세요.'),
            )
          else
            ..._friends.map((f) => ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        f.avatarUrl != null ? NetworkImage(f.avatarUrl!) : null,
                    child: f.avatarUrl == null
                        ? Text(f.displayName.characters.first)
                        : null,
                  ),
                  title: Text(f.displayName),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () async {
                      await widget.repo.removeFriend(f.id);
                      if (!mounted) return;
                      await _reload();
                    },
                  ),
                )),
        ],
      ),
    );
  }
}
