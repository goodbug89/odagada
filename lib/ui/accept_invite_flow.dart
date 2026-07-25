import 'package:flutter/material.dart';
import '../friends/friend.dart';
import '../friends/friend_repository.dart';
import 'toast.dart';

/// 초대 토큰을 확인하고 사용자가 승인하면 수락한다. 수락되면 true.
/// 코드 입력(FriendsScreen)과 딥링크 수신(MapScreen)이 같은 UX를 쓰도록 공유한다.
Future<bool> runAcceptInviteFlow(
    BuildContext context, FriendRepository repo, String token) async {
  void toast(String msg) => showToast(context, msg);

  final InviteInfo info;
  try {
    info = await repo.inviteInfo(token);
  } catch (_) {
    toast('초대 확인에 실패했어요.');
    return false;
  }
  if (!info.valid) {
    toast('유효하지 않은 초대예요.');
    return false;
  }
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text('${info.inviterName}님과 친구를 맺을까요?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('수락')),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await repo.acceptInvite(token);
  } catch (_) {
    toast('이미 친구이거나 만료된 초대예요.');
    return false;
  }
  toast('친구가 됐어요!');
  return true;
}
