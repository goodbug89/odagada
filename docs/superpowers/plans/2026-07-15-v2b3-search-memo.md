# v2.0b-3 검색-저장 + 한줄 메모 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** (①) Google Places 텍스트 검색으로 임의의 장소를 찾아 저장하고, (②) 저장 시 선택적 한줄 메모를 남긴다(핀 탭 저장·검색 저장 공통).

**Architecture:** `GooglePlacesProvider`에 `searchText`를 추가한다. 저장 시 뜨는 `showMemoSheet`(모달 바텀시트)가 메모를 받아 `SavedPlaceRepository.save(memo:)`로 넘긴다(기존 핀 탭 저장 경로에 연결). 새 `SearchScreen`(앱바 검색 아이콘 진입)은 `searchText` 결과를 리스트로 보여주고 같은 메모 시트로 저장한다. 저장된 장소는 v2.0d 오버레이 덕에 화면 영역 안이면 지도에 자동 표시된다.

**Tech Stack:** Flutter 3.44.6, Google Places API (New) `places:searchText`, 기존 `showModalBottomSheet`.

## Global Constraints

- 저장소 `/Users/goodbug/dev/odagada`, 브랜치 `feature/v2b-save`(현재), 새 브랜치 금지. Flutter `/opt/homebrew/bin`(`export PATH="/opt/homebrew/bin:$PATH"`). 패키지 `odagada`.
- 기존 테스트 회귀 유지(현재 58). 순수/모델/위젯은 TDD. `flutter analyze` 신규 이슈 0(기존 info 3건).
- **메모는 선택**(빈 메모면 null 저장). `SavedPlaceRepository.save`는 이미 `memo` 파라미터가 있음 — 지금 호출부가 안 넘길 뿐.
- **직접 추가(long-press)는 범위 아님**(이전에 drop). 검색 저장만.
- 저장 카테고리는 v2.0d대로 `bucket.name` 저장.

## 결정 (확정)
1. 저장 = 메모 시트 1회 경유(메모 없이 "저장"만 눌러도 즉시 완료 — 마찰 최소). 취소(시트 닫기)면 저장 안 함.
2. 검색 위치 바이어스 = 지도 마지막 중심(`_lastCenter`), 없으면 없이 검색.
3. 검색 결과 거리 = 바이어스 기준(없으면 0).

---

### Task 1: GooglePlacesProvider.searchText (텍스트 검색)

**Files:**
- Modify: `lib/poi/google_places_provider.dart`
- Test: `test/poi/google_places_provider_test.dart`(케이스 추가)

**Interfaces:**
- Produces: `Future<List<Poi>> searchText(String query, {LatLng? bias})` — `places:searchText`로 검색, 결과를 `Poi`로. bias 있으면 그 좌표 기준 거리·검색 바이어스.

- [ ] **Step 1: `_toPoi` 거리 기준을 nullable 참조좌표로 리팩터(회귀 없음)**

`lib/poi/google_places_provider.dart`에서 `_toPoi(LocationEvent loc, Map<String,dynamic> p)`를 참조좌표 기반으로 바꾼다:
```dart
  Poi _toPoi(LatLng? ref, Map<String, dynamic> p) {
    final l = p['location'] as Map<String, dynamic>;
    final pos = LatLng(
      (l['latitude'] as num).toDouble(),
      (l['longitude'] as num).toDouble(),
    );
    return Poi(
      id: (p['id'] as String?) ?? '${pos.lat},${pos.lng}',
      name: (p['displayName']?['text'] as String?) ?? '이름 없음',
      position: pos,
      category: (p['primaryTypeDisplayName']?['text'] as String?) ?? '음식점',
      bucket: PlaceCategory.fromGooglePrimaryType(p['primaryType'] as String?),
      address: p['formattedAddress'] as String?,
      phone: p['nationalPhoneNumber'] as String?,
      openNow: (p['regularOpeningHours'] as Map<String, dynamic>?)?['openNow']
          as bool?,
      weekdayHours: ((p['regularOpeningHours'] as Map<String, dynamic>?)?[
              'weekdayDescriptions'] as List?)
          ?.cast<String>(),
      distanceMeters: ref == null ? 0 : GeoMath.distanceMeters(ref, pos),
    );
  }
```
그리고 `nearby`의 호출부 `_toPoi(loc, ...)`를 `_toPoi(loc.position, ...)`로 바꾼다.

- [ ] **Step 2: 실패하는 테스트 추가**

`test/poi/google_places_provider_test.dart`에 추가(기존 mocktail·`loc()` 규약 재사용):
```dart
  test('searchText는 textQuery로 검색해 Poi 목록을 준다', () async {
    when(() => mockClient.post(any(),
        headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (invocation) async {
        final body = invocation.namedArguments[const Symbol('body')] as String;
        expect(body, contains('금양화로')); // textQuery 실림
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'places': [
              {
                'id': 'p1',
                'displayName': {'text': '금양화로'},
                'location': {'latitude': 37.5, 'longitude': 127.0},
                'primaryType': 'korean_restaurant',
              }
            ],
          })),
          200,
        );
      },
    );
    final provider = GooglePlacesProvider(client: mockClient, apiKey: 'k');
    final pois = await provider.searchText('금양화로',
        bias: const LatLng(37.5, 127.0));
    expect(pois.single.name, '금양화로');
    expect(pois.single.bucket, PlaceCategory.restaurant);
  });
```

- [ ] **Step 3: 실패 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/poi/google_places_provider_test.dart`
Expected: FAIL(`searchText` 없음).

- [ ] **Step 4: 구현**

`lib/poi/google_places_provider.dart`에 상수·메서드 추가:
```dart
  static const _textEndpoint =
      'https://places.googleapis.com/v1/places:searchText';

  Future<List<Poi>> searchText(String query, {LatLng? bias}) async {
    final res = await client.post(
      Uri.parse(_textEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.primaryType,places.primaryTypeDisplayName,places.formattedAddress,places.nationalPhoneNumber,places.regularOpeningHours',
      },
      body: jsonEncode({
        'textQuery': query,
        if (bias != null)
          'locationBias': {
            'circle': {
              'center': {'latitude': bias.lat, 'longitude': bias.lng},
              'radius': 20000.0,
            }
          },
        'maxResultCount': 15,
        'languageCode': 'ko',
      }),
    );
    if (res.statusCode != 200) {
      throw GooglePlacesException(res.statusCode, res.body);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final places = (body['places'] as List?) ?? const [];
    return places.map((p) => _toPoi(bias, p as Map<String, dynamic>)).toList();
  }
```

- [ ] **Step 5: 통과 + 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter test`
Expected: 전건 PASS.

- [ ] **Step 6: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/poi/google_places_provider.dart test/poi/google_places_provider_test.dart
git commit -m "feat: GooglePlacesProvider.searchText (text search)"
```

---

### Task 2: 메모 바텀시트 + 핀 탭 저장에 연결

**Files:**
- Create: `lib/ui/memo_sheet.dart`
- Modify: `lib/ui/map_screen.dart`(`_onSaveToggle` 저장 경로)
- Test: `test/ui/memo_sheet_test.dart`

**Interfaces:**
- Produces: `Future<String?> showMemoSheet(BuildContext context, {required String placeName})` — 모달 바텀시트. "저장" 누르면 입력한 메모(빈 문자열 가능) 반환, 닫으면 null.

- [ ] **Step 1: 실패하는 위젯 테스트**

`test/ui/memo_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/ui/memo_sheet.dart';

void main() {
  testWidgets('메모 입력 후 저장 → 입력값 반환', (t) async {
    String? result = 'unset';
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () async {
              result = await showMemoSheet(ctx, placeName: '금양화로');
            },
            child: const Text('open'),
          );
        }),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.textContaining('금양화로'), findsOneWidget); // 장소명 노출
    await t.enterText(find.byType(TextField), '분위기 좋음');
    await t.tap(find.widgetWithText(FilledButton, '저장'));
    await t.pumpAndSettle();
    expect(result, '분위기 좋음');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/ui/memo_sheet_test.dart`
Expected: FAIL(파일 없음).

- [ ] **Step 3: 구현**

`lib/ui/memo_sheet.dart`:
```dart
import 'package:flutter/material.dart';

/// 저장 시 뜨는 한줄 메모 입력 시트. "저장"이면 메모(빈 문자열 가능) 반환, 닫으면 null.
Future<String?> showMemoSheet(BuildContext context,
    {required String placeName}) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true, // 키보드 위로 올라오게
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$placeName 저장',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: '메모 (선택) — 왜 좋았는지 한 줄',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('저장', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd /Users/goodbug/dev/odagada && flutter test test/ui/memo_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: MapScreen 저장 경로에 메모 연결**

`lib/ui/map_screen.dart`의 `_onSaveToggle`에서 import 추가(`import 'memo_sheet.dart';`) 후 저장 분기 교체:
```dart
    if (_savedIds.contains(poi.id)) {
      await widget.savedRepo.deleteByPlaceId(ownerId: u.id, placeId: poi.id);
    } else {
      final memo = await showMemoSheet(context, placeName: poi.name);
      if (memo == null) return; // 시트 닫음 → 저장 취소
      await widget.savedRepo.save(
          ownerId: u.id, poi: poi, memo: memo.isEmpty ? null : memo);
    }
    await _reloadSaved();
```
(주의: `showMemoSheet` await 뒤 `context` 사용 없음. `_reloadSaved`는 mounted 가드 있음. `_onSaveToggle`은 이미 async.)

- [ ] **Step 6: 회귀 + 분석**

Run: `cd /Users/goodbug/dev/odagada && flutter test && flutter analyze`
Expected: 전건 PASS, analyze 신규 0.

- [ ] **Step 7: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/ui/memo_sheet.dart lib/ui/map_screen.dart test/ui/memo_sheet_test.dart
git commit -m "feat: one-line memo sheet on save (pin-tap path)"
```

---

### Task 3: 검색 화면(SearchScreen) + 앱바 진입 + 검색 저장

**Files:**
- Create: `lib/ui/search_screen.dart`
- Modify: `lib/ui/map_screen.dart`(앱바 검색 아이콘 + textSearch 배선)
- Modify: `lib/app.dart`(GooglePlacesProvider를 변수화해 searchText 콜백 전달)

**Interfaces:**
- Consumes: `GooglePlacesProvider.searchText`(Task 1), `showMemoSheet`(Task 2), `SavedPlaceRepository`.
- Produces: `SearchScreen`(검색어 입력 → 결과 리스트 → 저장). `MapScreen`에 `textSearch: Future<List<Poi>> Function(String query, LatLng? bias)` 파라미터 추가.

- [ ] **Step 1: app.dart — provider 변수화 + MapScreen에 textSearch·검색바이어스 전달**

`lib/app.dart`:
```dart
    final placesProvider = GooglePlacesProvider(
      client: http.Client(),
      apiKey: AppConfig.googleMapsApiKey,
    );
    final registry = ProviderRegistry()..register(placesProvider);
```
그리고 `MapScreen(...)`에 인자 추가: `textSearch: placesProvider.searchText,`.
`import 'core/models/poi.dart';`가 필요하면 추가.

- [ ] **Step 2: MapScreen — 파라미터 + 앱바 검색 아이콘**

`lib/ui/map_screen.dart`:
(a) 필드/생성자에 추가:
```dart
  final Future<List<Poi>> Function(String query, LatLng? bias) textSearch;
```
(생성자 `required this.textSearch,`)
(b) import: `import 'search_screen.dart';`
(c) 앱바 `actions`에 검색 아이콘(계정 버튼 앞 또는 뒤):
```dart
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchScreen(
                textSearch: widget.textSearch,
                bias: _lastCenter,
                savedRepo: widget.savedRepo,
                auth: widget.auth,
                onChanged: _reloadSaved,
              ),
            )),
          ),
```

- [ ] **Step 3: SearchScreen 구현**

`lib/ui/search_screen.dart`:
```dart
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../saved/saved_place_repository.dart';
import 'login_sheet.dart';
import 'memo_sheet.dart';

/// 텍스트 검색으로 장소를 찾아 저장하는 화면.
class SearchScreen extends StatefulWidget {
  final Future<List<Poi>> Function(String query, LatLng? bias) textSearch;
  final LatLng? bias;
  final SavedPlaceRepository savedRepo;
  final AuthController auth;
  final Future<void> Function() onChanged; // 저장 후 지도 갱신용
  const SearchScreen({
    super.key,
    required this.textSearch,
    required this.bias,
    required this.savedRepo,
    required this.auth,
    required this.onChanged,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Poi> _results = const [];
  Set<String> _savedIds = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final u = widget.auth.user;
    if (u == null) return;
    final ids = await widget.savedRepo.savedPlaceIds(u.id);
    if (mounted) setState(() => _savedIds = ids);
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.textSearch(q, widget.bias);
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _error = '검색에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Poi poi) async {
    final u = widget.auth.user;
    if (u == null) {
      showLoginSheet(context, onGoogle: widget.auth.signInWithGoogle);
      return;
    }
    final memo = await showMemoSheet(context, placeName: poi.name);
    if (memo == null) return;
    await widget.savedRepo.save(
        ownerId: u.id, poi: poi, memo: memo.isEmpty ? null : memo);
    await _loadSaved();
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: '장소·가게 이름 검색',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _search),
        ],
      ),
      body: _error != null
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24), child: Text(_error!)))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    final saved = _savedIds.contains(p.id);
                    return ListTile(
                      leading: Icon(p.bucket.icon, color: p.bucket.color),
                      title: Text(p.name),
                      subtitle: Text([
                        p.bucket.label,
                        if (p.address != null) p.address!,
                      ].join(' · ')),
                      trailing: saved
                          ? const Icon(Icons.bookmark, color: Color(0xFFFF5E13))
                          : TextButton(
                              onPressed: () => _save(p),
                              child: const Text('저장'),
                            ),
                    );
                  },
                ),
    );
  }
}
```

- [ ] **Step 4: 분석 + 회귀**

Run: `cd /Users/goodbug/dev/odagada && flutter analyze && flutter test`
Expected: analyze 신규 0(MapScreen 새 required 파라미터 `textSearch`가 app.dart에서 전달됨), 전건 green. (SearchScreen은 플랫폼 검색 호출이라 위젯테스트는 생략 — 온디바이스 검증.)

- [ ] **Step 5: 커밋**
```bash
cd /Users/goodbug/dev/odagada
git add lib/ui/search_screen.dart lib/ui/map_screen.dart lib/app.dart
git commit -m "feat: search screen (text search → save with memo)"
```

---

## 온디바이스 검증(계획 완료 후)
1. 앱바 검색 아이콘 → 장소 이름 입력·검색 → 결과 리스트(이름·카테고리·주소).
2. 결과의 "저장" → 메모 시트 → 메모 입력(또는 빈 채로) 저장 → 목록/지도(뷰포트 안이면)에 반영, 저장됨 표시.
3. 지도 핀 탭 → 저장 시에도 메모 시트 뜨는지, 메모가 저장 목록 부제에 보이는지.

## Self-Review 결과
- Spec 커버리지: §7.3 검색→저장·한줄 메모 → Task1(searchText)·Task2(메모+핀저장)·Task3(검색화면+검색저장). long-press 직접추가는 범위 제외(spec대로).
- Placeholder 스캔: 없음.
- 타입 일관성: `searchText(String,{LatLng? bias})→Future<List<Poi>>`, `showMemoSheet(ctx,{placeName})→Future<String?>`, `MapScreen.textSearch`, `SearchScreen(textSearch,bias,savedRepo,auth,onChanged)` — 태스크 간 일치. `_toPoi` 리팩터는 nearby 호출부까지 반영.
