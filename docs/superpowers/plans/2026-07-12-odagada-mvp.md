# 오다가다 (Odagada) MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 운전 중 차량의 실시간 위치를 기준으로 주변 맛집을 지도 핀으로 자동 추천하는 Flutter 앱(MVP)을 만든다.

**Architecture:** `Location Engine → POI Provider → Recommend Engine → Map UI` 순수-로직 중심 파이프라인. GPS/네트워크에 의존하는 부분(위치 소스, 카카오 API, 지도)은 어댑터로 격리하고, 거리 스로틀·랭킹·중복억제 같은 핵심 로직은 순수 함수/클래스로 두어 모의 데이터로 단위 테스트한다. 맛집(RestaurantProvider)은 공통 `PoiProvider` 인터페이스의 첫 구현체이며, 부동산·골프 모듈은 동일 인터페이스로 나중에 추가한다.

**Tech Stack:** Flutter (Dart), `geolocator`(GPS), `http`(카카오 로컬 REST API), `flutter_dotenv`(API 키), `webview_flutter`(카카오맵 JS SDK), `url_launcher`(길찾기 딥링크), `mocktail`(테스트).

## Global Constraints

- 앱/코드네임: **오다가다 (Odagada)**. 패키지·번들 ID: `com.odagada.app`.
- 저장소: `~/dev/odagada` (git repo, OneDrive 밖). **모든 경로는 이 저장소 루트 기준.**
- MVP 모듈은 **맛집(RestaurantProvider) 1종만**. Provider/Recommendation 인터페이스는 다중 모듈 대비해 구현하되 구현체는 맛집 하나.
- 카카오 로컬 API: 엔드포인트 `https://dapi.kakao.com/v2/local/search/category.json`, 음식점 카테고리 코드 `FD6`, 헤더 `Authorization: KakaoAK {REST_API_KEY}`. **평점 필드는 응답에 없음** → 랭킹은 거리·진행방향 위주, 평점은 없으면 0으로 처리.
- API 키는 **절대 커밋 금지**. `.env`로 주입(`.gitignore`에 이미 `.env` 포함). 코드에는 하드코딩 금지.
- 운전 중 안전: 자동 모달·연쇄 팝업 금지, 상호작용은 조작 불필요(핀 자동 갱신)를 기본으로. 상세는 탭 시에만.
- 거리 스로틀 기본값 **200m**, 전방 부채꼴 기본 **±60°** — 상수로 두고 한곳에서 조정 가능하게.
- 순수 로직(Location Engine, Recommend Engine, geo math)은 Flutter/플랫폼 의존 없이 단위 테스트. `flutter test`로 전부 통과해야 함.
- 참고 설계 문서: `docs/superpowers/specs/2026-07-12-matjip-driving-recommender-design.md`.

---

## File Structure

```
lib/
  main.dart                          # 앱 진입점, .env 로드, MapScreen 실행
  app.dart                           # MaterialApp 루트
  config/
    app_config.dart                  # .env에서 카카오 키 읽기
  core/
    models/
      lat_lng.dart                   # 좌표 값 객체
      location_event.dart            # 위치+속도+방위각 이벤트
      poi.dart                       # 공통 POI 모델
      recommendation.dart            # 랭킹된 추천 결과
    geo/
      geo_math.dart                  # 거리(하버사인)/방위각/각도차 순수 함수
  location/
    raw_fix.dart                     # 원시 GPS 픽스(위도·경도·속도·시각)
    location_source.dart             # geolocator 어댑터 → Stream<RawFix>
    location_engine.dart             # 순수: RawFix 스트림 → LocationEvent(거리 스로틀/주행판별)
  poi/
    poi_provider.dart                # 추상 인터페이스 + registry
    kakao_client.dart                # 카카오 REST http 래퍼(주입식 http.Client)
    restaurant_provider.dart         # 카카오 FD6 구현체
  recommend/
    recommend_engine.dart            # 순수: 후보 POI → 랭킹/필터/중복억제
  pipeline/
    recommendation_pipeline.dart     # 위치→Provider→Engine 배선, Stream<List<Recommendation>>
  ui/
    map_screen.dart                  # 파이프라인 구독 + 지도/카드/모듈선택 조립
    map_view.dart                    # 지도 추상 인터페이스(핀 갱신/카메라 팔로우/탭콜백)
    kakao_map_view.dart              # webview_flutter + 카카오맵 JS SDK 구현
    info_card.dart                   # 핀 탭 시 하단 정보 카드
    navigation_launcher.dart         # 카카오맵/내비 길찾기 딥링크
    module_selector.dart             # 활성 모듈 선택(맛집만 노출)
assets/
  kakao_map.html                     # 카카오맵 JS SDK 로드용 HTML
test/
  core/geo/geo_math_test.dart
  location/location_engine_test.dart
  poi/restaurant_provider_test.dart
  recommend/recommend_engine_test.dart
  pipeline/recommendation_pipeline_test.dart
  ui/info_card_test.dart
```

---

## Task 0: 개발 환경 & Flutter 프로젝트 스캐폴드

**Files:**
- Create: `pubspec.yaml` (flutter create가 생성 후 의존성 추가)
- Create: `.env.example`
- Create: `lib/config/app_config.dart`
- Modify: `.gitignore` (필요 시 확인)

**Interfaces:**
- Produces: `AppConfig.kakaoRestApiKey` (String), `AppConfig.kakaoJsAppKey` (String), `AppConfig.load()` (Future<void>).

- [ ] **Step 1: Flutter SDK 설치 확인/설치**

Run:
```bash
flutter --version
```
설치돼 있으면 다음 단계로. 없으면 설치:
```bash
brew install --cask flutter   # macOS. 또는 https://docs.flutter.dev/get-started/install
flutter doctor                # Android toolchain / Xcode 상태 확인
```
Expected: `flutter --version`이 3.x 이상 버전을 출력. `flutter doctor`에서 iOS(Xcode) 또는 Android 중 최소 하나가 ✓.

- [ ] **Step 2: 기존 repo 루트에 Flutter 프로젝트 생성**

저장소에는 이미 `docs/`와 `.gitignore`가 있으므로 현재 디렉터리에 생성한다.
Run:
```bash
cd ~/dev/odagada
flutter create --org com.odagada --project-name odagada --platforms=ios,android .
```
Expected: `lib/main.dart`, `pubspec.yaml`, `ios/`, `android/` 생성. 기존 `docs/`, `.gitignore`는 보존됨.

- [ ] **Step 3: 의존성 추가**

Run:
```bash
cd ~/dev/odagada
flutter pub add geolocator http flutter_dotenv webview_flutter url_launcher
flutter pub add --dev mocktail
```
Expected: `pubspec.yaml`의 `dependencies:`에 5개, `dev_dependencies:`에 `mocktail` 추가.

- [ ] **Step 4: `.env.example` 작성 (실제 `.env`는 커밋 안 함)**

Create `.env.example`:
```
# 카카오 개발자 콘솔(https://developers.kakao.com) 앱 > 앱 키
KAKAO_REST_API_KEY=여기에_REST_API_키
KAKAO_JS_APP_KEY=여기에_JavaScript_키
```
그리고 실제 키로 로컬 `.env` 생성(커밋 금지):
```bash
cp .env.example .env   # 후 편집기로 실제 키 입력
```

- [ ] **Step 5: `pubspec.yaml`에 assets/.env 등록**

`pubspec.yaml`의 `flutter:` 섹션 아래에 추가:
```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
    - assets/kakao_map.html
```

- [ ] **Step 6: `AppConfig` 작성**

Create `lib/config/app_config.dart`:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env에서 카카오 키를 읽어 앱 전역에 노출한다.
class AppConfig {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get kakaoRestApiKey {
    final key = dotenv.env['KAKAO_REST_API_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('KAKAO_REST_API_KEY가 .env에 없습니다.');
    }
    return key;
  }

  static String get kakaoJsAppKey {
    final key = dotenv.env['KAKAO_JS_APP_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('KAKAO_JS_APP_KEY가 .env에 없습니다.');
    }
    return key;
  }
}
```

- [ ] **Step 7: 위치 권한 네이티브 설정**

`ios/Runner/Info.plist`의 `<dict>` 안에 추가:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>주행 중 주변 맛집을 추천하기 위해 위치를 사용합니다.</string>
```
`android/app/src/main/AndroidManifest.xml`의 `<manifest>` 안(application 태그 밖)에 추가:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

- [ ] **Step 8: 빌드 확인 후 커밋**

Run:
```bash
cd ~/dev/odagada
flutter analyze
git add -A
git commit -m "chore: Flutter 프로젝트 스캐폴드 + 의존성 + AppConfig"
```
Expected: `flutter analyze`가 에러 없이 통과(기본 생성 코드 기준). `.env`는 커밋되지 않음(`.gitignore`).

---

## Task 1: 코어 모델 + geo 순수 함수

**Files:**
- Create: `lib/core/models/lat_lng.dart`
- Create: `lib/core/models/location_event.dart`
- Create: `lib/core/models/poi.dart`
- Create: `lib/core/models/recommendation.dart`
- Create: `lib/core/geo/geo_math.dart`
- Test: `test/core/geo/geo_math_test.dart`

**Interfaces:**
- Produces:
  - `LatLng(double lat, double lng)`
  - `LocationEvent({LatLng position, double headingDeg, double speedMps, DateTime timestamp})`
  - `Poi({String id, String name, LatLng position, String category, String? address, String? phone, String? placeUrl, double distanceMeters, double rating})`
  - `Recommendation({Poi poi, double score})`
  - `GeoMath.distanceMeters(LatLng a, LatLng b) -> double`
  - `GeoMath.bearingDeg(LatLng from, LatLng to) -> double` (0~360, 정북 0)
  - `GeoMath.angularDifferenceDeg(double a, double b) -> double` (0~180)

- [ ] **Step 1: geo 함수 실패 테스트 작성**

Create `test/core/geo/geo_math_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/geo/geo_math.dart';

void main() {
  group('distanceMeters', () {
    test('같은 지점은 0m', () {
      final p = LatLng(37.5665, 126.9780);
      expect(GeoMath.distanceMeters(p, p), closeTo(0, 0.5));
    });

    test('서울시청~강남역 약 8~9km', () {
      final cityHall = LatLng(37.5663, 126.9779);
      final gangnam = LatLng(37.4979, 127.0276);
      final d = GeoMath.distanceMeters(cityHall, gangnam);
      expect(d, closeTo(8300, 800));
    });
  });

  group('bearingDeg', () {
    test('정북 방향은 0도 근처', () {
      final from = LatLng(37.50, 127.00);
      final north = LatLng(37.51, 127.00);
      expect(GeoMath.bearingDeg(from, north), closeTo(0, 1));
    });

    test('정동 방향은 90도 근처', () {
      final from = LatLng(37.50, 127.00);
      final east = LatLng(37.50, 127.01);
      expect(GeoMath.bearingDeg(from, east), closeTo(90, 1));
    });
  });

  group('angularDifferenceDeg', () {
    test('10도와 350도의 차이는 20도', () {
      expect(GeoMath.angularDifferenceDeg(10, 350), closeTo(20, 0.001));
    });
    test('0도와 180도의 차이는 180도', () {
      expect(GeoMath.angularDifferenceDeg(0, 180), closeTo(180, 0.001));
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/core/geo/geo_math_test.dart`
Expected: FAIL — `lat_lng.dart`/`geo_math.dart` 미존재로 컴파일 에러.

- [ ] **Step 3: 모델 작성**

Create `lib/core/models/lat_lng.dart`:
```dart
class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);

  @override
  bool operator ==(Object other) =>
      other is LatLng && other.lat == lat && other.lng == lng;
  @override
  int get hashCode => Object.hash(lat, lng);
}
```

Create `lib/core/models/location_event.dart`:
```dart
import 'lat_lng.dart';

/// 거리 스로틀을 통과한, 앱이 실제로 사용하는 위치 이벤트.
class LocationEvent {
  final LatLng position;
  final double headingDeg; // 진행 방향(0~360, 정북 0). 미상이면 -1.
  final double speedMps;   // m/s
  final DateTime timestamp;

  const LocationEvent({
    required this.position,
    required this.headingDeg,
    required this.speedMps,
    required this.timestamp,
  });

  bool get isMoving => speedMps >= 1.5; // 약 5.4km/h 이상이면 주행으로 간주
}
```

Create `lib/core/models/poi.dart`:
```dart
import 'lat_lng.dart';

/// 모든 Provider가 공통으로 반환하는 관심지점.
class Poi {
  final String id;
  final String name;
  final LatLng position;
  final String category;
  final String? address;
  final String? phone;
  final String? placeUrl;
  final double distanceMeters; // 조회 기준점으로부터 거리
  final double rating;         // 평점 없으면 0

  const Poi({
    required this.id,
    required this.name,
    required this.position,
    required this.category,
    this.address,
    this.phone,
    this.placeUrl,
    required this.distanceMeters,
    this.rating = 0,
  });
}
```

Create `lib/core/models/recommendation.dart`:
```dart
import 'poi.dart';

class Recommendation {
  final Poi poi;
  final double score;
  const Recommendation({required this.poi, required this.score});
}
```

- [ ] **Step 4: geo_math 작성**

Create `lib/core/geo/geo_math.dart`:
```dart
import 'dart:math' as math;
import '../models/lat_lng.dart';

class GeoMath {
  static const double _earthRadiusM = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  /// 두 좌표 간 대권 거리(미터). 하버사인.
  static double distanceMeters(LatLng a, LatLng b) {
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final la1 = _rad(a.lat);
    final la2 = _rad(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// from에서 to를 바라보는 방위각(0~360, 정북 0, 시계방향).
  static double bearingDeg(LatLng from, LatLng to) {
    final la1 = _rad(from.lat);
    final la2 = _rad(to.lat);
    final dLng = _rad(to.lng - from.lng);
    final y = math.sin(dLng) * math.cos(la2);
    final x = math.cos(la1) * math.sin(la2) -
        math.sin(la1) * math.cos(la2) * math.cos(dLng);
    final brng = _deg(math.atan2(y, x));
    return (brng + 360) % 360;
  }

  /// 두 방위각의 최소 각도차(0~180).
  static double angularDifferenceDeg(double a, double b) {
    var diff = (a - b).abs() % 360;
    if (diff > 180) diff = 360 - diff;
    return diff;
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/core/geo/geo_math_test.dart`
Expected: PASS (모든 테스트).

- [ ] **Step 6: 커밋**

```bash
git add lib/core test/core
git commit -m "feat: 코어 모델(LatLng/LocationEvent/Poi/Recommendation) + geo 순수 함수"
```

---

## Task 2: Location Engine (거리 스로틀 + 주행 판별, 순수 로직)

**Files:**
- Create: `lib/location/raw_fix.dart`
- Create: `lib/location/location_engine.dart`
- Test: `test/location/location_engine_test.dart`

**Interfaces:**
- Consumes: `LatLng`, `LocationEvent`, `GeoMath.distanceMeters`.
- Produces:
  - `RawFix({LatLng position, double speedMps, double? headingDeg, DateTime timestamp})`
  - `LocationEngine({double minMoveMeters = 200})` with `Stream<LocationEvent> process(Stream<RawFix> fixes)`.
  - 규칙: 첫 픽스는 항상 방출. 이후 직전 방출 위치에서 `minMoveMeters` 이상 이동해야 방출. heading이 null이면 직전 방출 위치→현재 위치의 bearing으로 보정(이동거리 0이면 -1).

- [ ] **Step 1: 실패 테스트 작성**

Create `test/location/location_engine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/location/raw_fix.dart';
import 'package:odagada/location/location_engine.dart';

RawFix fix(double lat, double lng, {double speed = 10, double? heading}) =>
    RawFix(
      position: LatLng(lat, lng),
      speedMps: speed,
      headingDeg: heading,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

void main() {
  test('첫 픽스는 즉시 방출된다', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    final out = await engine.process(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out.length, 1);
    expect(out.first.position, LatLng(37.5, 127.0));
  });

  test('200m 미만 이동은 방출하지 않는다', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    // 약 11m 떨어진 두 점
    final out = await engine
        .process(Stream.fromIterable([fix(37.5, 127.0), fix(37.5001, 127.0)]))
        .toList();
    expect(out.length, 1); // 첫 점만
  });

  test('200m 이상 이동하면 다시 방출한다', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    // 약 330m 떨어진 두 점(위도 0.003도 ≈ 333m)
    final out = await engine
        .process(Stream.fromIterable([fix(37.5, 127.0), fix(37.503, 127.0)]))
        .toList();
    expect(out.length, 2);
  });

  test('heading이 없으면 이동 방향으로 보정된다(정북≈0)', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    final out = await engine
        .process(Stream.fromIterable([
          fix(37.5, 127.0, heading: null),
          fix(37.503, 127.0, heading: null), // 북쪽으로 이동
        ]))
        .toList();
    expect(out.last.headingDeg, closeTo(0, 2));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/location/location_engine_test.dart`
Expected: FAIL — `raw_fix.dart`/`location_engine.dart` 미존재.

- [ ] **Step 3: RawFix 작성**

Create `lib/location/raw_fix.dart`:
```dart
import '../core/models/lat_lng.dart';

/// 위치 소스가 내보내는 원시 픽스. heading은 기기가 제공 못하면 null.
class RawFix {
  final LatLng position;
  final double speedMps;
  final double? headingDeg;
  final DateTime timestamp;

  const RawFix({
    required this.position,
    required this.speedMps,
    required this.headingDeg,
    required this.timestamp,
  });
}
```

- [ ] **Step 4: LocationEngine 작성**

Create `lib/location/location_engine.dart`:
```dart
import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/geo/geo_math.dart';
import 'raw_fix.dart';

/// 원시 GPS 스트림을 거리 스로틀된 LocationEvent 스트림으로 변환하는 순수 로직.
/// 주입된 스트림만 다루므로 모의 트랙으로 단위 테스트 가능하다.
class LocationEngine {
  final double minMoveMeters;
  LocationEngine({this.minMoveMeters = 200});

  Stream<LocationEvent> process(Stream<RawFix> fixes) async* {
    LatLng? lastEmitted;
    await for (final f in fixes) {
      final isFirst = lastEmitted == null;
      final moved =
          isFirst ? double.infinity : GeoMath.distanceMeters(lastEmitted!, f.position);
      if (isFirst || moved >= minMoveMeters) {
        yield LocationEvent(
          position: f.position,
          headingDeg: _resolveHeading(f, lastEmitted),
          speedMps: f.speedMps,
          timestamp: f.timestamp,
        );
        lastEmitted = f.position;
      }
    }
  }

  double _resolveHeading(RawFix f, LatLng? prev) {
    if (f.headingDeg != null && f.headingDeg! >= 0) return f.headingDeg!;
    if (prev == null) return -1;
    if (GeoMath.distanceMeters(prev, f.position) < 1) return -1;
    return GeoMath.bearingDeg(prev, f.position);
  }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/location/location_engine_test.dart`
Expected: PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/location test/location
git commit -m "feat: Location Engine — 거리 스로틀 + heading 보정(순수 로직)"
```

---

## Task 3: POI Provider 인터페이스 + 카카오 RestaurantProvider

**Files:**
- Create: `lib/poi/poi_provider.dart`
- Create: `lib/poi/kakao_client.dart`
- Create: `lib/poi/restaurant_provider.dart`
- Test: `test/poi/restaurant_provider_test.dart`

**Interfaces:**
- Consumes: `LocationEvent`, `Poi`, `LatLng`.
- Produces:
  - `abstract class PoiProvider { String get id; String get displayName; Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}); }`
  - `class ProviderRegistry { void register(PoiProvider p); List<PoiProvider> get all; PoiProvider? byId(String id); }`
  - `class KakaoClient { KakaoClient({required http.Client client, required String restApiKey}); Future<List<Map<String,dynamic>>> searchCategory({required String categoryCode, required double lat, required double lng, required int radiusMeters}); }`
  - `class RestaurantProvider implements PoiProvider` — id `"restaurant"`, displayName `"맛집"`.

- [ ] **Step 1: 실패 테스트 작성 (http 목킹)**

Create `test/poi/restaurant_provider_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/poi/kakao_client.dart';
import 'package:odagada/poi/restaurant_provider.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

LocationEvent loc() => LocationEvent(
      position: LatLng(37.5, 127.0),
      headingDeg: 0,
      speedMps: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

const _sampleBody = '''
{
  "documents": [
    {
      "id": "111",
      "place_name": "맛있는 국밥",
      "category_name": "음식점 > 한식 > 국밥",
      "x": "127.001",
      "y": "37.501",
      "distance": "150",
      "road_address_name": "서울 어딘가 12",
      "phone": "02-123-4567",
      "place_url": "http://place.map.kakao.com/111"
    }
  ],
  "meta": {"total_count": 1, "is_end": true}
}
''';

void main() {
  setUpAll(() => registerFallbackValue(FakeUri()));

  test('카카오 응답을 Poi 리스트로 매핑한다', () async {
    final mock = MockHttpClient();
    when(() => mock.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(_sampleBody, 200));

    final provider = RestaurantProvider(
      client: KakaoClient(client: mock, restApiKey: 'TEST'),
    );

    final pois = await provider.nearby(loc(), radiusMeters: 1000);

    expect(pois.length, 1);
    expect(pois.first.name, '맛있는 국밥');
    expect(pois.first.category, '음식점 > 한식 > 국밥');
    expect(pois.first.position.lat, closeTo(37.501, 0.0001));
    expect(pois.first.distanceMeters, closeTo(150, 0.1));
    expect(provider.id, 'restaurant');
  });

  test('요청에 FD6 카테고리와 KakaoAK 헤더가 들어간다', () async {
    final mock = MockHttpClient();
    when(() => mock.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response(_sampleBody, 200));

    final provider = RestaurantProvider(
      client: KakaoClient(client: mock, restApiKey: 'TEST'),
    );
    await provider.nearby(loc(), radiusMeters: 500);

    final captured = verify(() => mock.get(
          captureAny(),
          headers: captureAny(named: 'headers'),
        )).captured;
    final uri = captured[0] as Uri;
    final headers = captured[1] as Map<String, String>;
    expect(uri.queryParameters['category_group_code'], 'FD6');
    expect(uri.queryParameters['radius'], '500');
    expect(headers['Authorization'], 'KakaoAK TEST');
  });

  test('HTTP 200이 아니면 예외', () async {
    final mock = MockHttpClient();
    when(() => mock.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response('nope', 429));
    final provider = RestaurantProvider(
      client: KakaoClient(client: mock, restApiKey: 'TEST'),
    );
    expect(() => provider.nearby(loc(), radiusMeters: 500), throwsA(isA<KakaoApiException>()));
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/poi/restaurant_provider_test.dart`
Expected: FAIL — 대상 파일 미존재.

- [ ] **Step 3: PoiProvider 인터페이스 + registry 작성**

Create `lib/poi/poi_provider.dart`:
```dart
import '../core/models/location_event.dart';
import '../core/models/poi.dart';

/// 모든 "주변 정보 모듈"의 공통 인터페이스. 맛집이 첫 구현체.
abstract class PoiProvider {
  String get id;          // "restaurant", "realEstate", "golf"
  String get displayName;
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters});
}

/// 활성 Provider들을 등록/조회하는 레지스트리(다중 모듈 확장 지점).
class ProviderRegistry {
  final List<PoiProvider> _providers = [];
  void register(PoiProvider p) => _providers.add(p);
  List<PoiProvider> get all => List.unmodifiable(_providers);
  PoiProvider? byId(String id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }
}
```

- [ ] **Step 4: KakaoClient 작성**

Create `lib/poi/kakao_client.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class KakaoApiException implements Exception {
  final int statusCode;
  final String message;
  KakaoApiException(this.statusCode, this.message);
  @override
  String toString() => 'KakaoApiException($statusCode): $message';
}

/// 카카오 로컬 REST API 래퍼. http.Client를 주입받아 테스트에서 목킹 가능.
class KakaoClient {
  final http.Client client;
  final String restApiKey;
  static const _base = 'https://dapi.kakao.com/v2/local/search/category.json';

  KakaoClient({required this.client, required this.restApiKey});

  /// 카테고리+좌표+반경 검색. documents 리스트(raw map)를 반환.
  Future<List<Map<String, dynamic>>> searchCategory({
    required String categoryCode,
    required double lat,
    required double lng,
    required int radiusMeters,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'category_group_code': categoryCode,
      'x': lng.toString(), // 카카오는 x=경도, y=위도
      'y': lat.toString(),
      'radius': radiusMeters.toString(), // 0~20000
      'sort': 'distance',
      'size': '15',
    });
    final res = await client.get(uri, headers: {
      'Authorization': 'KakaoAK $restApiKey',
    });
    if (res.statusCode != 200) {
      throw KakaoApiException(res.statusCode, res.body);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final docs = (body['documents'] as List).cast<Map<String, dynamic>>();
    return docs;
  }
}
```

- [ ] **Step 5: RestaurantProvider 작성**

Create `lib/poi/restaurant_provider.dart`:
```dart
import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import 'kakao_client.dart';
import 'poi_provider.dart';

export 'kakao_client.dart' show KakaoApiException;

/// 카카오 로컬 API(음식점 카테고리 FD6) 기반 맛집 Provider.
class RestaurantProvider implements PoiProvider {
  final KakaoClient client;
  RestaurantProvider({required this.client});

  @override
  String get id => 'restaurant';
  @override
  String get displayName => '맛집';

  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async {
    final docs = await client.searchCategory(
      categoryCode: 'FD6',
      lat: loc.position.lat,
      lng: loc.position.lng,
      radiusMeters: radiusMeters.round(),
    );
    return docs.map(_toPoi).toList();
  }

  Poi _toPoi(Map<String, dynamic> d) {
    return Poi(
      id: d['id'] as String,
      name: d['place_name'] as String,
      position: LatLng(
        double.parse(d['y'] as String),
        double.parse(d['x'] as String),
      ),
      category: (d['category_name'] as String?) ?? '음식점',
      address: d['road_address_name'] as String?,
      phone: d['phone'] as String?,
      placeUrl: d['place_url'] as String?,
      distanceMeters: double.parse((d['distance'] as String?) ?? '0'),
      rating: 0, // 카카오 로컬 API는 평점 미제공
    );
  }
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `flutter test test/poi/restaurant_provider_test.dart`
Expected: PASS (3개 테스트).

- [ ] **Step 7: 커밋**

```bash
git add lib/poi test/poi
git commit -m "feat: PoiProvider 인터페이스 + 카카오 RestaurantProvider(FD6)"
```

---

## Task 4: Recommendation Engine (랭킹/필터/중복억제, 순수 로직)

**Files:**
- Create: `lib/recommend/recommend_engine.dart`
- Test: `test/recommend/recommend_engine_test.dart`

**Interfaces:**
- Consumes: `Poi`, `LocationEvent`, `Recommendation`, `GeoMath`.
- Produces:
  - `RecommendEngine({double forwardHalfAngleDeg = 60, double maxDistanceMeters = 3000, int maxResults = 10})`
  - `List<Recommendation> rank(LocationEvent loc, List<Poi> candidates)`
  - 규칙: (1) `maxDistanceMeters` 초과 후보 제외. (2) heading이 유효(>=0)할 때, 현재 위치→POI 방위각이 heading 기준 전방 부채꼴(±forwardHalfAngleDeg) 밖이면 감점(제외는 아님). (3) 이미 표시된 id(`markShown`)는 제외. (4) 점수 = 거리가점 + 전방가점 + 평점가점, 내림차순 정렬 후 `maxResults`개.
  - `void markShown(Iterable<String> ids)` / `void reset()` — 중복억제 상태.

- [ ] **Step 1: 실패 테스트 작성**

Create `test/recommend/recommend_engine_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/recommend/recommend_engine.dart';

LocationEvent north() => LocationEvent(
      position: LatLng(37.5, 127.0),
      headingDeg: 0, // 북쪽 진행
      speedMps: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

Poi poi(String id, double lat, double lng, {double dist = 100, double rating = 0}) =>
    Poi(id: id, name: id, position: LatLng(lat, lng), category: 'c',
        distanceMeters: dist, rating: rating);

void main() {
  test('최대 거리 초과 후보는 제외', () {
    final e = RecommendEngine(maxDistanceMeters: 500);
    final far = poi('far', 37.51, 127.0, dist: 1200);
    final near = poi('near', 37.5009, 127.0, dist: 100);
    final out = e.rank(north(), [far, near]);
    expect(out.map((r) => r.poi.id), ['near']);
  });

  test('전방(북쪽) POI가 후방 POI보다 점수가 높다', () {
    final e = RecommendEngine();
    final ahead = poi('ahead', 37.502, 127.0, dist: 200); // 북쪽 = 전방
    final behind = poi('behind', 37.498, 127.0, dist: 200); // 남쪽 = 후방
    final out = e.rank(north(), [behind, ahead]);
    expect(out.first.poi.id, 'ahead');
  });

  test('이미 표시된 POI는 다음 랭킹에서 제외', () {
    final e = RecommendEngine();
    final a = poi('a', 37.502, 127.0, dist: 100);
    final b = poi('b', 37.5025, 127.0, dist: 150);
    final first = e.rank(north(), [a, b]);
    e.markShown(first.map((r) => r.poi.id));
    final second = e.rank(north(), [a, b]);
    expect(second, isEmpty);
  });

  test('maxResults 개수로 제한', () {
    final e = RecommendEngine(maxResults: 2);
    final pois = List.generate(
        5, (i) => poi('p$i', 37.5 + 0.001 * (i + 1), 127.0, dist: 100.0 * (i + 1)));
    final out = e.rank(north(), pois);
    expect(out.length, 2);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/recommend/recommend_engine_test.dart`
Expected: FAIL — `recommend_engine.dart` 미존재.

- [ ] **Step 3: RecommendEngine 작성**

Create `lib/recommend/recommend_engine.dart`:
```dart
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../core/geo/geo_math.dart';

/// 후보 POI를 진행방향·거리·평점으로 랭킹하고, 이미 본 곳을 억제하는 순수 엔진.
class RecommendEngine {
  final double forwardHalfAngleDeg;
  final double maxDistanceMeters;
  final int maxResults;
  final Set<String> _shown = {};

  RecommendEngine({
    this.forwardHalfAngleDeg = 60,
    this.maxDistanceMeters = 3000,
    this.maxResults = 10,
  });

  void markShown(Iterable<String> ids) => _shown.addAll(ids);
  void reset() => _shown.clear();

  List<Recommendation> rank(LocationEvent loc, List<Poi> candidates) {
    final scored = <Recommendation>[];
    for (final p in candidates) {
      if (_shown.contains(p.id)) continue;
      if (p.distanceMeters > maxDistanceMeters) continue;
      scored.add(Recommendation(poi: p, score: _score(loc, p)));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).toList();
  }

  double _score(LocationEvent loc, Poi p) {
    // 거리 가점: 가까울수록 1에 가깝게(0~1).
    final distScore = 1.0 - (p.distanceMeters / maxDistanceMeters).clamp(0.0, 1.0);

    // 전방 가점: heading 유효 시, 전방 부채꼴 안이면 1, 밖이면 각도차 비례 감점.
    double forwardScore = 0.5; // heading 미상일 때 중립값
    if (loc.headingDeg >= 0) {
      final bearing = GeoMath.bearingDeg(loc.position, p.position);
      final diff = GeoMath.angularDifferenceDeg(loc.headingDeg, bearing);
      if (diff <= forwardHalfAngleDeg) {
        forwardScore = 1.0;
      } else {
        forwardScore = (1.0 - (diff - forwardHalfAngleDeg) / (180 - forwardHalfAngleDeg))
            .clamp(0.0, 1.0);
      }
    }

    // 평점 가점(0~5 → 0~1). 데이터 없으면 0.
    final ratingScore = (p.rating / 5.0).clamp(0.0, 1.0);

    // 가중합: 전방 0.5, 거리 0.35, 평점 0.15.
    return forwardScore * 0.5 + distScore * 0.35 + ratingScore * 0.15;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/recommend/recommend_engine_test.dart`
Expected: PASS (4개 테스트).

- [ ] **Step 5: 커밋**

```bash
git add lib/recommend test/recommend
git commit -m "feat: Recommendation Engine — 전방/거리/평점 랭킹 + 중복억제(순수 로직)"
```

---

## Task 5: Recommendation Pipeline (위치→Provider→Engine 배선)

**Files:**
- Create: `lib/pipeline/recommendation_pipeline.dart`
- Test: `test/pipeline/recommendation_pipeline_test.dart`

**Interfaces:**
- Consumes: `LocationEngine`, `ProviderRegistry`, `PoiProvider`, `RecommendEngine`, `LocationEvent`, `RawFix`, `Recommendation`.
- Produces:
  - `RecommendationPipeline({required LocationEngine locationEngine, required ProviderRegistry registry, required RecommendEngine recommendEngine, double searchRadiusMeters = 2000})`
  - `Stream<List<Recommendation>> run(Stream<RawFix> fixes)` — 각 LocationEvent마다 활성 Provider들을 병렬 호출→합쳐서 랭킹→중복억제 반영→방출. Provider 예외는 삼키고 직전 결과 유지(빈 리스트 방출 안 함).

- [ ] **Step 1: 실패 테스트 작성 (Fake Provider)**

Create `test/pipeline/recommendation_pipeline_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/location/location_engine.dart';
import 'package:odagada/location/raw_fix.dart';
import 'package:odagada/poi/poi_provider.dart';
import 'package:odagada/recommend/recommend_engine.dart';
import 'package:odagada/pipeline/recommendation_pipeline.dart';

class FakeProvider implements PoiProvider {
  final List<Poi> Function() supplier;
  FakeProvider(this.supplier);
  @override
  String get id => 'fake';
  @override
  String get displayName => 'fake';
  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async =>
      supplier();
}

class ThrowingProvider implements PoiProvider {
  @override
  String get id => 'boom';
  @override
  String get displayName => 'boom';
  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async =>
      throw Exception('network down');
}

RawFix fix(double lat, double lng) => RawFix(
      position: LatLng(lat, lng),
      speedMps: 10,
      headingDeg: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

Poi poi(String id, double lat) =>
    Poi(id: id, name: id, position: LatLng(lat, 127.0), category: 'c', distanceMeters: 100);

void main() {
  test('LocationEvent마다 추천 리스트를 방출한다', () async {
    final registry = ProviderRegistry()
      ..register(FakeProvider(() => [poi('a', 37.502)]));
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    final out = await pipeline.run(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out.length, 1);
    expect(out.first.map((r) => r.poi.id), ['a']);
  });

  test('Provider 예외는 삼키고 빈 방출을 하지 않는다', () async {
    final registry = ProviderRegistry()..register(ThrowingProvider());
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    final out = await pipeline.run(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out, isEmpty); // 방출 없음(직전 결과 유지)
  });

  test('한 번 추천된 POI는 다음 위치에서 중복 방출되지 않는다', () async {
    final registry = ProviderRegistry()
      ..register(FakeProvider(() => [poi('a', 37.502)]));
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    // 두 위치 모두 같은 POI 'a'만 반환 → 두 번째엔 억제되어 빈 리스트
    final out = await pipeline
        .run(Stream.fromIterable([fix(37.5, 127.0), fix(37.503, 127.0)]))
        .toList();
    expect(out.length, 2);
    expect(out[0].map((r) => r.poi.id), ['a']);
    expect(out[1], isEmpty);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/pipeline/recommendation_pipeline_test.dart`
Expected: FAIL — `recommendation_pipeline.dart` 미존재.

- [ ] **Step 3: RecommendationPipeline 작성**

Create `lib/pipeline/recommendation_pipeline.dart`:
```dart
import '../core/models/location_event.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../location/location_engine.dart';
import '../location/raw_fix.dart';
import '../poi/poi_provider.dart';
import '../recommend/recommend_engine.dart';

/// 위치 스트림을 받아 활성 Provider 호출→랭킹→중복억제까지 배선한다.
class RecommendationPipeline {
  final LocationEngine locationEngine;
  final ProviderRegistry registry;
  final RecommendEngine recommendEngine;
  final double searchRadiusMeters;

  RecommendationPipeline({
    required this.locationEngine,
    required this.registry,
    required this.recommendEngine,
    this.searchRadiusMeters = 2000,
  });

  Stream<List<Recommendation>> run(Stream<RawFix> fixes) async* {
    await for (final loc in locationEngine.process(fixes)) {
      final candidates = await _gather(loc);
      if (candidates == null) continue; // 모든 Provider 실패 → 방출 안 함
      final ranked = recommendEngine.rank(loc, candidates);
      recommendEngine.markShown(ranked.map((r) => r.poi.id));
      yield ranked;
    }
  }

  /// 활성 Provider들을 병렬 호출. 하나라도 성공하면 합집합, 전부 실패면 null.
  Future<List<Poi>?> _gather(LocationEvent loc) async {
    final futures = registry.all.map((p) async {
      try {
        return await p.nearby(loc, radiusMeters: searchRadiusMeters);
      } catch (_) {
        return <Poi>[]; // 개별 Provider 실패는 빈 결과로
      }
    });
    final results = await Future.wait(futures);
    final merged = results.expand((e) => e).toList();
    final anySucceeded = registry.all.isNotEmpty;
    if (!anySucceeded) return null;
    // 전부 예외였는지 구분: 모든 결과가 비었고 실제로 예외였던 경우도 빈 리스트가 되지만,
    // 억제 상태 오염을 막기 위해 빈 후보는 방출하지 않고 직전 유지.
    if (merged.isEmpty) return null;
    return merged;
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/pipeline/recommendation_pipeline_test.dart`
Expected: PASS (3개 테스트).

- [ ] **Step 5: 전체 단위 테스트 통과 확인 + 커밋**

Run: `flutter test`
Expected: 지금까지의 모든 테스트 PASS.
```bash
git add lib/pipeline test/pipeline
git commit -m "feat: Recommendation Pipeline — 위치→Provider→랭킹→중복억제 배선"
```

---

## Task 6: 지도 UI — MapView 추상화 + 카카오맵(WebView) 구현

> **참고(설계 12절):** 카카오맵 렌더링 방식(WebView JS SDK vs 네이티브)은 초기 검증 대상. 본 MVP는 **webview_flutter + 카카오맵 JS SDK**로 진행하되, 앱 로직은 `MapView` 인터페이스에만 의존하게 하여 추후 네이티브 교체 가능하게 한다. 지도 렌더는 실기기 수동 확인이 기본이고, 로직 단은 앞선 태스크들에서 단위 테스트로 커버됨.

**Files:**
- Create: `lib/ui/map_view.dart`
- Create: `assets/kakao_map.html`
- Create: `lib/ui/kakao_map_view.dart`

**Interfaces:**
- Consumes: `LatLng`, `Recommendation`, `AppConfig.kakaoJsAppKey`.
- Produces:
  - `abstract class MapView { Widget build(BuildContext); void moveCamera(LatLng); void setPins(List<Recommendation>); }` (위젯형 컨트롤러)
  - 실제로는 StatefulWidget으로 구현: `KakaoMapView extends StatefulWidget` + `KakaoMapController`(핀 세팅/카메라 이동/핀 탭 콜백 `onPinTap(Poi)`).

- [ ] **Step 1: 카카오맵 HTML 작성**

Create `assets/kakao_map.html`:
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no" />
  <style>html,body,#map{margin:0;padding:0;width:100%;height:100%;}</style>
</head>
<body>
  <div id="map"></div>
  <script>
    // Flutter가 __KAKAO_JS_KEY__ 를 실제 키로 치환해 로드한다.
    var script = document.createElement('script');
    script.src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=__KAKAO_JS_KEY__&autoload=false';
    script.onload = function () {
      kakao.maps.load(function () {
        window._map = new kakao.maps.Map(document.getElementById('map'), {
          center: new kakao.maps.LatLng(37.5665, 126.9780),
          level: 4
        });
        window._markers = [];
        // Flutter → JS: 카메라 이동
        window.moveCamera = function (lat, lng) {
          window._map.setCenter(new kakao.maps.LatLng(lat, lng));
        };
        // Flutter → JS: 핀 세팅. items = [{id,name,lat,lng}]
        window.setPins = function (jsonStr) {
          var items = JSON.parse(jsonStr);
          window._markers.forEach(function (m) { m.setMap(null); });
          window._markers = [];
          items.forEach(function (it) {
            var marker = new kakao.maps.Marker({
              position: new kakao.maps.LatLng(it.lat, it.lng)
            });
            marker.setMap(window._map);
            kakao.maps.event.addListener(marker, 'click', function () {
              // JS → Flutter: 핀 탭 통지
              PinChannel.postMessage(it.id);
            });
            window._markers.push(marker);
          });
        };
        MapReady.postMessage('ready');
      });
    };
    document.head.appendChild(script);
  </script>
</body>
</html>
```

- [ ] **Step 2: MapView 인터페이스 작성**

Create `lib/ui/map_view.dart`:
```dart
import 'package:flutter/widgets.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';

/// 지도 구현을 로직에서 분리하기 위한 컨트롤러 인터페이스.
abstract class MapController {
  void moveCamera(LatLng center);
  void setPins(List<Recommendation> recs);
}

/// 핀 탭 콜백 시그니처.
typedef PinTapCallback = void Function(Poi poi);
```

- [ ] **Step 3: KakaoMapView(WebView) 작성**

Create `lib/ui/kakao_map_view.dart`:
```dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_config.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import 'map_view.dart';

/// 카카오맵 JS SDK를 webview_flutter로 렌더링하는 지도 위젯.
class KakaoMapView extends StatefulWidget {
  final PinTapCallback onPinTap;
  final void Function(MapController controller) onReady;
  const KakaoMapView({super.key, required this.onPinTap, required this.onReady});

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<KakaoMapView> implements MapController {
  late final WebViewController _web;
  List<Recommendation> _lastRecs = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    var html = await rootBundle.loadString('assets/kakao_map.html');
    html = html.replaceAll('__KAKAO_JS_KEY__', AppConfig.kakaoJsAppKey);

    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MapReady',
          onMessageReceived: (_) => widget.onReady(this))
      ..addJavaScriptChannel('PinChannel', onMessageReceived: (msg) {
        final poi = _findPoi(msg.message);
        if (poi != null) widget.onPinTap(poi);
      })
      ..loadHtmlString(html);
  }

  Poi? _findPoi(String id) {
    for (final r in _lastRecs) {
      if (r.poi.id == id) return r.poi;
    }
    return null;
  }

  @override
  void moveCamera(LatLng center) {
    _web.runJavaScript('window.moveCamera(${center.lat}, ${center.lng});');
  }

  @override
  void setPins(List<Recommendation> recs) {
    _lastRecs = recs;
    final items = recs
        .map((r) => {
              'id': r.poi.id,
              'name': r.poi.name,
              'lat': r.poi.position.lat,
              'lng': r.poi.position.lng,
            })
        .toList();
    final json = jsonEncode(items);
    _web.runJavaScript('window.setPins(${jsonEncode(json)});');
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
```

- [ ] **Step 4: 정적 분석 통과 확인 + 커밋**

Run: `flutter analyze`
Expected: 에러 없음(경고 수준 허용). 지도 렌더는 Task 8의 수동 실행에서 확인.
```bash
git add lib/ui/map_view.dart lib/ui/kakao_map_view.dart assets/kakao_map.html pubspec.yaml
git commit -m "feat: MapView 추상화 + 카카오맵(WebView JS SDK) 렌더러"
```

---

## Task 7: 정보 카드 + 길찾기 딥링크

**Files:**
- Create: `lib/ui/info_card.dart`
- Create: `lib/ui/navigation_launcher.dart`
- Test: `test/ui/info_card_test.dart`

**Interfaces:**
- Consumes: `Poi`.
- Produces:
  - `class InfoCard extends StatelessWidget { InfoCard({required Poi poi, required VoidCallback onNavigate}); }` — 이름·거리·카테고리 표시(운전 중 안전 위해 큰 글씨, 버튼 1개), "길찾기" 버튼.
  - `class NavigationLauncher { Future<void> launch(Poi poi); }` — 카카오맵 길찾기 딥링크(`kakaomap://route?ep=<lat>,<lng>&by=CAR`) 시도, 실패 시 `https://map.kakao.com/link/to/...` 웹 폴백. `url_launcher` 사용.

- [ ] **Step 1: InfoCard 위젯 테스트 작성**

Create `test/ui/info_card_test.dart`:
```dart
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/ui/info_card_test.dart`
Expected: FAIL — `info_card.dart` 미존재.

- [ ] **Step 3: InfoCard 작성**

Create `lib/ui/info_card.dart`:
```dart
import 'package:flutter/material.dart';
import '../core/models/poi.dart';

/// 핀 탭 시 하단에 뜨는 정보 카드. 운전 중 가독성 위해 큰 글씨/버튼 1개.
class InfoCard extends StatelessWidget {
  final Poi poi;
  final VoidCallback onNavigate;
  const InfoCard({super.key, required this.poi, required this.onNavigate});

  String get _distanceText {
    final d = poi.distanceMeters;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}km';
    return '${d.round()}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poi.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('$_distanceText · ${poi.category}',
                style: const TextStyle(fontSize: 18, color: Colors.black54)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: onNavigate,
                child: const Text('길찾기', style: TextStyle(fontSize: 20)),
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

Run: `flutter test test/ui/info_card_test.dart`
Expected: PASS.

- [ ] **Step 5: NavigationLauncher 작성**

Create `lib/ui/navigation_launcher.dart`:
```dart
import 'package:url_launcher/url_launcher.dart';
import '../core/models/poi.dart';

/// 카카오맵 길찾기로 연결. 앱 딥링크 우선, 실패 시 웹 폴백.
class NavigationLauncher {
  Future<void> launch(Poi poi) async {
    final lat = poi.position.lat;
    final lng = poi.position.lng;
    final appUri = Uri.parse('kakaomap://route?ep=$lat,$lng&by=CAR');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }
    final webUri = Uri.parse(
        'https://map.kakao.com/link/to/${Uri.encodeComponent(poi.name)},$lat,$lng');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
```

- [ ] **Step 6: iOS URL scheme 허용**

`ios/Runner/Info.plist`의 `<dict>` 안에 추가(딥링크 canLaunch용):
```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>kakaomap</string>
</array>
```

- [ ] **Step 7: 커밋**

```bash
git add lib/ui/info_card.dart lib/ui/navigation_launcher.dart test/ui ios/Runner/Info.plist
git commit -m "feat: 정보 카드 + 카카오맵 길찾기 딥링크"
```

---

## Task 8: Module Selector + 앱 조립 + 수동 실전 검증

**Files:**
- Create: `lib/ui/module_selector.dart`
- Create: `lib/location/location_source.dart`
- Create: `lib/ui/map_screen.dart`
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: 모든 앞선 컴포넌트.
- Produces:
  - `class LocationSource { Stream<RawFix> stream(); Future<bool> ensurePermission(); }` — geolocator 어댑터.
  - `class ModuleSelector extends StatelessWidget` — 활성 모듈 토글 목록(MVP는 맛집만, 켜짐 고정).
  - `class MapScreen extends StatefulWidget` — 파이프라인 구독→지도 핀 갱신, 핀 탭→InfoCard, 카드 길찾기→NavigationLauncher.

- [ ] **Step 1: LocationSource(geolocator 어댑터) 작성**

Create `lib/location/location_source.dart`:
```dart
import 'package:geolocator/geolocator.dart';
import '../core/models/lat_lng.dart';
import 'raw_fix.dart';

/// 플랫폼 GPS를 RawFix 스트림으로 변환하는 어댑터.
class LocationSource {
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Stream<RawFix> stream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10m마다 raw 픽스(엔진이 200m로 다시 스로틀)
      ),
    ).map((p) => RawFix(
          position: LatLng(p.latitude, p.longitude),
          speedMps: p.speed,
          headingDeg: p.heading >= 0 ? p.heading : null,
          timestamp: p.timestamp,
        ));
  }
}
```

- [ ] **Step 2: ModuleSelector 작성**

Create `lib/ui/module_selector.dart`:
```dart
import 'package:flutter/material.dart';
import '../poi/poi_provider.dart';

/// 활성 모듈 선택 화면. MVP는 맛집만 노출(항상 켜짐), 구조는 다중 대비.
class ModuleSelector extends StatelessWidget {
  final ProviderRegistry registry;
  const ModuleSelector({super.key, required this.registry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('모듈 선택')),
      body: ListView(
        children: registry.all
            .map((p) => SwitchListTile(
                  title: Text(p.displayName),
                  value: true,
                  onChanged: null, // MVP: 맛집 고정. v2에서 토글 가능.
                ))
            .toList(),
      ),
    );
  }
}
```

- [ ] **Step 3: MapScreen 조립**

Create `lib/ui/map_screen.dart`:
```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../location/location_source.dart';
import '../pipeline/recommendation_pipeline.dart';
import '../poi/poi_provider.dart';
import 'kakao_map_view.dart';
import 'map_view.dart';
import 'info_card.dart';
import 'module_selector.dart';
import 'navigation_launcher.dart';

class MapScreen extends StatefulWidget {
  final LocationSource locationSource;
  final RecommendationPipeline pipeline;
  final ProviderRegistry registry;
  final NavigationLauncher navigationLauncher;

  const MapScreen({
    super.key,
    required this.locationSource,
    required this.pipeline,
    required this.registry,
    required this.navigationLauncher,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _map;
  StreamSubscription? _sub;
  Poi? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await widget.locationSource.ensurePermission();
    if (!ok) {
      setState(() => _error = '위치 권한이 필요합니다. 설정에서 허용해 주세요.');
      return;
    }
    _sub = widget.pipeline.run(widget.locationSource.stream()).listen(_onRecs);
  }

  void _onRecs(List<Recommendation> recs) {
    if (recs.isEmpty) return;
    _map?.setPins(recs);
    _map?.moveCamera(recs.first.poi.position);
  }

  void _onPinTap(Poi poi) => setState(() => _selected = poi);

  @override
  void dispose() {
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
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ModuleSelector(registry: widget.registry),
            )),
          ),
        ],
      ),
      body: Stack(
        children: [
          KakaoMapView(
            onReady: (c) => _map = c,
            onPinTap: _onPinTap,
          ),
          if (_selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: InfoCard(
                poi: _selected!,
                onNavigate: () => widget.navigationLauncher.launch(_selected!),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: app.dart / main.dart 배선**

Replace `lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'location/location_source.dart';
import 'location/location_engine.dart';
import 'pipeline/recommendation_pipeline.dart';
import 'poi/poi_provider.dart';
import 'poi/kakao_client.dart';
import 'poi/restaurant_provider.dart';
import 'recommend/recommend_engine.dart';
import 'config/app_config.dart';
import 'ui/map_screen.dart';
import 'ui/navigation_launcher.dart';

class OdagadaApp extends StatelessWidget {
  const OdagadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = ProviderRegistry()
      ..register(RestaurantProvider(
        client: KakaoClient(
          client: http.Client(),
          restApiKey: AppConfig.kakaoRestApiKey,
        ),
      ));

    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );

    return MaterialApp(
      title: '오다가다',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: MapScreen(
        locationSource: LocationSource(),
        pipeline: pipeline,
        registry: registry,
        navigationLauncher: NavigationLauncher(),
      ),
    );
  }
}
```

Replace `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const OdagadaApp());
}
```

- [ ] **Step 5: 전체 테스트 + 정적 분석**

Run:
```bash
flutter test
flutter analyze
```
Expected: 모든 단위/위젯 테스트 PASS, analyze 에러 없음.

- [ ] **Step 6: 실기기 수동 검증 (운전 시나리오)**

> 카카오 개발자 콘솔에서 앱 등록 후 (1) REST API 키, (2) JavaScript 키를 발급하고, JS 키의 **플랫폼 > Web 사이트 도메인**에 WebView 로컬 오리진 등록이 필요할 수 있음. Android는 실기기/에뮬레이터, iOS는 실기기 권장(GPS).

Run:
```bash
flutter run   # 실기기 연결 상태에서
```
확인 항목:
- [ ] 앱 실행 시 위치 권한 요청 → 허용하면 지도 표시.
- [ ] 이동(또는 위치 시뮬레이션)에 따라 200m마다 맛집 핀이 갱신됨.
- [ ] 핀 탭 → 하단 정보 카드(이름·거리·카테고리) 표시.
- [ ] "길찾기" → 카카오맵/내비 앱으로 전환.
- [ ] 우상단 모듈 아이콘 → 맛집 모듈만 노출.
- [ ] 네트워크 일시 끊김 시 앱이 죽지 않고 직전 핀 유지.

문제가 있으면 systematic-debugging 스킬로 원인부터 재현/격리.

- [ ] **Step 7: 커밋**

```bash
git add lib test
git commit -m "feat: 앱 조립 — LocationSource/ModuleSelector/MapScreen 배선(MVP 완성)"
```

---

## Self-Review (작성자 점검)

- **스펙 커버리지:**
  - 개요/목표(§1) → Task 5~8 파이프라인+지도. ✅
  - Location Engine(§5.1) → Task 2. ✅
  - PoiProvider 인터페이스+RestaurantProvider(§5.2) → Task 3. ✅
  - Recommendation Engine(§5.3, 전방/거리/평점/중복억제) → Task 4. ✅
  - Map UI(§5.4, 핀·카메라팔로우·정보카드·길찾기) → Task 6·7·8. ✅
  - Module Selector(§5.5) → Task 8. ✅
  - 에러 처리(§7, API 실패 시 직전 유지) → Task 5 `_gather`, Task 8 error 상태. ✅ (지수 백오프 재시도는 MVP에서 "직전 유지"로 단순화 — §7의 핵심인 사용자 방해 최소화 충족, 백오프는 v2 튜닝 대상으로 남김.)
  - 안전(§8, 조작 불필요·자동 팝업 금지) → 핀 자동 갱신, 카드는 탭 시에만. ✅
  - 테스트 전략(§9) → Task 2·3·4·5·7 단위/위젯 테스트. ✅
  - MVP 범위(§10, 맛집 1종·확장 인터페이스만) → registry에 맛집 1개. ✅
  - 미해결(§12): 카카오맵 렌더 방식 → Task 6에서 WebView로 확정+MapView로 격리. 평점 → 0 처리. API 키/쿼터 → Task 0. 스로틀/각도 → 상수화. ✅
- **플레이스홀더 스캔:** TBD/TODO 없음. 모든 코드 스텝에 실제 코드 포함. ✅
- **타입 일관성:** `PoiProvider.nearby(loc, {radiusMeters})`, `RecommendEngine.rank/markShown/reset`, `MapController.moveCamera/setPins`, `RawFix`/`LocationEvent` 필드명이 태스크 전반에서 일치. ✅
- **알려진 튜닝/후속:** 지수 백오프 재시도, 정차 시 갱신 빈도 축소(§5.1의 정차 판별은 `LocationEvent.isMoving`으로 노출만, 실제 빈도 제어는 v2), TTS(v2), 부동산/골프(v3).

---

## 실행 방법 (Execution)

이 계획을 실행하려면 두 가지 방식이 있습니다:
1. **Subagent-Driven (권장)** — 태스크마다 새 서브에이전트가 구현, 태스크 사이 리뷰.
2. **Inline Execution** — 현재 세션에서 체크포인트 단위로 실행.
