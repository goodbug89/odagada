import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/ui/place_pin.dart';

Poi _poi() => const Poi(
      id: 'p1',
      name: '스타벅스',
      position: LatLng(37.5, 127.0),
      category: '카페',
      bucket: PlaceCategory.cafe,
      distanceMeters: 0,
    );

Future<void> _pump(WidgetTester t, Widget w) => t.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: w))),
    );

void main() {
  testWidgets('CategoryDot: 이름 + 카테고리 아이콘 표시, 탭 콜백', (t) async {
    var tapped = false;
    await _pump(t, CategoryDot(poi: _poi(), onTap: () => tapped = true));
    expect(find.text('스타벅스'), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    await t.tap(find.byType(CategoryDot));
    expect(tapped, isTrue);
  });

  testWidgets('SavedPin: 이름 + 카테고리 아이콘 + 북마크 배지', (t) async {
    await _pump(t, SavedPin(poi: _poi(), onTap: () {}));
    expect(find.text('스타벅스'), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
  });
}
