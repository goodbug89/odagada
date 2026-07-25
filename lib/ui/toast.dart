// lib/ui/toast.dart
import 'package:flutter/material.dart';

/// 화면 하단 스낵바로 짧은 메시지를 보여준다. dispose된 context는 무시.
void showToast(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
