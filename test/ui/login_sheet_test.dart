import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/ui/login_sheet.dart';

void main() {
  testWidgets('구글 버튼을 표시하고 탭하면 콜백을 호출한다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LoginSheet(onGoogle: () => tapped = true)),
    ));

    expect(find.textContaining('로그인'), findsWidgets);
    expect(find.text('구글로 계속하기'), findsOneWidget);

    await tester.tap(find.text('구글로 계속하기'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
