# v2.0d 정보카드·모드토글·내저장 오버레이 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** (①) 정보카드에 닫기(X+지도탭)와 주소·전화·영업시간을 넣고, (②) 추적↔탐색 모드 토글 FAB을 만들고, (③) 내 저장 장소는 뷰포트 20곳 상한과 무관하게 항상 지도에 오버레이한다.

**Architecture:** v2.0c 브라우즈 위에 얹는다. Provider가 전화·영업시간 필드를 추가로 받아 `Poi`에 싣는다. `InfoCard`는 닫기 콜백과 상세 정보를 표시(스크롤 가능). `GoogleMapView`가 지도 탭(`onMapTap`)과 따라가기 상태 변화(`onFollowChanged`)를 콜백하고 `stopFollowing()`을 제공. 저장 시 카테고리 버킷을 저장(마이그레이션 없이 기존 `category` 컬럼에 버킷 id 저장)해 저장-전용 핀도 색/아이콘을 갖게 하고, `MapScreen`이 매 검색 때 보이는 영역 안의 내 저장을 검색결과와 dedupe해 병합한다.

**Tech Stack:** Flutter 3.44.6, `google_maps_flutter ^2.17.1`(`GoogleMap.onTap`), Google Places API (New) 추가 필드(`nationalPhoneNumber`, `regularOpeningHours`).

## Global Constraints

- 저장소 `/Users/goodbug/dev/odagada`, 브랜치 `feature/v2b-save`(현재), 새 브랜치 금지. Flutter `/opt/homebrew/bin`(`export PATH="/opt/homebrew/bin:$PATH"`). 패키지 `odagada`.
- 기존 50개 테스트 회귀 유지. 순수/모델/위젯은 TDD. `flutter analyze` 신규 이슈 0(기존 info 3건: `saved_list_screen.dart:56`, `maps_loader_web.dart:2`×2).
- **평점/리뷰 표시 금지**(§2 공개평점 없음 원칙). 정보카드엔 주소·전화·영업시간(영업중)만.
- **내 저장은 무조건 표시**: 뷰포트 검색 20곳과 별개로, 보이는 영역(중심·반경) 안의 내 저장은 항상 핀. place_id로 검색결과와 dedupe.
- **마이그레이션 없이**: 저장 시 `saved_places.category` 컬럼에 **버킷 id**(enum name, 예 `restaurant`)를 저장한다. 기존 행(구글 표시문자열)은 읽을 때 `기타`로 폴백(테스트 데이터라 무해).
- 친구 저장 오버레이는 **v2.1**(친구 그래프 이후) — 이 계획은 내 저장까지만.

## 결정 (확정)
1. 정보카드는 내용이 길어질 수 있어 **스크롤 가능**(최대 높이 제한)으로 만든다.
2. 모드 토글은 별도 위젯 대신 **내 위치 FAB의 상태 토글**로 구현(추적ON=`Icons.gps_fixed` 강조, 탐색=`Icons.my_location`). 손대면 자동 탐색 전환.
3. 저장 카테고리는 기존 `category` 컬럼 재사용(버킷 id 저장) — 새 컬럼/마이그레이션 없이. 표시 라벨은 `PlaceCategory.label`에서 파생.

---

### Task 1: Poi 필드(전화·영업) + Provider 추가 필드 수집

**Files:**
- Modify: `lib/core/models/poi.dart`
- Modify: `lib/poi/google_places_provider.dart`
- Test: `test/poi/google_places_provider_test.dart`(케이스 추가)

**Interfaces:**
- Produces: `Poi`에 `bool? openNow`, `List<String>? weekdayHours` 추가(`phone`은 이미 존재, Provider가 채움). Provider fieldMask에 `places.nationalPhoneNumber,places.regularOpeningHours` 추가.

- [ ] **Step 1: Poi에 필드 추가**

`lib/core/models/poi.dart`의 클래스에 필드 추가(기본값 null이라 기존 생성 안 깨짐):
```dart
  final String? phone;
  final String? placeUrl;
  final bool? openNow;              // 영업중 여부(모르면 null)
  final List<String>? weekdayHours; // 요일별 영업시간 설명(없으면 null)
  final double distanceMeters;
```
그리고 생성자에 `this.openNow,` 와 `this.weekdayHours,`를 `this.placeUrl,` 다음에 추가.

- [ ] **Step 2: Provider 테스트에 실패 케이스 추가**

`test/poi/google_places_provider_test.dart`에 추가(기존 mocktail 패턴·`loc()` 헬퍼 재사용):
```dart
  test('전화·영업시간을 파싱한다', () async {
    when(() => mockClient.post(any(),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({
          'places': [
            {
              'id': 'p1',
              'displayName': {'text': '카페A'},
              'location': {'latitude': 37.5, 'longitude': 127.0},
              'primaryType': 'cafe',
              'nationalPhoneNumber': '02-123-4567',
              'regularOpeningHours': {
                'openNow': true,
                'weekdayDescriptions': ['월요일: 09:00~18:00', '화요일: 09:00~18:00'],
              },
            },
          ],
        })),
        200,
      ),
    );
    final provider = GooglePlacesProvider(client: mockClient, apiKey: 'k');
    final pois = await provider.nearby(loc(), radiusMeters: 500);
    expect(pois.single.phone, '02-123-4567');
    expect(pois.single.openNow, true);
    expect(pois.single.weekdayHours, hasLength(2));
  });
```
(상단 import에 `dart:convert`/`http`가 이미 있으면 재사용. `loc()` 시그니처는 기존 케이스를 그대로 따를 것.)

- [ ] **Step 3: 실패 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/poi/google_places_provider_test.dart`
Expected: FAIL(필드 null).

- [ ] **Step 4: Provider 구현**

`lib/poi/google_places_provider.dart`:
(a) fieldMask에 추가:
```dart
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.primaryType,places.primaryTypeDisplayName,places.formattedAddress,places.nationalPhoneNumber,places.regularOpeningHours',
```
(b) `_toPoi`에서 설정(기존 필드 뒤에):
```dart
      phone: p['nationalPhoneNumber'] as String?,
      openNow: (p['regularOpeningHours'] as Map<String, dynamic>?)?['openNow'] as bool?,
      weekdayHours: ((p['regularOpeningHours'] as Map<String, dynamic>?)?['weekdayDescriptions'] as List?)?.cast<String>(),
```

- [ ] **Step 5: 통과 + 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter test`
Expected: 신규 케이스 포함 전건 PASS.

- [ ] **Step 6: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/core/models/poi.dart lib/poi/google_places_provider.dart test/poi/google_places_provider_test.dart
git commit -m "feat: fetch phone + opening hours from Places into Poi"
```

---

### Task 2: InfoCard — 닫기 버튼 + 주소·전화·영업시간 표시(스크롤)

**Files:**
- Modify: `lib/ui/info_card.dart`
- Test: `test/ui/info_card_test.dart`(케이스 추가)

**Interfaces:**
- Consumes: `Poi.address/phone/openNow/weekdayHours/bucket`.
- Produces: `InfoCard`에 `required VoidCallback onClose` 추가. 내부는 스크롤 가능.

- [ ] **Step 1: 실패하는 위젯 테스트 추가**

`test/ui/info_card_test.dart`에 추가:
```dart
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
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/ui/info_card_test.dart`
Expected: FAIL(onClose 없음/미표시).

- [ ] **Step 3: InfoCard 구현**

`lib/ui/info_card.dart` 전체를 교체:
```dart
import 'package:flutter/material.dart';
import '../core/models/poi.dart';

/// 핀 탭 시 하단에 뜨는 정보 카드. 운전 중 가독성 위해 큰 글씨. 내용이 길면 스크롤.
class InfoCard extends StatelessWidget {
  final Poi poi;
  final VoidCallback onNavigate;
  final bool isSaved;
  final VoidCallback onSave;
  final VoidCallback onClose;
  const InfoCard({
    super.key,
    required this.poi,
    required this.onNavigate,
    this.isSaved = false,
    required this.onSave,
    required this.onClose,
  });

  String get _distanceText {
    final d = poi.distanceMeters;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}km';
    return '${d.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.45),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(poi.name,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '닫기',
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(poi.bucket.icon, size: 18, color: poi.bucket.color),
                const SizedBox(width: 6),
                Text('$_distanceText · ${poi.bucket.label}',
                    style: const TextStyle(fontSize: 18, color: Colors.black54)),
              ]),
              if (poi.openNow != null) ...[
                const SizedBox(height: 8),
                _OpenBadge(open: poi.openNow!),
              ],
              if (poi.address != null && poi.address!.isNotEmpty)
                _InfoRow(icon: Icons.place_outlined, text: poi.address!),
              if (poi.phone != null && poi.phone!.isNotEmpty)
                _InfoRow(icon: Icons.phone_outlined, text: poi.phone!),
              if (poi.weekdayHours != null && poi.weekdayHours!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('영업시간',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...poi.weekdayHours!.map((h) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(h,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54)),
                    )),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSave,
                    icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
                    label: Text(isSaved ? '저장됨' : '저장',
                        style: const TextStyle(fontSize: 18)),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onNavigate,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56)),
                    child:
                        const Text('길찾기', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16))),
      ]),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool open;
  const _OpenBadge({required this.open});
  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.green : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(open ? '영업 중' : '영업 종료',
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/ui/info_card_test.dart`
Expected: PASS. (기존 InfoCard 생성 지점이 있으면 `onClose`가 required라 컴파일 에러 — 그 지점은 Task 3(MapScreen)에서 배선. 이 태스크의 위젯테스트는 자체적으로 onClose를 넘기므로 통과. 전체 `flutter test`는 MapScreen이 아직 onClose 미배선이면 실패할 수 있으니, 이 태스크는 focused 테스트로 확인하고 전체는 Task 3에서 green 확인.)

- [ ] **Step 5: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/ui/info_card.dart test/ui/info_card_test.dart
git commit -m "feat: InfoCard close button + address/phone/opening-hours (scrollable)"
```

---

### Task 3: 지도 탭 닫기 + 추적/탐색 모드 토글 FAB

**Files:**
- Modify: `lib/ui/map_view.dart`(MapController + 빌더)
- Modify: `lib/ui/google_map_view.dart`
- Modify: `lib/ui/kakao_map_view.dart`(no-op)
- Modify: `lib/ui/map_screen.dart`(onClose·onMapTap·FAB 토글)

**Interfaces:**
- Produces: `MapController.stopFollowing()`; `MapViewBuilder`에 `required VoidCallback onMapTap`, `required void Function(bool following) onFollowChanged` 추가.

- [ ] **Step 1: 인터페이스 확장**

`lib/ui/map_view.dart`:
```dart
abstract class MapController {
  void setCar(LatLng car);
  void recenter();          // 따라가기 재개 + 차로 이동
  void stopFollowing();     // 따라가기 해제(카메라 그대로)
  void setPins(List<Recommendation> recs);
  void setSavedIds(Set<String> ids);
}

typedef MapViewBuilder = Widget Function({
  required void Function(MapController) onReady,
  required PinTapCallback onPinTap,
  required void Function(LatLng center, double radiusMeters) onCameraIdle,
  required VoidCallback onMapTap,
  required void Function(bool following) onFollowChanged,
});
```

- [ ] **Step 2: KakaoMapView no-op 보강**

`_KakaoMapViewState`에 추가: `@override void stopFollowing() {}`. (위젯 생성자는 변경 불필요 — 앱에서 미생성.)

- [ ] **Step 3: GoogleMapView 구현**

`lib/ui/google_map_view.dart`:
(a) 위젯에 콜백 필드 추가: `final VoidCallback onMapTap;`, `final void Function(bool following) onFollowChanged;` + 생성자 `required`.
(b) 따라가기 상태 변경 시 콜백하는 헬퍼:
```dart
  void _setFollowing(bool v) {
    if (_following == v) return;
    _following = v;
    widget.onFollowChanged(v);
  }
```
(c) `stopFollowing` 구현: `@override void stopFollowing() => _setFollowing(false);`
(d) `recenter`에서 `_following = true;`를 `_setFollowing(true);`로 교체. `onCameraMoveStarted`의 `_following = false;`를 `_setFollowing(false);`로 교체(프로그램 이동 소비 로직은 유지):
```dart
              onCameraMoveStarted: () {
                if (_programmaticMove) {
                  _programmaticMove = false;
                } else {
                  _setFollowing(false);
                }
              },
```
(e) `GoogleMap`에 지도 탭 배선: `onTap: (_) => widget.onMapTap(),`.

- [ ] **Step 4: MapScreen 배선 — 닫기·지도탭·FAB 토글**

`lib/ui/map_screen.dart`:
(a) 상태 추가: `bool _following = true;`
(b) `mapBuilder(...)` 호출에 콜백 추가:
```dart
              onMapTap: () {
                if (_selected != null) setState(() => _selected = null);
              },
              onFollowChanged: (f) {
                if (mounted) setState(() => _following = f);
              },
```
(c) InfoCard에 `onClose: () => setState(() => _selected = null),` 추가.
(d) FAB를 상태 토글로 교체:
```dart
      floatingActionButton: FloatingActionButton(
        tooltip: _following ? '탐색 모드로' : '내 위치(추적)',
        backgroundColor: _following
            ? Theme.of(context).colorScheme.primary
            : null,
        foregroundColor: _following ? Colors.white : null,
        onPressed: () {
          if (_following) {
            _map?.stopFollowing();
          } else {
            _map?.recenter();
          }
        },
        child: Icon(_following ? Icons.gps_fixed : Icons.my_location),
      ),
```

- [ ] **Step 5: app.dart — mapBuilder 시그니처 확장**

`lib/app.dart`의 `mapBuilder`에 `onMapTap`·`onFollowChanged` 파라미터를 추가하고 `GoogleMapView(...)`에 전달.

- [ ] **Step 6: 분석 + 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter analyze && flutter test`
Expected: analyze 신규 0, 테스트 green(InfoCard onClose 배선돼 전체 컴파일). 지도/FAB는 플랫폼뷰라 on-device 검증.

- [ ] **Step 7: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/ui/map_view.dart lib/ui/google_map_view.dart lib/ui/kakao_map_view.dart lib/ui/map_screen.dart lib/app.dart
git commit -m "feat: dismiss card on map tap + follow/browse mode toggle FAB"
```

---

### Task 4: 저장 시 카테고리 버킷 저장 + SavedPlace.bucket

**Files:**
- Modify: `lib/core/models/place_category.dart`(fromId)
- Modify: `lib/saved/saved_place.dart`(bucket)
- Modify: `lib/saved/saved_place_repository.dart`(save가 버킷 id 저장)
- Test: `test/saved/saved_place_test.dart`(있으면 케이스 추가, 없으면 생성)

**Interfaces:**
- Produces: `PlaceCategory.fromId(String?)`; `SavedPlace.bucket` (getter, category를 PlaceCategory로 파싱). `save()`는 `category`에 `poi.bucket.name` 저장.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/saved/saved_place_test.dart`(없으면 생성):
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/saved/saved_place.dart';

void main() {
  test('category에 저장된 버킷 id를 PlaceCategory로 읽는다', () {
    final row = savedPlaceFromRow({
      'id': 's1', 'place_id': 'p1', 'name': 'x',
      'lat': 37.5, 'lng': 127.0, 'category': 'cafe', 'memo': null,
    });
    expect(row.bucket, PlaceCategory.cafe);
  });

  test('알 수 없는 category는 기타로 폴백', () {
    final row = savedPlaceFromRow({
      'id': 's2', 'place_id': 'p2', 'name': 'y',
      'lat': 37.5, 'lng': 127.0, 'category': '음식점', 'memo': null,
    });
    expect(row.bucket, PlaceCategory.other);
  });

  test('PlaceCategory.fromId', () {
    expect(PlaceCategory.fromId('bar'), PlaceCategory.bar);
    expect(PlaceCategory.fromId(null), PlaceCategory.other);
    expect(PlaceCategory.fromId('nope'), PlaceCategory.other);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/saved/saved_place_test.dart`
Expected: FAIL(`fromId`/`bucket` 없음).

- [ ] **Step 3: 구현**

(a) `lib/core/models/place_category.dart`에 static 추가:
```dart
  /// enum id(name)로 역매핑. 미지/누락은 기타.
  static PlaceCategory fromId(String? id) =>
      values.firstWhere((e) => e.name == id, orElse: () => PlaceCategory.other);
```
(b) `lib/saved/saved_place.dart`에 import + getter 추가:
```dart
import '../core/models/place_category.dart';
```
`SavedPlace` 클래스에:
```dart
  PlaceCategory get bucket => PlaceCategory.fromId(category);
```
(c) `lib/saved/saved_place_repository.dart`의 `save()`에서 `category: poi.category` 를 `category: poi.bucket.name` 으로 변경(버킷 id 저장).

- [ ] **Step 4: 통과 + 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter test`
Expected: 전건 PASS.

- [ ] **Step 5: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/core/models/place_category.dart lib/saved/saved_place.dart lib/saved/saved_place_repository.dart test/saved/saved_place_test.dart
git commit -m "feat: persist category bucket on save; SavedPlace.bucket"
```

---

### Task 5: 내 저장 뷰포트 오버레이(20곳 상한과 무관하게 항상 표시)

**Files:**
- Create: `lib/saved/saved_overlay.dart`
- Modify: `lib/ui/map_screen.dart`
- Test: `test/saved/saved_overlay_test.dart`

**Interfaces:**
- Consumes: `SavedPlace`(lat/lng/name/bucket/placeId), `GeoMath.distanceMeters`, `Poi`.
- Produces: `List<Poi> savedPoisInViewport(List<SavedPlace> saved, LatLng center, double radiusMeters)` — 반경 안의 내 저장을 `Poi`로 변환(bucket 포함, distance=중심 기준). MapScreen이 검색결과와 place_id로 dedupe 병합.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/saved/saved_overlay_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/saved/saved_place.dart';
import 'package:odagada/saved/saved_overlay.dart';

SavedPlace _s(String id, double lat, double lng, String cat) => SavedPlace(
    id: id, placeId: id, name: id, lat: lat, lng: lng, category: cat);

void main() {
  test('반경 안의 저장만 Poi로 변환(버킷·거리 포함)', () {
    final center = const LatLng(37.5, 127.0);
    final saved = [
      _s('near', 37.5008, 127.0, 'cafe'),   // ~89m
      _s('far', 37.6, 127.0, 'bar'),        // ~11km
    ];
    final pois = savedPoisInViewport(saved, center, 500);
    expect(pois.map((p) => p.id), ['near']);
    expect(pois.single.bucket, PlaceCategory.cafe);
    expect(pois.single.distanceMeters, greaterThan(0));
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/saved/saved_overlay_test.dart`
Expected: FAIL(파일 없음).

- [ ] **Step 3: 구현**

`lib/saved/saved_overlay.dart`:
```dart
import '../core/geo/geo_math.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import 'saved_place.dart';

/// 보이는 영역(중심·반경) 안의 내 저장 장소를 지도 핀용 Poi로 변환한다.
/// 뷰포트 검색 결과와 별개로 항상 오버레이되도록 하기 위함.
List<Poi> savedPoisInViewport(
    List<SavedPlace> saved, LatLng center, double radiusMeters) {
  final out = <Poi>[];
  for (final s in saved) {
    final pos = LatLng(s.lat, s.lng);
    final d = GeoMath.distanceMeters(center, pos);
    if (d > radiusMeters) continue;
    out.add(Poi(
      id: s.placeId ?? '${s.lat},${s.lng}',
      name: s.name,
      position: pos,
      category: s.bucket.label,
      bucket: s.bucket,
      distanceMeters: d,
    ));
  }
  return out;
}
```

- [ ] **Step 4: MapScreen 배선 — 전체 저장 로드 + 검색 병합**

`lib/ui/map_screen.dart`:
(a) import 추가: `import '../saved/saved_place.dart';`, `import '../saved/saved_overlay.dart';`
(b) 상태 추가: `List<SavedPlace> _savedPlaces = const [];` 그리고 마지막 검색 파라미터 보관용 `LatLng? _lastCenter; double? _lastRadius;`(오버레이 갱신에 재사용).
(c) `_reloadSaved`를 전체 목록 로드로 확장:
```dart
  Future<void> _reloadSaved() async {
    final u = widget.auth.user;
    if (u == null) {
      if (mounted) setState(() { _savedIds = {}; _savedPlaces = const []; });
      _map?.setSavedIds(const {});
      return;
    }
    final places = await widget.savedRepo.listMine(u.id);
    final ids = places.map((p) => p.placeId).whereType<String>().toSet();
    if (mounted) setState(() { _savedPlaces = places; _savedIds = ids; });
    _map?.setSavedIds(ids);
    // 저장이 바뀌면 현재 화면에 즉시 반영(마지막 검색 좌표로 재병합)
    final c = _lastCenter, r = _lastRadius;
    if (c != null && r != null) _runSearch(c, r);
  }
```
(d) `_runSearch`에서 검색결과에 내 저장(뷰포트) 병합(place_id dedupe):
```dart
  Future<void> _runSearch(LatLng center, double radiusMeters) async {
    _lastCenter = center;
    _lastRadius = radiusMeters;
    final gen = ++_searchGen;
    final pois = await _searcher.search(center, radiusMeters);
    if (!mounted || gen != _searchGen) return;
    final ids = pois.map((p) => p.id).toSet();
    final overlay = savedPoisInViewport(_savedPlaces, center, radiusMeters)
        .where((p) => !ids.contains(p.id)); // 검색결과에 이미 있으면 중복 제거
    final recs = [...pois, ...overlay]
        .map((p) => Recommendation(poi: p, score: 0))
        .toList();
    _map?.setPins(recs);
    _map?.setSavedIds(_savedIds);
  }
```
(주의: 기존 `_onCameraIdle`의 `_lastSearchCenter`/`_lastSearchRadius`(스킵 판정용)와 여기 `_lastCenter`/`_lastRadius`(오버레이 재병합용)는 별개 목적이다. 혼동 없게 둘 다 유지.)

- [ ] **Step 5: 통과 + 분석 + 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/saved/saved_overlay_test.dart && flutter test && flutter analyze`
Expected: 신규 테스트 PASS, 전건 green, analyze 신규 0.

- [ ] **Step 6: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/saved/saved_overlay.dart lib/ui/map_screen.dart test/saved/saved_overlay_test.dart
git commit -m "feat: always overlay my saved places in viewport (independent of 20-cap)"
```

---

## 온디바이스 검증(계획 완료 후, 실기기)
1. 핀 탭 → 카드에 **주소·전화·영업중/영업시간** 표시, **X 버튼**과 **지도 빈 곳 탭**으로 닫힘.
2. **FAB 토글**: 추적ON(강조)일 때 차 따라감 → 탭하면 탐색(회색), 지도 자유 이동 → 탭하면 다시 차로 복귀(추적). 손으로 지도 밀면 FAB가 탐색으로 바뀜.
3. **내 저장 오버레이**: 한 곳 저장 후 지도를 그 장소가 20곳 밖이 되게 이동/축소해도 **내 저장 핀은 계속 표시**되는지(북마크 배지). 저장-전용 핀도 카테고리 색/아이콘 맞는지.

## Self-Review 결과
- **Spec 커버리지:** §7.7 v2.0d(내저장 항상 오버레이/모드토글/카드 닫기+정보) → Task1(전화·영업), Task2(카드 정보+닫기), Task3(지도탭 닫기+모드토글), Task4(버킷 저장), Task5(오버레이). 평점 제외 준수. 친구 오버레이는 명시적으로 v2.1.
- **Placeholder 스캔:** 없음.
- **타입 일관성:** `Poi.openNow/weekdayHours`, `InfoCard.onClose`, `MapController.stopFollowing`, `MapViewBuilder(onMapTap,onFollowChanged)`, `PlaceCategory.fromId`, `SavedPlace.bucket`, `savedPoisInViewport(List<SavedPlace>,LatLng,double)→List<Poi>` — 태스크 간 일치. InfoCard `onClose` required가 MapScreen(Task3)·위젯테스트(Task2)에서 배선됨.
