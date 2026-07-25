import 'package:flutter/material.dart';

/// 저장 시 뜨는 한줄 메모 입력 시트. "저장"이면 메모(빈 문자열 가능) 반환, 닫으면 null.
Future<String?> showMemoSheet(BuildContext context,
    {required String placeName}) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // 키보드 위로 올라오게
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$placeName 저장',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: '메모 (선택) — 왜 좋았는지 한 줄',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('저장', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      );
    },
  );
  // NOTE: controller는 시트 퇴장 애니메이션 중에도 TextField가 참조하므로 여기서
  // dispose하지 않는다(일회성 함수-로컬이라 GC됨). whenComplete 즉시 해제는 X.
}
