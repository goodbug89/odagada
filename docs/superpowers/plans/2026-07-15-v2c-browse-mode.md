# v2.0c 브라우즈 모드(뷰포트 검색) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 핀 소스를 "차 GPS 주변"에서 "지도에 보이는 화면 영역"으로 바꿔, 지도를 움직이면 그 영역을 재검색해 최대 20곳을 표시한다(브라우즈 모드). 카메라는 차를 따라가되 사용자가 손대면 멈추고 `내 위치` 버튼으로 복귀한다.

**Architecture:** 기존 GPS→pipeline→RecommendEngine 랭킹 경로를 핀 소스에서 분리한다. 새 `ViewportSearcher`가 지도 중심·반경으로 Provider를 호출해 dedupe·거리순·상한20을 적용한다. `GoogleMapView`는 `onCameraIdle`에서 보이는 영역(중심·반경)을 계산해 콜백하고, 차 따라가기(`setCar`)/복귀(`recenter`)와 "손대면 멈춤"을 담당한다. `MapScreen`은 GPS 스트림으로 차 위치만 받아 카메라 팔로우에 쓰고, 카메라 정지 이벤트를 디바운스해 `ViewportSearcher`로 핀을 갱신한다.

**Tech Stack:** Flutter 3.44.6 / Dart, `google_maps_flutter ^2.17.1`(`GoogleMapController.getVisibleRegion()`, `onCameraIdle`), 기존 `GooglePlacesProvider`.

## Global Constraints

- **저장소:** `/Users/goodbug/dev/odagada`, 브랜치 `feature/v2b-save`(현재 작업 브랜치)에서 이어간다. 새 브랜치 만들지 않는다.
- **Flutter:** `/opt/homebrew/bin`. 없으면 `export PATH="/opt/homebrew/bin:$PATH"`. 패키지명 `odagada`.
- **테스트:** 기존 47개 회귀 유지. 순수 로직은 TDD. `flutter analyze`는 이 변경으로 **신규 이슈 0**(기존 info 3건은 무관: `saved_list_screen.dart:56`, `maps_loader_web.dart:2`×2).
- **상한:** Places Nearby는 호출당 최대 20곳 → `ViewportSearcher` cap=20.
- **검색 트리거:** `onCameraIdle` → 400ms 디바운스 → 직전 검색 중심에서 30m 이상 이동했을 때만 재검색.
- **카메라:** 기본 차 따라가기. 사용자 제스처 이동이면 따라가기 해제. `내 위치` FAB로 복귀.
- **includedTypes:** v2.0b-2에서 넓힌 7종 세트를 그대로 사용(변경 없음).

## 결정 (확정)

1. **랭킹 제외:** 브라우즈에선 전방/거리 가점 랭킹을 쓰지 않고 보이는 영역의 장소를 거리순 dedupe해 그대로 표시. `RecommendEngine`/`RecommendationPipeline` 클래스와 그 단위테스트는 **삭제하지 않고 보존**(향후 주행 추천용). 단 `MapScreen`/`app.dart`는 더 이상 이들을 핀 소스로 쓰지 않는다.
2. **거리 표시:** Provider가 계산하는 `distanceMeters`는 검색 중심(지도 중심) 기준. 따라가는 동안 중심≈차라 "내게서의 거리"와 사실상 같다. 별도 재계산 없음(단순화).
3. **반경:** 보이는 영역(`getVisibleRegion`)의 중심에서 북동 코너까지 거리 → 뷰포트를 덮는 원. `[200, 50000]m`로 clamp.

---

### Task 1: ViewportSearcher (뷰포트 검색·dedupe·상한)

**Files:**
- Create: `lib/poi/viewport_searcher.dart`
- Test: `test/poi/viewport_searcher_test.dart`

**Interfaces:**
- Consumes: `ProviderRegistry`(`registry.all` → `List<PoiProvider>`), `PoiProvider.nearby(LocationEvent, {radiusMeters})`.
- Produces: `class ViewportSearcher { ViewportSearcher(ProviderRegistry registry, {int cap = 20}); Future<List<Poi>> search(LatLng center, double radiusMeters); }` — 활성 Provider들을 중심·반경으로 병렬 호출, 개별 실패는 빈 리스트, place id로 dedupe, `distanceMeters` 오름차순 정렬, 앞에서 `cap`개.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/poi/viewport_searcher_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/poi/poi_provider.dart';
import 'package:odagada/poi/viewport_searcher.dart';

Poi _poi(String id, double dist) => Poi(
      id: id, name: id, position: const LatLng(37.5, 127.0),
      category: 'x', distanceMeters: dist,
    );

class _FakeProvider implements PoiProvider {
  final List<Poi> result;
  final bool throwing;
  _FakeProvider(this.result, {this.throwing = false});
  @override
  String get id => 'fake';
  @override
  String get displayName => 'fake';
  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async {
    if (throwing) throw Exception('boom');
    return result;
  }
}

void main() {
  test('여러 Provider 결과를 합치고 id로 dedupe, 거리순 정렬', () async {
    final reg = ProviderRegistry()
      ..register(_FakeProvider([_poi('a', 300), _poi('b', 100)]))
      ..register(_FakeProvider([_poi('b', 100), _poi('c', 200)])); // b 중복
    final pois = await ViewportSearcher(reg).search(const LatLng(37.5, 127.0), 500);
    expect(pois.map((p) => p.id).toList(), ['b', 'c', 'a']); // 100,200,300
  });

  test('cap으로 개수 제한(거리순 앞에서)', () async {
    final reg = ProviderRegistry()
      ..register(_FakeProvider([_poi('a', 10), _poi('b', 20), _poi('c', 30)]));
    final pois = await ViewportSearcher(reg, cap: 2).search(const LatLng(37.5, 127.0), 500);
    expect(pois.map((p) => p.id).toList(), ['a', 'b']);
  });

  test('한 Provider가 실패해도 나머지 결과는 반환', () async {
    final reg = ProviderRegistry()
      ..register(_FakeProvider([], throwing: true))
      ..register(_FakeProvider([_poi('a', 10)]));
    final pois = await ViewportSearcher(reg).search(const LatLng(37.5, 127.0), 500);
    expect(pois.map((p) => p.id).toList(), ['a']);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/poi/viewport_searcher_test.dart`
Expected: FAIL — `viewport_searcher.dart` 없음.

- [ ] **Step 3: 구현**

`lib/poi/viewport_searcher.dart`:
```dart
import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import 'poi_provider.dart';

/// 지도에 보이는 영역(중심·반경)으로 활성 Provider를 병렬 호출해
/// dedupe·거리순·상한을 적용하는 브라우즈 검색기.
class ViewportSearcher {
  final ProviderRegistry registry;
  final int cap;
  ViewportSearcher(this.registry, {this.cap = 20});

  Future<List<Poi>> search(LatLng center, double radiusMeters) async {
    final loc = LocationEvent(
      position: center,
      headingDeg: -1,
      speedMps: 0,
      timestamp: DateTime.now(),
    );
    final lists = await Future.wait(registry.all.map((p) async {
      try {
        return await p.nearby(loc, radiusMeters: radiusMeters);
      } catch (_) {
        return <Poi>[];
      }
    }));
    final byId = <String, Poi>{};
    for (final list in lists) {
      for (final p in list) {
        byId[p.id] = p;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return merged.take(cap).toList();
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/poi/viewport_searcher_test.dart`
Expected: PASS (3건).

- [ ] **Step 5: 커밋**

```bash
cd /Users/goodbug/dev/odagada
git add lib/poi/viewport_searcher.dart test/poi/viewport_searcher_test.dart
git commit -m "feat: add ViewportSearcher (dedupe + distance sort + cap 20)"
```

---

### Task 2: 지도 인터페이스 + GoogleMapView 브라우즈 배선

**Files:**
- Modify: `lib/ui/map_view.dart`(MapController + MapViewBuilder)
- Modify: `lib/ui/google_map_view.dart`
- Modify: `lib/ui/kakao_map_view.dart`(레거시 no-op)

**Interfaces:**
- Consumes: `GeoMath.distanceMeters(LatLng, LatLng)`(중심→코너 반경), `gmap.GoogleMapController.getVisibleRegion()`.
- Produces:
  - `MapViewBuilder`에 `required void Function(LatLng center, double radiusMeters) onCameraIdle` 추가.
  - `MapController`: `moveCamera(LatLng)` 제거, `void setCar(LatLng car)`(차 위치 갱신; 따라가는 중이면 카메라 이동) + `void recenter()`(따라가기 재개+차로 이동) 추가. 기존 `setPins`/`setSavedIds` 유지.

- [ ] **Step 1: MapController + 빌더 타입 변경**

`lib/ui/map_view.dart`:
```dart
import 'package:flutter/widgets.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';

/// 지도 구현을 로직에서 분리하기 위한 컨트롤러 인터페이스.
abstract class MapController {
  /// 차(GPS) 위치 갱신. 따라가는 중이면 카메라가 이 위치로 이동.
  void setCar(LatLng car);

  /// 따라가기를 재개하고 차 위치로 카메라 복귀('내 위치' 버튼).
  void recenter();

  void setPins(List<Recommendation> recs);
  void setSavedIds(Set<String> ids);
}

/// 핀 탭 콜백 시그니처.
typedef PinTapCallback = void Function(Poi poi);

/// 지도 위젯을 만들어주는 빌더. 플랫폼별 구현(카카오/구글)을 MapScreen에서 분리한다.
typedef MapViewBuilder = Widget Function({
  required void Function(MapController) onReady,
  required PinTapCallback onPinTap,
  required void Function(LatLng center, double radiusMeters) onCameraIdle,
});
```

- [ ] **Step 2: KakaoMapView(레거시) 시그니처 맞추기**

`lib/ui/kakao_map_view.dart`의 `_KakaoMapViewState`(현재 `moveCamera(LatLng)` @override 존재, `setPins`/`setSavedIds`는 유지)에서 **`moveCamera` 메서드를 삭제**하고 그 자리에 no-op 2종을 둔다:
```dart
  @override
  void setCar(LatLng car) {} // 레거시(구글로 전환됨) — 미사용
  @override
  void recenter() {} // 레거시 — 미사용
```
`KakaoMapView` 위젯 생성자는 그대로 둔다(이 위젯은 앱 어디서도 생성되지 않으므로 `onCameraIdle` 파라미터 불필요 — MapController 인터페이스만 만족하면 됨). `LatLng` import가 있는지 확인.

- [ ] **Step 3: GoogleMapView — 위젯에 onCameraIdle 추가, 따라가기/복귀/뷰포트 계산 구현**

`lib/ui/google_map_view.dart`:

(a) import에 `GeoMath` 추가:
```dart
import '../core/geo/geo_math.dart';
```

(b) 위젯 생성자에 콜백 추가:
```dart
class GoogleMapView extends StatefulWidget {
  final void Function(MapController controller) onReady;
  final PinTapCallback onPinTap;
  final void Function(LatLng center, double radiusMeters) onCameraIdle;
  const GoogleMapView({
    super.key,
    required this.onReady,
    required this.onPinTap,
    required this.onCameraIdle,
  });
  ...
}
```

(c) State에 따라가기 상태 필드 추가(`_camZoom` 아래):
```dart
  gmap.LatLng? _car;          // 최근 차 위치
  bool _following = true;      // 차 따라가기 여부
  bool _programmaticMove = false; // 우리가 animateCamera로 움직이는 중(제스처와 구분)
```

(d) `moveCamera`를 제거하고 `setCar`/`recenter`/내부 `_animateTo` 구현:
```dart
  @override
  void setCar(LatLng car) {
    _car = gmap.LatLng(car.lat, car.lng);
    if (_following) _animateTo(_car!);
  }

  @override
  void recenter() {
    _following = true;
    if (_car != null) _animateTo(_car!);
  }

  void _animateTo(gmap.LatLng pos) {
    _programmaticMove = true; // 이어지는 onCameraMoveStarted는 우리 이동
    _controller?.animateCamera(gmap.CameraUpdate.newLatLng(pos));
  }
```

(e) `GoogleMap`에 콜백 3종 배선(기존 `onCameraMove`/`onMapCreated` 옆):
```dart
              onCameraMoveStarted: () {
                // 우리 이동이 아니면 사용자가 손댄 것 → 따라가기 해제
                if (!_programmaticMove) _following = false;
              },
              onCameraMove: (pos) {
                setState(() {
                  _camTarget = pos.target;
                  _camZoom = pos.zoom;
                });
              },
              onCameraIdle: _handleCameraIdle,
```

(f) 뷰포트 중심·반경 계산 후 콜백:
```dart
  Future<void> _handleCameraIdle() async {
    _programmaticMove = false; // 이동 종료
    final c = _controller;
    if (c == null) return;
    final region = await c.getVisibleRegion();
    final ne = region.northeast;
    final sw = region.southwest;
    final center = LatLng((ne.latitude + sw.latitude) / 2,
        (ne.longitude + sw.longitude) / 2);
    final radius = GeoMath.distanceMeters(
            center, LatLng(ne.latitude, ne.longitude))
        .clamp(200.0, 50000.0);
    widget.onCameraIdle(center, radius);
  }
```

(g) `_buildPins`·`_screenOf`·`_project`는 그대로 둔다(핀은 여전히 `_recs`로 그린다). `moveCamera` 참조가 사라졌는지 확인.

- [ ] **Step 4: 정적 분석**

Run: `cd /Users/goodbug/dev/odagada && flutter analyze`
Expected: 신규 이슈 0(기존 3건 info 외 없음). `moveCamera` 미정의/미사용 에러 없음.

- [ ] **Step 5: 전체 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter test`
Expected: 47건 유지(플랫폼 뷰라 이 파일 위젯테스트 없음 — Task 3 배선 후 온디바이스 검증).

- [ ] **Step 6: 커밋**

```bash
cd /Users/goodbug/dev/odagada
git add lib/ui/map_view.dart lib/ui/google_map_view.dart lib/ui/kakao_map_view.dart
git commit -m "feat: GoogleMapView browse plumbing (onCameraIdle viewport, follow-until-pan, setCar/recenter)"
```

---

### Task 3: MapScreen 뷰포트 검색 배선 + '내 위치' FAB + app.dart

**Files:**
- Modify: `lib/ui/map_screen.dart`
- Modify: `lib/app.dart`

**Interfaces:**
- Consumes: `ViewportSearcher.search`(Task 1), `MapController.setCar/recenter`(Task 2), `MapViewBuilder`의 `onCameraIdle`(Task 2), `LocationSource.stream()`(`RawFix.position`).

- [ ] **Step 1: MapScreen 재작성 — 파이프라인 제거, GPS로 차 위치, 카메라 정지 시 뷰포트 검색**

`lib/ui/map_screen.dart` 전체를 아래로 교체:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../location/location_source.dart';
import '../poi/poi_provider.dart';
import '../poi/viewport_searcher.dart';
import '../saved/saved_place_repository.dart';
import 'account_button.dart';
import 'map_view.dart';
import 'info_card.dart';
import 'login_sheet.dart';
import 'module_selector.dart';
import 'navigation_launcher.dart';
import 'saved_list_screen.dart';

class MapScreen extends StatefulWidget {
  final AuthController auth;
  final LocationSource locationSource;
  final ProviderRegistry registry;
  final NavigationLauncher navigationLauncher;
  final MapViewBuilder mapBuilder;
  final SavedPlaceRepository savedRepo;

  const MapScreen({
    super.key,
    required this.auth,
    required this.locationSource,
    required this.registry,
    required this.navigationLauncher,
    required this.mapBuilder,
    required this.savedRepo,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _map;
  StreamSubscription? _sub;
  Poi? _selected;
  String? _error;
  Set<String> _savedIds = {};
  late final ViewportSearcher _searcher = ViewportSearcher(widget.registry);

  Timer? _idleDebounce;
  LatLng? _lastSearchCenter;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await widget.locationSource.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '위치 권한이 필요합니다. 설정에서 허용해 주세요.');
      return;
    }
    // GPS는 차 위치(카메라 따라가기)용으로만 사용. 핀은 지도 뷰포트 검색으로 채운다.
    _sub = widget.locationSource.stream().listen((fix) {
      _map?.setCar(LatLng(fix.position.lat, fix.position.lng));
    });
    await _reloadSaved();
  }

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

  // 카메라 정지 → 디바운스 → 중심 30m 이상 이동했을 때만 뷰포트 검색.
  void _onCameraIdle(LatLng center, double radiusMeters) {
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 400), () {
      final last = _lastSearchCenter;
      if (last != null) {
        // GeoMath 없이 대략 이동 판단: 위경도 → m 근사(위도 111km/deg)
        final dLat = (center.lat - last.lat).abs() * 111000;
        final dLng = (center.lng - last.lng).abs() * 88000; // ~cos(37.5)*111km
        if (dLat < 30 && dLng < 30) return; // 거의 안 움직임 → 스킵
      }
      _lastSearchCenter = center;
      _runSearch(center, radiusMeters);
    });
  }

  Future<void> _runSearch(LatLng center, double radiusMeters) async {
    final pois = await _searcher.search(center, radiusMeters);
    if (!mounted) return;
    final recs = pois.map((p) => Recommendation(poi: p, score: 0)).toList();
    _map?.setPins(recs);
    _map?.setSavedIds(_savedIds);
  }

  Future<void> _onSaveToggle(Poi poi) async {
    final u = widget.auth.user;
    if (u == null) {
      showLoginSheet(context, onGoogle: widget.auth.signInWithGoogle);
      return;
    }
    if (_savedIds.contains(poi.id)) {
      await widget.savedRepo.deleteByPlaceId(ownerId: u.id, placeId: poi.id);
    } else {
      await widget.savedRepo.save(ownerId: u.id, poi: poi);
    }
    await _reloadSaved();
  }

  void _onPinTap(Poi poi) => setState(() => _selected = poi);

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('오다가다'),
        actions: [
          AccountButton(auth: widget.auth),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            tooltip: '내 저장',
            onPressed: () {
              final u = widget.auth.user;
              if (u == null) {
                showLoginSheet(context, onGoogle: widget.auth.signInWithGoogle);
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    SavedListScreen(repo: widget.savedRepo, ownerId: u.id),
              ));
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ModuleSelector(registry: widget.registry),
            )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '내 위치',
        onPressed: () => _map?.recenter(),
        child: const Icon(Icons.my_location),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.mapBuilder(
              onReady: (c) {
                _map = c;
                _map?.setSavedIds(_savedIds);
              },
              onPinTap: _onPinTap,
              onCameraIdle: _onCameraIdle,
            ),
          ),
          if (_selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: InfoCard(
                poi: _selected!,
                onNavigate: () => widget.navigationLauncher.launch(_selected!),
                isSaved: _savedIds.contains(_selected!.id),
                onSave: () => _onSaveToggle(_selected!),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: app.dart — pipeline 제거, mapBuilder에 onCameraIdle 배선**

`lib/app.dart`:

(a) 미사용 import 제거: `location/location_engine.dart`, `pipeline/recommendation_pipeline.dart`, `recommend/recommend_engine.dart`.

(b) `pipeline` 생성 블록(라인 50-54) 삭제.

(c) `mapBuilder`가 `onCameraIdle`를 받아 넘기도록 교체:
```dart
    Widget mapBuilder({
      required void Function(MapController) onReady,
      required PinTapCallback onPinTap,
      required void Function(LatLng center, double radiusMeters) onCameraIdle,
    }) =>
        GoogleMapView(
          onReady: onReady,
          onPinTap: onPinTap,
          onCameraIdle: onCameraIdle,
        );
```
그리고 상단에 `import 'core/models/lat_lng.dart';` 추가(타입 `LatLng`).

(d) `MapScreen(...)` 생성에서 `pipeline: pipeline,` 인자 제거.

- [ ] **Step 3: 정적 분석 + 전체 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter analyze && flutter test`
Expected: analyze 신규 0(기존 3건 info 외 없음 — 특히 `recommendation_pipeline`/`recommend_engine` 미사용 import 잔존 없게), 테스트 47건 유지(파이프라인/엔진 단위테스트는 클래스 보존이라 그대로 통과).

- [ ] **Step 4: 커밋**

```bash
cd /Users/goodbug/dev/odagada
git add lib/ui/map_screen.dart lib/app.dart
git commit -m "feat: browse-mode viewport search in MapScreen + my-location FAB"
```

---

## 온디바이스 검증(계획 완료 후, 실기기)

지도·카메라는 플랫폼 뷰라 위젯테스트가 어렵다 — 실기기로 확인한다:
1. `flutter run -d <device>`.
2. 앱 시작 시 차 위치 주변 최대 20곳이 카테고리색 아이콘+이름으로 뜨는지.
3. **지도를 손으로 패닝** → 손댄 순간 따라가기 멈추고, 멈춘 뒤 그 영역의 장소로 핀이 갱신되는지.
4. **확대** → 더 좁은 영역을 촘촘히(그 영역 20곳) 보여주는지.
5. **`내 위치` FAB** → 차 위치로 복귀하고 따라가기 재개되는지.
6. 저장→SavedPin, 정보카드 카테고리 등 v2.0b-2 동작 회귀 없는지.
7. 밀집 지역(예: 가산)에서 겹침이 줄고(확대 시) 다양한 색이 보이는지.

## Self-Review 결과

- **Spec 커버리지:** §7.7 v2.0c 브라우즈 모드 → Task 1(뷰포트 검색·상한20·dedupe), Task 2(onCameraIdle 뷰포트 계산·따라가다 손대면 멈춤·recenter), Task 3(GPS→차위치, 디바운스 검색, 내 위치 FAB, 랭킹/파이프라인 핀소스 제외). 결정 #1(클래스 보존) 반영.
- **Placeholder 스캔:** 없음(모든 스텝 실제 코드/명령/기대값).
- **타입 일관성:** `ViewportSearcher(registry,{cap}).search(LatLng,double)→Future<List<Poi>>`, `MapController.setCar(LatLng)/recenter()`, `MapViewBuilder(...onCameraIdle: void Function(LatLng,double))` — Task 간 시그니처 일치. `moveCamera` 제거를 Task 2에서 인터페이스·양 구현체·app.dart(Task 3) 모두 반영.
