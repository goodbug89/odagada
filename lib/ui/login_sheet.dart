import 'package:flutter/material.dart';

/// 로그인 유도 바텀시트 내용. 이번 계획은 구글만.
class LoginSheet extends StatelessWidget {
  final VoidCallback onGoogle;
  const LoginSheet({super.key, required this.onGoogle});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('오다가다 로그인',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('저장·친구 기능을 쓰려면 로그인하세요.',
                style: TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: onGoogle,
                icon: const Icon(Icons.login),
                label: const Text('구글로 계속하기',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인 시트를 바텀시트로 띄운다.
Future<void> showLoginSheet(BuildContext context,
    {required VoidCallback onGoogle}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => LoginSheet(onGoogle: onGoogle),
  );
}
