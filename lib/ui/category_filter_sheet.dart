import 'package:flutter/material.dart';
import '../core/models/place_category.dart';

/// 카테고리 필터 바텀시트를 띄우고 선택 결과를 반환한다(취소/닫기면 null).
Future<Set<PlaceCategory>?> showCategoryFilterSheet(
    BuildContext context, Set<PlaceCategory> current) {
  return showModalBottomSheet<Set<PlaceCategory>>(
    context: context,
    isScrollControlled: true, // 내용(7종+전체+적용) 높이만큼 — 기본 캡의 하단 오버플로 방지
    builder: (ctx) => CategoryFilterSheet(
      initial: current,
      onApply: (sel) => Navigator.of(ctx).pop(sel),
    ),
  );
}

/// 7종 카테고리 토글 + 전체 + 적용. 일반(주변) POI 표시 종류를 고른다.
/// (친구/저장 핀은 이 필터와 무관하게 항상 표시된다.)
class CategoryFilterSheet extends StatefulWidget {
  final Set<PlaceCategory> initial;
  final ValueChanged<Set<PlaceCategory>> onApply;
  const CategoryFilterSheet({
    super.key,
    required this.initial,
    required this.onApply,
  });

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  late final Set<PlaceCategory> _sel = {...widget.initial};

  bool get _allSelected => _sel.length == PlaceCategory.values.length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('전체',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              value: _allSelected,
              onChanged: (v) => setState(() {
                _sel
                  ..clear()
                  ..addAll(v == true
                      ? PlaceCategory.values
                      : const <PlaceCategory>[]);
              }),
            ),
            const Divider(height: 1),
            ...PlaceCategory.values.map((cat) => CheckboxListTile(
                  secondary: Icon(cat.icon, color: cat.color),
                  title: Text(cat.label),
                  value: _sel.contains(cat),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _sel.add(cat);
                    } else {
                      _sel.remove(cat);
                    }
                  }),
                )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onApply({..._sel}),
                child: const Text('적용'),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
