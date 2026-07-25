import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import 'login_sheet.dart';

/// 앱바 계정 버튼. 익명↔로그인 상태를 AuthController로부터 반영.
class AccountButton extends StatelessWidget {
  final AuthController auth;
  final VoidCallback? onFriends;
  const AccountButton({super.key, required this.auth, this.onFriends});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isSignedIn) {
          return IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: '로그인',
            onPressed: () =>
                showLoginSheet(context, onGoogle: auth.signInWithGoogle),
          );
        }
        final name = auth.user?.displayName ?? '사용자';
        return PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle),
          tooltip: name,
          onSelected: (v) {
            if (v == 'signout') auth.signOut();
            if (v == 'friends') onFriends?.call();
          },
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text(name)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'friends', child: Text('친구')),
            const PopupMenuItem(value: 'signout', child: Text('로그아웃')),
          ],
        );
      },
    );
  }
}
