import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/ui/memo_sheet.dart';

void main() {
  testWidgets('메모 입력 후 저장 → 입력값 반환', (t) async {
    String? result = 'unset';
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              result = await showMemoSheet(ctx, placeName: '금양화로');
            },
            child: const Text('open'),
          );
        }),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining('금양화로'), findsOneWidget); // 장소명 노출
    await t.enterText(find.byType(TextField), '분위기 좋음');
    await t.tap(find.widgetWithText(FilledButton, '저장'));
    await t.pumpAndSettle();
    expect(result, '분위기 좋음');
  });
}
