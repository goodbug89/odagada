# POI 밀도 조절 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 일반(주변) POI를 라벨 없는 점으로 만들고, 임계 줌 미만이면 숨기며, 카테고리로 걸러 지도 밀도를 낮춘다(친구/저장 핀은 항상 표시).

**Architecture:** 세 독립 레버 — (1) `CategoryDot`에서 이름표 제거, (2) `google_map_view._buildPins`가 카메라 줌 ≥16일 때만 일반 POI를 렌더 + `map_screen`이 `TiledPoiSource`를 `minBrowseZoom:16`으로 생성해 그 아래선 검색도 안 함, (3) 새 `CategoryFilterSheet`로 7종 중 볼 종류만 고르고 `map_screen`이 일반 POI만 필터(친구/저장 오버레이는 필터·줌 무관 항상).

**Tech Stack:** Flutter/Dart, 기존 `PlaceCategory`(7종 enum), `TiledPoiSource`, `google_maps_flutter` 커스텀 핀 오버레이.

## Global Constraints

- 패키지명 `odagada`. Flutter 경로: `export PATH="/opt/homebrew/bin:$PATH"`.
- 임계 줌 `Z = 16`. 두 곳에 명시: `map_screen`의 `TiledPoiSource(..., minBrowseZoom: 16)`(검색 게이트)와 `google_map_view`의 `static const _ambientMinZoom = 16.0`(렌더 게이트). **`tiled_poi_source.dart`의 기본값(14)과 그 단위 테스트는 건드리지 않는다** — 생성 시 인자로만 올린다(기존 테스트 보존).
- 카테고리 필터는 **일반 POI에만** 적용. 친구(extraPins)·내 저장(savedOverlay) 핀은 필터·줌 무관 **항상 표시**.
- 7종 카테고리 = `PlaceCategory.values` (restaurant/cafe/bar/attraction/shopping/activity/other).
- 기존 baseline analyze = info 3건(saved_list_screen.dart:56, maps_loader_web.dart:2 ×2). 신규 0 유지.
- 커밋 메시지 끝: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

### Task 1: `CategoryDot` 라벨 제거

**Files:**
- Modify: `lib/ui/place_pin.dart` (`CategoryDot.build`)
- Test: `test/ui/place_pin_test.dart` (CategoryDot 테스트 갱신)

**Interfaces:**
- Consumes: `Poi.bucket` (`PlaceCategory`), `PlaceCategory.color`/`.icon`.
- Produces: `CategoryDot`는 이름표 없이 카테고리색 원+아이콘만 렌더. `PlacePin`·`_NameLabel`은 불변.

- [ ] **Step 1: 기존 CategoryDot 테스트를 "라벨 없음"으로 갱신(실패 상태로)**

`test/ui/place_pin_test.dart`에서 이 테스트
```dart
  testWidgets('CategoryDot: 이름 + 카테고리 아이콘 표시, 탭 콜백', (t) async {
    var tapped = false;
    await _pump(t, CategoryDot(poi: _poi(), onTap: () => tapped = true));
    expect(find.text('스타벅스'), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    await t.tap(find.byType(CategoryDot));
    expect(tapped, isTrue);
  });
```
를 다음으로 교체:
```dart
  testWidgets('CategoryDot: 이름표 없이 카테고리 아이콘만, 탭 콜백', (t) async {
    var tapped = false;
    await _pump(t, CategoryDot(poi: _poi(), onTap: () => tapped = true));
    expect(find.text('스타벅스'), findsNothing); // 일반 POI는 라벨 숨김
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    await t.tap(find.byType(CategoryDot));
    expect(tapped, isTrue);
  });
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter test test/ui/place_pin_test.dart`
Expected: FAIL — `find.text('스타벅스')`가 아직 1개 발견되어 `findsNothing` 실패.

- [ ] **Step 3: CategoryDot에서 이름표 제거**

`lib/ui/place_pin.dart`의 `CategoryDot.build`를 다음으로 교체:
```dart
  @override
  Widget build(BuildContext context) {
    final c = poi.bucket;
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // 점 히트영역(작아지므로 opaque 유지)
      onTap: onTap,
      child: Container(
        width: _dotSize,
        height: _dotSize,
        decoration: BoxDecoration(
          color: c.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Icon(c.icon, color: Colors.white, size: 17),
      ),
    );
  }
```
(`Row`·`SizedBox(width:4)`·`_NameLabel`을 제거. `_NameLabel`은 `PlacePin`이 계속 쓰므로 파일에 남긴다.)

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter test test/ui/place_pin_test.dart`
Expected: PASS (CategoryDot 라벨없음, PlacePin 테스트들 그대로 통과).

- [ ] **Step 5: 전체 테스트 + analyze**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter test && flutter analyze`
Expected: 전체 통과, analyze 신규 0(기존 3).

- [ ] **Step 6: Commit**

```bash
cd /Users/goodbug/dev/odagada && git add lib/ui/place_pin.dart test/ui/place_pin_test.dart && git commit -m "feat(pins): drop name label from ambient CategoryDot

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `CategoryFilterSheet` (카테고리 필터 시트)

**Files:**
- Create: `lib/ui/category_filter_sheet.dart`
- Test: `test/ui/category_filter_sheet_test.dart`

**Interfaces:**
- Consumes: `PlaceCategory` (`.values`, `.label`, `.icon`, `.color`).
- Produces:
  - `Future<Set<PlaceCategory>?> showCategoryFilterSheet(BuildContext context, Set<PlaceCategory> current)` — 시트를 띄우고 선택 결과(적용 시) 또는 null(취소) 반환.
  - `class CategoryFilterSheet extends StatefulWidget { final Set<PlaceCategory> initial; final ValueChanged<Set<PlaceCategory>> onApply; }` — 시트 본문(테스트용 공개).

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

```dart
// test/ui/category_filter_sheet_test.dart
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter test test/ui/category_filter_sheet_test.dart`
Expected: FAIL — `category_filter_sheet.dart` 없음.

- [ ] **Step 3: 시트 구현**

```dart
// lib/ui/category_filter_sheet.dart
import 'package:flutter/material.dart';
import '../core/models/place_category.dart';

/// 카테고리 필터 바텀시트를 띄우고 선택 결과를 반환한다(취소/닫기면 null).
Future<Set<PlaceCategory>?> showCategoryFilterSheet(
    BuildContext context, Set<PlaceCategory> current) {
  return showModalBottomSheet<Set<PlaceCategory>>(
    context: context,
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
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter test test/ui/category_filter_sheet_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: 전체 테스트 + analyze**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter test && flutter analyze`
Expected: 전체 통과, analyze 신규 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/goodbug/dev/odagada && git add lib/ui/category_filter_sheet.dart test/ui/category_filter_sheet_test.dart && git commit -m "feat(ui): CategoryFilterSheet — pick which ambient categories to show

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: 줌 게이팅 렌더 (`google_map_view`)

**Files:**
- Modify: `lib/ui/google_map_view.dart` (`_ambientMinZoom` 상수 + `_buildPins`)

**Interfaces:**
- Consumes: `_camZoom`(기존 `double` 필드, `onCameraMove`로 갱신), `_savedIds`, `_friendCounts`, `_recs`.
- Produces: 카메라 줌 <16이면 일반 POI(`CategoryDot`)를 렌더하지 않음. 친구/저장(`PlacePin`)은 항상 렌더.

이 태스크는 플랫폼뷰라 새 단위 테스트가 없다. 검증: `flutter analyze` 신규 0 + 전체 `flutter test` 통과 + 컴파일. 렌더 게이트 동작은 온디바이스로 확인(줌<16 친구/저장만, ≥16 일반 등장).

- [ ] **Step 1: `_ambientMinZoom` 상수 추가**

`lib/ui/google_map_view.dart`에서 기존 `_mapStyle` 정적 상수 근처에 추가:
```dart
  // 이 줌 미만이면 일반(주변) POI 점은 그리지 않는다(친구/저장 핀은 항상).
  static const _ambientMinZoom = 16.0;
```

- [ ] **Step 2: `_buildPins`의 일반 POI 분기에 줌 게이트 적용**

`_buildPins` 안의 분기
```dart
      if (saved || fc > 0) {
        pins.add(Positioned(
          left: s.dx - 22, // 머리 폭 44의 절반
          top: s.dy - 46,  // 꼬리 끝이 기준점
          child: PlacePin(
            poi: r.poi,
            saved: saved,
            friendCount: fc,
            onTap: () => widget.onPinTap(r.poi),
          ),
        ));
      } else {
        pins.add(Positioned(
          left: s.dx - 15, // 원 지름 30의 절반(원 중심 = 기준점)
          top: s.dy - 15,
          child: CategoryDot(poi: r.poi, onTap: () => widget.onPinTap(r.poi)),
        ));
      }
```
에서 `else`를 `else if (_camZoom >= _ambientMinZoom)`로 바꾼다:
```dart
      if (saved || fc > 0) {
        pins.add(Positioned(
          left: s.dx - 22, // 머리 폭 44의 절반
          top: s.dy - 46,  // 꼬리 끝이 기준점
          child: PlacePin(
            poi: r.poi,
            saved: saved,
            friendCount: fc,
            onTap: () => widget.onPinTap(r.poi),
          ),
        ));
      } else if (_camZoom >= _ambientMinZoom) {
        // 일반 POI는 임계 줌 이상에서만(축소 시 친구/저장만 보이게).
        pins.add(Positioned(
          left: s.dx - 15, // 원 지름 30의 절반(원 중심 = 기준점)
          top: s.dy - 15,
          child: CategoryDot(poi: r.poi, onTap: () => widget.onPinTap(r.poi)),
        ));
      }
```

- [ ] **Step 3: analyze + 전체 테스트**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter analyze && flutter test`
Expected: analyze 신규 0(기존 3), 전체 테스트 통과.

- [ ] **Step 4: Commit**

```bash
cd /Users/goodbug/dev/odagada && git add lib/ui/google_map_view.dart && git commit -m "feat(map): zoom-gate ambient POIs (render only at zoom >= 16)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `map_screen` — 카테고리 필터 배선 + 검색 게이트

**Files:**
- Modify: `lib/ui/map_screen.dart` (필드·`_poiSource` 생성·`_runSearch` 필터·앱바 필터 아이콘)

**Interfaces:**
- Consumes: `showCategoryFilterSheet(context, Set<PlaceCategory>) → Future<Set<PlaceCategory>?>` (Task 2), `PlaceCategory.values`, `TiledPoiSource(registry, {int minBrowseZoom})`, `Poi.bucket`.
- Produces: (앱 배선; 다른 태스크가 소비하지 않음.)

플랫폼뷰 화면이라 새 단위 테스트 없음. 필터 시트 자체는 Task 2에서 테스트됨. 검증: `flutter analyze` 신규 0 + 전체 `flutter test` 통과 + 컴파일. 필터·검색게이트 동작은 온디바이스.

- [ ] **Step 1: import 추가**

`lib/ui/map_screen.dart` 상단 import 목록에 추가:
```dart
import '../core/models/place_category.dart';
import 'category_filter_sheet.dart';
```

- [ ] **Step 2: 필드 추가 + `_poiSource`를 minBrowseZoom:16으로 생성**

`_MapScreenState`에서 이 줄
```dart
  late final TiledPoiSource _poiSource = TiledPoiSource(widget.registry);
```
을
```dart
  // 임계 줌 16 미만이면 일반 POI 검색 자체를 건너뛴다(렌더 게이트와 같은 값).
  late final TiledPoiSource _poiSource =
      TiledPoiSource(widget.registry, minBrowseZoom: 16);
  Set<PlaceCategory> _visibleCategories = PlaceCategory.values.toSet();
```
로 교체.

- [ ] **Step 3: `_runSearch`에서 일반 POI를 카테고리로 필터**

`_runSearch` 안의 이 줄
```dart
    final pois = await _poiSource.load(bounds, zoom);
```
을 다음으로 교체:
```dart
    // 일반 POI만 카테고리 필터 적용(친구/저장 오버레이는 아래에서 무관하게 병합).
    final pois = (await _poiSource.load(bounds, zoom))
        .where((p) => _visibleCategories.contains(p.bucket))
        .toList();
```
(이후 `ids`/`savedOverlay`/`friendOverlay`/`recs` 로직은 그대로. 필터로 빠진 장소가 내 저장/친구 저장이면 savedOverlay·friendOverlay가 다시 넣어 항상 표시된다.)

- [ ] **Step 4: 앱바에 필터 아이콘 추가**

`build`의 `AppBar.actions`에서 검색 IconButton 다음(내 저장 IconButton 앞)에 삽입:
```dart
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: '카테고리 필터',
            onPressed: () async {
              final sel =
                  await showCategoryFilterSheet(context, _visibleCategories);
              if (sel == null || !mounted) return;
              setState(() => _visibleCategories = sel);
              // 캐시 재필터(타일 이미 있으면 네트워크 0)로 즉시 반영.
              final b = _lastBounds, z = _lastZoom;
              if (b != null && z != null) _runSearch(b, z);
            },
          ),
```

- [ ] **Step 5: analyze + 전체 테스트**

Run: `export PATH="/opt/homebrew/bin:$PATH"; cd /Users/goodbug/dev/odagada && flutter analyze && flutter test`
Expected: analyze 신규 0(기존 3). 전체 테스트 통과. `showCategoryFilterSheet`/`PlaceCategory`/`_visibleCategories` 관련 미사용·미정의 경고 없음.

- [ ] **Step 6: Commit**

```bash
cd /Users/goodbug/dev/odagada && git add lib/ui/map_screen.dart && git commit -m "feat(map): category filter for ambient POIs + zoom search-gate wiring

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## 온디바이스 검증 (전체 태스크 후, 사용자와 함께)

- 실기기(R3CW703J2ZV)에 빌드:
  1. **라벨 사라짐**: 일반 POI가 이름표 없는 점으로만(겹침 클러터 해소). 친구/저장 핀은 이름표 유지.
  2. **줌 게이팅**: 초기 줌(15)에선 친구/저장 핀만. 확대(≥16)하면 일반 POI 점 등장. 축소하면 다시 사라짐.
  3. **카테고리 필터**: 필터 아이콘 → 시트 → 특정 종류만 켜기 → 일반 POI가 그에 맞게 줄고 친구/저장은 항상. 재검색 없이 즉시(네트워크 0).
  4. Z=16이 붐빔/희소 균형에 맞는지 보고 필요 시 `_ambientMinZoom`(google_map_view)·`minBrowseZoom`(map_screen) 함께 조정.
- 점만 남아 탭 히트영역이 작아지므로 탭 정확도 확인.

## Self-Review 메모(스펙 대비 커버리지)

- 스펙 §2 라벨 숨김 → Task 1. §3 줌 게이팅 → Task 3(렌더)+Task 4 Step2(검색게이트 minBrowseZoom:16). §4 카테고리 필터(상태·적용·재적용·UI) → Task 2(시트)+Task 4(필드·필터·아이콘·재검색). §5 데이터 흐름 → Task 4 Step3 + Task 3. §6 테스트 → Task 1/2 단위 + Task 3/4 analyze/test + 온디바이스.
- 스펙은 "minBrowseZoom 기본값 14→16"이라 했으나, `tiled_poi_source.dart` 기본값·단위테스트 보존을 위해 **생성 인자로 16 지정**(Task 4 Step2). 효과 동일(그 map_screen 인스턴스는 16). 렌더 게이트(Task 3)가 캐시 잔여 누수까지 막아 저줌에서 일반 POI 완전 비표시.
- 클러스터·필터 영속화(§8) = 범위 밖.
