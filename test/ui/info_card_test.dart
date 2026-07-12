import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/ui/info_card.dart';

void main() {
  testWidgets('이름·거리·카테고리를 표시하고 길찾기 버튼이 동작한다', (tester) async {
    var tapped = false;
    final poi = Poi(
      id: '1',
      name: '맛있는 국밥',
      position: LatLng(37.5, 127.0),
      category: '음식점 > 한식 > 국밥',
      distanceMeters: 320,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InfoCard(poi: poi, onNavigate: () => tapped = true),
      ),
    ));

    expect(find.text('맛있는 국밥'), findsOneWidget);
    expect(find.textContaining('320'), findsOneWidget); // 거리 표기
    expect(find.textContaining('한식'), findsOneWidget);

    await tester.tap(find.text('길찾기'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
