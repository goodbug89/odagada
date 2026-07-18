import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/place_category.dart';
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
      bucket: PlaceCategory.restaurant,
      distanceMeters: 320,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InfoCard(
            poi: poi,
            onNavigate: () => tapped = true,
            onSave: () {},
            onClose: () {}),
      ),
    ));

    expect(find.text('맛있는 국밥'), findsOneWidget);
    expect(find.textContaining('320'), findsOneWidget); // 거리 표기
    expect(find.textContaining('맛집'), findsOneWidget); // 카테고리 라벨(버킷)

    await tester.tap(find.text('길찾기'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('저장 버튼 탭 시 onSave 호출, isSaved면 "저장됨" 표시', (tester) async {
    var saved = false;
    final poi = Poi(
      id: '1', name: '국밥집', position: LatLng(37.5, 127.0),
      category: '음식점', distanceMeters: 100,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InfoCard(
          poi: poi, onNavigate: () {},
          isSaved: false, onSave: () => saved = true,
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('저장'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(saved, isTrue);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InfoCard(
          poi: poi, onNavigate: () {},
          isSaved: true, onSave: () {},
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('저장됨'), findsOneWidget);
  });

  testWidgets('카테고리 아이콘과 라벨을 보여준다', (tester) async {
    final poi = Poi(
      id: '1', name: '스타벅스', position: LatLng(37.5, 127.0),
      category: '카페', bucket: PlaceCategory.cafe, distanceMeters: 120,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: InfoCard(poi: poi, onNavigate: () {}, onSave: () {}, onClose: () {}),
      ),
    ));
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    expect(find.textContaining('카페·디저트'), findsOneWidget);
  });

  testWidgets('주소·전화·영업중·닫기 버튼을 표시하고 onClose 콜백', (t) async {
    var closed = false;
    final poi = const Poi(
      id: 'p1', name: '카페A', position: LatLng(37.5, 127.0),
      category: '카페', bucket: PlaceCategory.cafe,
      address: '서울시 어딘가 1', phone: '02-123-4567', openNow: true,
      weekdayHours: ['월요일: 09:00~18:00'], distanceMeters: 50,
    );
    await t.pumpWidget(MaterialApp(home: Scaffold(body: InfoCard(
      poi: poi, onNavigate: () {}, onSave: () {}, onClose: () => closed = true,
    ))));
    expect(find.textContaining('서울시 어딘가 1'), findsOneWidget);
    expect(find.textContaining('02-123-4567'), findsOneWidget);
    expect(find.textContaining('영업 중'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });

  testWidgets('친구 저장 섹션: N명 + 이름별 메모', (t) async {
    final poi = const Poi(
      id: 'p1', name: '금양화로', position: LatLng(37.5, 127.0),
      category: '맛집', bucket: PlaceCategory.restaurant, distanceMeters: 50);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: InfoCard(
      poi: poi, onNavigate: () {}, onSave: () {}, onClose: () {},
      friendNames: const ['철수', '영희'], friendMemos: const ['여기 좋아요', ''],
    ))));
    expect(find.textContaining('친구 2명'), findsOneWidget);
    expect(find.textContaining('철수'), findsOneWidget);
    expect(find.textContaining('여기 좋아요'), findsOneWidget);
    expect(find.text('영희'), findsOneWidget); // 메모 없으면 이름만
  });

  testWidgets('내 저장 + 내 메모 섹션', (t) async {
    final poi = const Poi(
      id: 'p1', name: '금양화로', position: LatLng(37.5, 127.0),
      category: '맛집', bucket: PlaceCategory.restaurant, distanceMeters: 50);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: InfoCard(
      poi: poi, onNavigate: () {}, onSave: () {}, onClose: () {},
      isSaved: true, myMemo: '내가 왔던 곳',
    ))));
    expect(find.textContaining('내가 저장'), findsOneWidget);
    expect(find.textContaining('내가 왔던 곳'), findsOneWidget);
  });
}
