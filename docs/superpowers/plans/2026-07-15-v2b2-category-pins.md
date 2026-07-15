# v2.0b-2 카테고리 핀 비주얼 시스템 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지도 핀을 "색=종류(7종)·모양=저장상태"로 재설계한다 — 미저장은 작은 카테고리색 아이콘+이름, 내 저장은 카테고리색 핀+북마크, 구글 기본 POI 라벨은 숨긴다.

**Architecture:** v1의 커스텀 핀 오버레이(`GoogleMapView`, Web Mercator 투영) 위에 얹는다. 순수 카테고리 모델(`PlaceCategory`)이 Google `primaryType` 코드를 7종으로 매핑하고 색·아이콘·라벨을 제공한다. `Poi`가 `bucket`을 실어 나르고, 표시용 핀 위젯 2종(`CategoryDot`/`SavedPin`)이 이를 그린다. `MapController`에 저장 id 집합을 주입하는 `setSavedIds`를 추가해 지도가 미저장/내저장을 구분한다.

**Tech Stack:** Flutter 3.44.6 / Dart, `google_maps_flutter ^2.17.1`(`GoogleMap(style:)` 지원), `http ^1.6.0`(Google Places New).

## Global Constraints

- **저장소:** `~/dev/odagada`, 브랜치 `feature/v2b-save`(현재 작업 브랜치)에서 이어간다.
- **키/비밀:** `.env`(gitignore)만 사용. 실제 키 커밋 금지.
- **테스트:** 기존 35개 테스트 회귀 유지. 새 순수 로직·위젯은 TDD. `flutter analyze` 0 issues.
- **7종 카테고리·색(확정, spec §7.7):** 맛집 `#FF7A2F` `Icons.restaurant` · 카페·디저트 `#B07A4E` `Icons.local_cafe` · 술집·바 `#8E3B7A` `Icons.local_bar` · 명소·뷰 `#3E9E5B` `Icons.park` · 쇼핑 `#2E7DF6` `Icons.shopping_bag` · 액티비티·체험 `#7A5AE0` `Icons.local_activity` · 기타 `#9AA0A6` `Icons.place`.
- **저장 상태 = 크기·모양(색 아님):** 미저장=작은 원형아이콘+이름, 내저장=핀+흰 북마크 배지+이름 굵게.

## 결정 (리뷰 대상 — 실행 전 확인)

1. **주변 검색 카테고리 확장:** 현재 provider는 `includedTypes: ['restaurant']`(맛집만)이라 7색이 지도에 안 드러난다. 확정된 목업이 다양한 종류(카페·명소·쇼핑…)를 보여주므로, **Task 2에서 `includedTypes`를 7종 대표 타입으로 확장**한다. 맛집-only를 유지하고 싶으면 Task 2의 `includedTypes`를 `['restaurant']`로 되돌리면 되고 나머지 시스템은 그대로 동작한다(전부 맛집색).
2. **범위 분리(YAGNI):** 검색-저장 / long-press 직접추가 / 메모 입력 UI는 **별개 UI 서브시스템**이라 이 계획에서 제외하고 다음 계획(v2.0b-3)으로 넘긴다. long-press는 애초에 미구현이라 "제거"할 코드 없음.
3. **내 저장 핀 범위:** 이 계획의 "내 저장" 스타일은 **현재 주변 추천에 포함된 저장 장소**(place_id가 `_savedIds`에 있는 rec)에만 적용한다. 주변에 없는 내 저장 전체를 지도에 항상 띄우는 "저장 레이어"는 친구 레이어와 함께 v2.1로 미룬다.

---

### Task 1: PlaceCategory 모델 + Google primaryType 매핑

**Files:**
- Create: `lib/core/models/place_category.dart`
- Test: `test/core/models/place_category_test.dart`

**Interfaces:**
- Produces: `enum PlaceCategory { restaurant, cafe, bar, attraction, shopping, activity, other }` with instance getters `String get label`, `Color get color`, `IconData get icon`; static `PlaceCategory fromGooglePrimaryType(String? primaryType)`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/models/place_category_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/place_category.dart';

void main() {
  group('fromGooglePrimaryType', () {
    test('음식점류 → restaurant', () {
      expect(PlaceCategory.fromGooglePrimaryType('restaurant'), PlaceCategory.restaurant);
      expect(PlaceCategory.fromGooglePrimaryType('korean_restaurant'), PlaceCategory.restaurant);
      expect(PlaceCategory.fromGooglePrimaryType('fast_food_restaurant'), PlaceCategory.restaurant);
    });
    test('카페·베이커리 → cafe', () {
      expect(PlaceCategory.fromGooglePrimaryType('cafe'), PlaceCategory.cafe);
      expect(PlaceCategory.fromGooglePrimaryType('coffee_shop'), PlaceCategory.cafe);
      expect(PlaceCategory.fromGooglePrimaryType('bakery'), PlaceCategory.cafe);
    });
    test('술집류 → bar', () {
      expect(PlaceCategory.fromGooglePrimaryType('bar'), PlaceCategory.bar);
      expect(PlaceCategory.fromGooglePrimaryType('night_club'), PlaceCategory.bar);
    });
    test('명소류 → attraction', () {
      expect(PlaceCategory.fromGooglePrimaryType('park'), PlaceCategory.attraction);
      expect(PlaceCategory.fromGooglePrimaryType('tourist_attraction'), PlaceCategory.attraction);
      expect(PlaceCategory.fromGooglePrimaryType('museum'), PlaceCategory.attraction);
    });
    test('쇼핑류 → shopping (집합 + _store 접미사)', () {
      expect(PlaceCategory.fromGooglePrimaryType('shopping_mall'), PlaceCategory.shopping);
      expect(PlaceCategory.fromGooglePrimaryType('clothing_store'), PlaceCategory.shopping);
      expect(PlaceCategory.fromGooglePrimaryType('jewelry_store'), PlaceCategory.shopping);
    });
    test('액티비티류 → activity', () {
      expect(PlaceCategory.fromGooglePrimaryType('movie_theater'), PlaceCategory.activity);
      expect(PlaceCategory.fromGooglePrimaryType('amusement_park'), PlaceCategory.activity);
    });
    test('미지·null → other', () {
      expect(PlaceCategory.fromGooglePrimaryType(null), PlaceCategory.other);
      expect(PlaceCategory.fromGooglePrimaryType(''), PlaceCategory.other);
      expect(PlaceCategory.fromGooglePrimaryType('church'), PlaceCategory.other);
    });
  });

  test('각 카테고리는 라벨·색·아이콘을 갖는다', () {
    expect(PlaceCategory.cafe.label, '카페·디저트');
    expect(PlaceCategory.cafe.color, const Color(0xFFB07A4E));
    expect(PlaceCategory.cafe.icon, Icons.local_cafe);
    expect(PlaceCategory.restaurant.color, const Color(0xFFFF7A2F));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd ~/dev/odagada && flutter test test/core/models/place_category_test.dart`
Expected: FAIL — `place_category.dart`가 없어 컴파일 에러.

- [ ] **Step 3: 최소 구현**

`lib/core/models/place_category.dart`:
```dart
import 'package:flutter/material.dart';

/// 저장·표시용 7종 카테고리 큰 묶음.
/// 색=종류(지도에서 색으로 종류 구분), 아이콘=종류. (spec §7.7)
enum PlaceCategory {
  restaurant('맛집', Color(0xFFFF7A2F), Icons.restaurant),
  cafe('카페·디저트', Color(0xFFB07A4E), Icons.local_cafe),
  bar('술집·바', Color(0xFF8E3B7A), Icons.local_bar),
  attraction('명소·뷰', Color(0xFF3E9E5B), Icons.park),
  shopping('쇼핑', Color(0xFF2E7DF6), Icons.shopping_bag),
  activity('액티비티·체험', Color(0xFF7A5AE0), Icons.local_activity),
  other('기타', Color(0xFF9AA0A6), Icons.place);

  final String label;
  final Color color;
  final IconData icon;
  const PlaceCategory(this.label, this.color, this.icon);

  /// Google Places(New) primaryType 코드를 7종으로 매핑. 미지/누락은 기타.
  /// 구체 종류(카페/술집/명소/쇼핑/액티비티)를 먼저 판정하고,
  /// 광범위한 restaurant(및 `*_restaurant`)는 마지막에 판정한다.
  static PlaceCategory fromGooglePrimaryType(String? primaryType) {
    final t = primaryType?.toLowerCase() ?? '';
    if (t.isEmpty) return PlaceCategory.other;
    if (_cafe.contains(t)) return PlaceCategory.cafe;
    if (_bar.contains(t)) return PlaceCategory.bar;
    if (_attraction.contains(t)) return PlaceCategory.attraction;
    if (_shopping.contains(t) || t.endsWith('_store')) return PlaceCategory.shopping;
    if (_activity.contains(t)) return PlaceCategory.activity;
    if (_restaurant.contains(t) || t.endsWith('_restaurant')) {
      return PlaceCategory.restaurant;
    }
    return PlaceCategory.other;
  }

  static const _restaurant = {
    'restaurant', 'food', 'meal_takeaway', 'meal_delivery',
    'diner', 'buffet_restaurant', 'food_court',
  };
  static const _cafe = {
    'cafe', 'coffee_shop', 'bakery', 'dessert_shop', 'ice_cream_shop',
    'tea_house', 'bagel_shop', 'donut_shop', 'dessert_restaurant',
  };
  static const _bar = {
    'bar', 'pub', 'wine_bar', 'night_club', 'bar_and_grill',
  };
  static const _attraction = {
    'tourist_attraction', 'park', 'national_park', 'museum', 'art_gallery',
    'historical_landmark', 'historical_place', 'plaza', 'garden',
    'observation_deck', 'monument',
  };
  static const _shopping = {
    'store', 'shopping_mall', 'department_store', 'supermarket',
    'convenience_store', 'market', 'grocery_store',
  };
  static const _activity = {
    'movie_theater', 'amusement_park', 'bowling_alley', 'gym', 'spa',
    'zoo', 'aquarium', 'stadium', 'water_park', 'sports_complex', 'arcade',
  };
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd ~/dev/odagada && flutter test test/core/models/place_category_test.dart`
Expected: PASS (전건).

- [ ] **Step 5: 커밋**

```bash
cd ~/dev/odagada
git add lib/core/models/place_category.dart test/core/models/place_category_test.dart
git commit -m "feat: add PlaceCategory (7 buckets) with Google primaryType mapping"
```

---

### Task 2: Poi.bucket 필드 + Provider(primaryType 수집·타입 확장·bucket 설정)

**Files:**
- Modify: `lib/core/models/poi.dart`
- Modify: `lib/poi/google_places_provider.dart:40-41`(fieldMask), `:44`(includedTypes), `:75-83`(_toPoi)
- Test: `test/poi/google_places_provider_test.dart`(기존 파일에 케이스 추가)

**Interfaces:**
- Consumes: `PlaceCategory.fromGooglePrimaryType` (Task 1).
- Produces: `Poi.bucket` (타입 `PlaceCategory`, 기본값 `PlaceCategory.other`). Provider가 `primaryType`로 채운다.

- [ ] **Step 1: Poi에 bucket 필드 추가(기본값으로 기존 호출 안 깨짐)**

`lib/core/models/poi.dart` — import 추가 + 필드 추가:
```dart
import 'lat_lng.dart';
import 'place_category.dart';

/// 모든 Provider가 공통으로 반환하는 관심지점.
class Poi {
  final String id;
  final String name;
  final LatLng position;
  final String category;      // Google primaryTypeDisplayName 원문(표시 보조)
  final PlaceCategory bucket;  // 7종 분류(색·아이콘)
  final String? address;
  final String? phone;
  final String? placeUrl;
  final double distanceMeters;
  final double rating;

  const Poi({
    required this.id,
    required this.name,
    required this.position,
    required this.category,
    this.bucket = PlaceCategory.other,
    this.address,
    this.phone,
    this.placeUrl,
    required this.distanceMeters,
    this.rating = 0,
  });
}
```

- [ ] **Step 2: Provider 테스트에 실패 케이스 추가**

`test/poi/google_places_provider_test.dart`에 아래 테스트를 추가한다(기존 import·헬퍼 재사용; 없으면 `MockClient` 패턴은 기존 케이스와 동일하게). primaryType→bucket 매핑을 검증:
```dart
  test('primaryType으로 bucket을 채운다', () async {
    final client = MockClient((req) async {
      return http.Response(
        jsonEncode({
          'places': [
            {
              'id': 'p1',
              'displayName': {'text': '스타벅스'},
              'location': {'latitude': 37.5, 'longitude': 127.0},
              'primaryType': 'coffee_shop',
              'primaryTypeDisplayName': {'text': '카페'},
            },
          ],
        }),
        200,
      );
    });
    final provider = GooglePlacesProvider(client: client, apiKey: 'k');
    final pois = await provider.nearby(
      LocationEvent(position: const LatLng(37.5, 127.0), timestamp: DateTime(2026)),
      radiusMeters: 500,
    );
    expect(pois.single.bucket, PlaceCategory.cafe);
  });
```
필요한 import가 없으면 파일 상단에 추가: `import 'package:odagada/core/models/place_category.dart';`. (`LocationEvent` 생성자 시그니처는 기존 테스트 케이스를 그대로 참고할 것.)

- [ ] **Step 3: 테스트 실패 확인**

Run: `cd ~/dev/odagada && flutter test test/poi/google_places_provider_test.dart`
Expected: FAIL — `bucket`이 항상 `other`(provider가 아직 안 채움).

- [ ] **Step 4: Provider 구현 — fieldMask에 primaryType 추가, includedTypes 확장, _toPoi에서 bucket 설정**

`lib/poi/google_places_provider.dart`:

(a) fieldMask(라인 40-41)에 `places.primaryType` 추가:
```dart
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.primaryType,places.primaryTypeDisplayName,places.formattedAddress',
```

(b) includedTypes(라인 44) 확장(결정 #1 — 되돌리려면 `['restaurant']`):
```dart
        'includedTypes': const [
          'restaurant', 'cafe', 'bar', 'bakery',
          'tourist_attraction', 'park', 'museum',
          'shopping_mall', 'department_store',
          'movie_theater', 'amusement_park',
        ],
```

(c) `_toPoi`(라인 75-83)에서 bucket 설정 — import 추가(`import '../core/models/place_category.dart';`) 후:
```dart
    return Poi(
      id: (p['id'] as String?) ?? '${pos.lat},${pos.lng}',
      name: (p['displayName']?['text'] as String?) ?? '이름 없음',
      position: pos,
      category: (p['primaryTypeDisplayName']?['text'] as String?) ?? '음식점',
      bucket: PlaceCategory.fromGooglePrimaryType(p['primaryType'] as String?),
      address: p['formattedAddress'] as String?,
      distanceMeters: GeoMath.distanceMeters(loc.position, pos),
    );
```

- [ ] **Step 5: 테스트 통과 + 전체 회귀 확인**

Run: `cd ~/dev/odagada && flutter test test/poi/google_places_provider_test.dart && flutter test`
Expected: PASS (신규 케이스 포함 전건).

- [ ] **Step 6: 커밋**

```bash
cd ~/dev/odagada
git add lib/core/models/poi.dart lib/poi/google_places_provider.dart test/poi/google_places_provider_test.dart
git commit -m "feat: carry PlaceCategory bucket on Poi from Places primaryType; broaden nearby types"
```

---

### Task 3: 핀 위젯 2종 (CategoryDot / SavedPin)

**Files:**
- Create: `lib/ui/place_pin.dart`
- Test: `test/ui/place_pin_test.dart`

**Interfaces:**
- Consumes: `Poi.bucket`(색·아이콘), `Poi.name`.
- Produces: `class CategoryDot extends StatelessWidget { CategoryDot({required Poi poi, required VoidCallback onTap}) }` (미저장: 작은 카테고리색 원형 아이콘 + 이름). `class SavedPin extends StatelessWidget { SavedPin({required Poi poi, required VoidCallback onTap}) }` (내저장: 카테고리색 핀 + 흰 북마크 배지 + 이름 굵게). 앵커 규약: `CategoryDot`은 원 중심이 기준점, `SavedPin`은 핀 머리 중심 x·꼬리 끝(상단에서 46px)이 기준점.

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/ui/place_pin_test.dart`:
```dart
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd ~/dev/odagada && flutter test test/ui/place_pin_test.dart`
Expected: FAIL — `place_pin.dart` 없음.

- [ ] **Step 3: 구현**

`lib/ui/place_pin.dart`:
```dart
import 'package:flutter/material.dart';
import '../core/models/poi.dart';

const double _dotSize = 30;
const double _headSize = 40;

/// 미저장 주변 장소: 작은 카테고리색 원형 아이콘 + 이름 라벨.
/// 앵커: 원 중심이 기준점.
class CategoryDot extends StatelessWidget {
  final Poi poi;
  final VoidCallback onTap;
  const CategoryDot({super.key, required this.poi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = poi.bucket;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
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
          const SizedBox(width: 4),
          _NameLabel(text: poi.name, bold: false),
        ],
      ),
    );
  }
}

/// 내 저장 장소: 카테고리색 핀 머리 + 꼬리 + 흰 북마크 배지 + 이름 굵게.
/// 앵커: 머리 중심 x, 꼬리 끝(상단에서 46px)이 기준점.
class SavedPin extends StatelessWidget {
  final Poi poi;
  final VoidCallback onTap;
  const SavedPin({super.key, required this.poi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = poi.bucket;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: _headSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: _headSize,
                  height: _headSize,
                  decoration: BoxDecoration(
                    color: c.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(c.icon, color: Colors.white, size: 20),
                ),
                Positioned(
                  right: 0,
                  top: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.color, width: 1.5),
                    ),
                    child: Icon(Icons.bookmark, size: 10, color: c.color),
                  ),
                ),
              ],
            ),
          ),
          Container(width: 3, height: 6, color: c.color), // 꼬리(끝=상단 46px)
          const SizedBox(height: 2),
          _NameLabel(text: poi.name, bold: true),
        ],
      ),
    );
  }
}

/// 흰 배경 이름 라벨(가독성). 지도 오버레이에서 폭 제한으로 오버플로 방지.
class _NameLabel extends StatelessWidget {
  final String text;
  final bool bold;
  const _NameLabel({required this.text, required this.bold});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd ~/dev/odagada && flutter test test/ui/place_pin_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
cd ~/dev/odagada
git add lib/ui/place_pin.dart test/ui/place_pin_test.dart
git commit -m "feat: add CategoryDot and SavedPin map marker widgets"
```

---

### Task 4: GoogleMapView 통합 — setSavedIds, 핀 분기, 기본 POI 라벨 숨김

**Files:**
- Modify: `lib/ui/map_view.dart:7-10`(MapController 인터페이스)
- Modify: `lib/ui/google_map_view.dart`(상태·style·_buildPins)
- Modify: `lib/ui/kakao_map_view.dart`(레거시 no-op 구현으로 컴파일 유지)

**Interfaces:**
- Consumes: `CategoryDot`, `SavedPin` (Task 3).
- Produces: `MapController.setSavedIds(Set<String> ids)` — 내 저장 place_id 집합을 지도에 주입.

- [ ] **Step 1: MapController 인터페이스에 setSavedIds 추가**

`lib/ui/map_view.dart`:
```dart
abstract class MapController {
  void moveCamera(LatLng center);
  void setPins(List<Recommendation> recs);
  void setSavedIds(Set<String> ids);
}
```

- [ ] **Step 2: KakaoMapView(레거시)에 no-op 추가 — 컴파일 유지**

`lib/ui/kakao_map_view.dart`의 `_KakaoMapViewState`(implements MapController) 안에 다른 override 메서드 옆에 추가:
```dart
  @override
  void setSavedIds(Set<String> ids) {} // 레거시(구글로 전환됨) — 미사용
```

- [ ] **Step 3: GoogleMapView — 저장 상태·맵 스타일·핀 분기 구현**

`lib/ui/google_map_view.dart`:

(a) import 추가(파일 상단, 기존 import 뒤):
```dart
import 'place_pin.dart';
```

(b) 상태 필드 추가(`List<Recommendation> _recs = const [];` 아래):
```dart
  Set<String> _savedIds = const {};
```

(c) 기본 POI/대중교통 라벨 숨김 스타일 상수 추가(`_initialZoom` 근처):
```dart
  // 구글 기본 POI·대중교통 라벨 숨김(우리 핀만 보이게).
  static const _mapStyle =
      '[{"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},'
      '{"featureType":"transit","elementType":"labels","stylers":[{"visibility":"off"}]}]';
```

(d) `setSavedIds` 구현(`setPins` 아래):
```dart
  @override
  void setSavedIds(Set<String> ids) {
    if (!mounted) return;
    setState(() => _savedIds = ids);
  }
```

(e) `GoogleMap`에 `style:` 지정(`myLocationButtonEnabled: false,` 위/아래 어디든 파라미터로):
```dart
              style: _mapStyle,
```

(f) `_buildPins`를 저장 상태로 분기하도록 교체:
```dart
  List<Widget> _buildPins(Size size) {
    const margin = 160.0; // 이름 라벨 폭까지 감안한 컬링 여유
    final pins = <Widget>[];
    for (final r in _recs) {
      final s = _screenOf(r.poi.position, size);
      if (s.dx < -margin ||
          s.dy < -margin ||
          s.dx > size.width + margin ||
          s.dy > size.height + margin) {
        continue;
      }
      final saved = _savedIds.contains(r.poi.id);
      if (saved) {
        pins.add(Positioned(
          left: s.dx - 22, // 머리 폭 44의 절반
          top: s.dy - 46,  // 꼬리 끝이 기준점
          child: SavedPin(poi: r.poi, onTap: () => widget.onPinTap(r.poi)),
        ));
      } else {
        pins.add(Positioned(
          left: s.dx - 15, // 원 지름 30의 절반(원 중심 = 기준점)
          top: s.dy - 15,
          child: CategoryDot(poi: r.poi, onTap: () => widget.onPinTap(r.poi)),
        ));
      }
    }
    return pins;
  }
```

(g) 기존 `_Pin` 위젯 클래스(파일 하단, 131-169행)와 그 안의 `const pinSize = 40.0;` 지역 상수는 더 이상 안 쓰이므로 **삭제**한다.

- [ ] **Step 4: 정적 분석 — 컴파일·미사용 경고 0 확인**

Run: `cd ~/dev/odagada && flutter analyze`
Expected: `No issues found!` (미사용 `_Pin` 제거 확인).

- [ ] **Step 5: 전체 테스트 회귀 확인**

Run: `cd ~/dev/odagada && flutter test`
Expected: PASS 전건(핀 변경은 위젯테스트 없음 — 다음 Task의 MapScreen 와이어링 + 온디바이스로 검증).

- [ ] **Step 6: 커밋**

```bash
cd ~/dev/odagada
git add lib/ui/map_view.dart lib/ui/kakao_map_view.dart lib/ui/google_map_view.dart
git commit -m "feat: render category dots / saved pins on map; hide base POI labels"
```

---

### Task 5: MapScreen 와이어링 + InfoCard 카테고리 표시

**Files:**
- Modify: `lib/ui/map_screen.dart`(_reloadSaved / onReady에서 setSavedIds 호출)
- Modify: `lib/ui/info_card.dart:38-39`(카테고리 아이콘+라벨)
- Test: `test/ui/info_card_test.dart`(기존 파일에 케이스 추가)

**Interfaces:**
- Consumes: `MapController.setSavedIds`(Task 4), `Poi.bucket`(Task 2).

- [ ] **Step 1: InfoCard 테스트에 실패 케이스 추가**

`test/ui/info_card_test.dart`에 추가(기존 pump 헬퍼/생성 패턴 재사용):
```dart
  testWidgets('카테고리 아이콘과 라벨을 보여준다', (t) async {
    final poi = const Poi(
      id: 'p1', name: '스타벅스', position: LatLng(37.5, 127.0),
      category: '카페', bucket: PlaceCategory.cafe, distanceMeters: 120,
    );
    await t.pumpWidget(MaterialApp(home: Scaffold(body: InfoCard(
      poi: poi, onNavigate: () {}, onSave: () {},
    ))));
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    expect(find.textContaining('카페·디저트'), findsOneWidget);
  });
```
파일 상단에 import 없으면 추가: `import 'package:odagada/core/models/place_category.dart';`, `import 'package:odagada/core/models/lat_lng.dart';`.

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd ~/dev/odagada && flutter test test/ui/info_card_test.dart`
Expected: FAIL — 현재 카드는 `poi.category`(원문 '카페')만, `local_cafe` 아이콘·`카페·디저트` 라벨 없음.

- [ ] **Step 3: InfoCard 구현 — 부제에 bucket 아이콘+라벨**

`lib/ui/info_card.dart`의 부제(라인 37-39)를 교체:
```dart
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(poi.bucket.icon, size: 18, color: poi.bucket.color),
                const SizedBox(width: 6),
                Text('$_distanceText · ${poi.bucket.label}',
                    style: const TextStyle(fontSize: 18, color: Colors.black54)),
              ],
            ),
```

- [ ] **Step 4: InfoCard 테스트 통과 확인**

Run: `cd ~/dev/odagada && flutter test test/ui/info_card_test.dart`
Expected: PASS.

- [ ] **Step 5: MapScreen에서 저장 id를 지도에 밀어넣기**

`lib/ui/map_screen.dart`:

(a) `_reloadSaved`의 setState 뒤에 지도 반영 추가:
```dart
  Future<void> _reloadSaved() async {
    final u = widget.auth.user;
    if (u == null) {
      if (mounted) setState(() => _savedIds = {});
      _map?.setSavedIds(const {});
      return;
    }
    final ids = await widget.savedRepo.savedPlaceIds(u.id);
    if (mounted) setState(() => _savedIds = ids);
    _map?.setSavedIds(ids);
  }
```

(b) 지도 준비 콜백(`onReady`, build 안)에서 마지막 저장 상태도 반영:
```dart
              onReady: (c) {
                _map = c;
                final last = _lastUpdate;
                if (last != null) _applyToMap(last);
                _map?.setSavedIds(_savedIds);
              },
```

- [ ] **Step 6: 전체 회귀 + 분석**

Run: `cd ~/dev/odagada && flutter test && flutter analyze`
Expected: 테스트 전건 PASS, analyze `No issues found!`.

- [ ] **Step 7: 커밋**

```bash
cd ~/dev/odagada
git add lib/ui/map_screen.dart lib/ui/info_card.dart test/ui/info_card_test.dart
git commit -m "feat: push saved ids to map; show category in info card"
```

---

## 온디바이스 검증(계획 완료 후, 실기기 Galaxy Z Fold5)

지도·핀은 위젯테스트가 어려워(플랫폼 뷰) 실기기로 확인한다:
1. `cd ~/dev/odagada && flutter run -d <device>` (폰 연결: `adb devices`).
2. 주변에 **다양한 종류**의 작은 카테고리색 아이콘+이름이 뜨는지(맛집 주황·카페 갈색·명소 초록 등), 구글 **기본 POI 라벨이 사라졌는지** 확인.
3. 한 곳 저장 → 그 핀이 **카테고리색 핀 + 흰 북마크 배지 + 이름 굵게**로 바뀌는지, 저장 해제 시 작은 아이콘으로 되돌아가는지.
4. 핀 탭 → 정보카드에 **카테고리 아이콘+라벨**이 뜨는지.
5. 폴더블 스크린샷: `adb shell screencap -p /sdcard/x.png` 후 pull.

## Self-Review 결과

- **Spec 커버리지:** §7.7 "핀 비주얼 언어(2026-07-15 확정)" → Task 1(색·아이콘)·Task 3(미저장/내저장 위젯)·Task 4(지도 분기·기본라벨 숨김). §7.3 "카테고리 7종 자동 채움" → Task 1(매핑)·Task 2(provider primaryType). 검색-저장/직접추가/메모는 결정 #2로 명시 제외(다음 계획).
- **Placeholder 스캔:** 없음(모든 스텝에 실제 코드/명령/기대값).
- **타입 일관성:** `PlaceCategory`(label/color/icon/fromGooglePrimaryType), `Poi.bucket`, `CategoryDot`/`SavedPin`(poi+onTap), `MapController.setSavedIds(Set<String>)` — Task 간 시그니처 일치 확인.
