import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/ui/category_filter_sheet.dart';

Future<void> _pump(WidgetTester t, Widget w) =>
    t.pumpWidget(MaterialApp(home: Scaffold(body: w)));

void main() {
  testWidgets('현재 선택 반영 + 토글 후 적용하면 결과 반환', (t) async {
    Set<PlaceCategory>? applied;
    await _pump(
      t,
      CategoryFilterSheet(
        initial: {PlaceCategory.restaurant, PlaceCategory.cafe},
        onApply: (s) => applied = s,
      ),
    );
    await t.tap(find.text('술집·바')); // 술집 켜기
    await t.pumpAndSettle();
    await t.tap(find.text('적용'));
    expect(applied,
        {PlaceCategory.restaurant, PlaceCategory.cafe, PlaceCategory.bar});
  });

  testWidgets('전체 토글이 모두 선택', (t) async {
    Set<PlaceCategory>? applied;
    await _pump(
      t,
      CategoryFilterSheet(
        initial: {PlaceCategory.restaurant},
        onApply: (s) => applied = s,
      ),
    );
    await t.tap(find.text('전체'));
    await t.pumpAndSettle();
    await t.tap(find.text('적용'));
    expect(applied, PlaceCategory.values.toSet());
  });
}
