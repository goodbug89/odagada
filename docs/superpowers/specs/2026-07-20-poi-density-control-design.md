# 오다가다 POI 밀도 조절 설계 (라벨 숨김 · 줌 게이팅 · 카테고리 필터)

- 작성일: 2026-07-20
- 상태: 브레인스토밍 승인 → 구현 계획으로
- 상위: v2.2 타일 로딩이 "뷰포트당 20개" 상한을 없애 팝핑을 잡은 대신, 누적 표시로 화면이 붐빔. 그 밀도를 제품 원칙에 맞게 조절한다.
- 저장소: `~/dev/odagada`

## 1. 목표 / 범위

지도의 일반(주변) POI가 너무 많고 이름표가 겹쳐 지저분한 문제를 해결한다. 핵심 관점: **이 앱의 신호는 친구/내 저장 핀**(§2 원칙: 공개평점 없음, 신호는 친구그래프). 일반 POI(Google Places)는 "여기 뭐가 있나" 배경 맥락일 뿐이므로, 일반 POI를 눈에 덜 띄게 깔고 친구/저장 핀을 도드라지게 한다.

세 레버:
1. 일반 POI = 이름표 없는 작은 점(이름은 탭 시 정보카드).
2. 줌 게이팅: 임계 배율 Z 미만이면 일반 POI를 아예 안 그림(친구/저장만).
3. 카테고리 필터: 7종 중 볼 종류만 토글(일반 POI에만 적용).

**완료 정의**: (a) 일반 POI가 라벨 없는 점으로만 뜨고, (b) 초기 줌(15)에선 친구/저장 핀만 보이며 확대(≥16)하면 일반 POI가 나타나고, (c) 필터로 특정 카테고리만 남기면 일반 POI가 그에 맞게 줄되 친구/저장 핀은 항상 보인다.

## 2. 컴포넌트 1 — 일반 POI 라벨 숨김

`lib/ui/place_pin.dart`의 `CategoryDot`에서 이름표를 제거한다.
- 현재: `Row([Container(dot+icon), SizedBox(4), _NameLabel])`.
- 변경: 이름표와 그 앞 간격을 제거해 **점(카테고리색 원 + 흰 아이콘)만** 렌더.
- 앵커 불변: `google_map_view._buildPins`의 CategoryDot 앵커 `-15/-15`(원 중심)는 그대로 유효.
- `PlacePin`(내 저장/친구)은 이름표 유지 — 변경 없음.
- `_NameLabel`은 `PlacePin`이 계속 쓰므로 파일에 남긴다.

## 3. 컴포넌트 2 — 줌 게이팅 (임계 배율 Z)

일반 POI는 카메라 줌이 임계 `Z` 이상일 때만 표시한다. 친구/저장 핀은 줌과 무관하게 항상 표시(신호).

- 상수: `Z = 16`(기본값, 온디바이스 튜닝 대상). `lib/poi/tiled_poi_source.dart`의 `minBrowseZoom` 기본값을 14→16으로 올려 **안 그릴 것은 검색도 안 하게** 한다(낭비 방지).
- 렌더 게이트: `lib/ui/google_map_view.dart`의 `_buildPins`에서 ambient(비저장·비친구, 즉 CategoryDot 분기)는 `_camZoom >= 16`일 때만 추가한다. 이는 캐시에 남은 저줌 잔여 POI가 축소 시 새는 것을 막는다(검색 게이트만으론 `load`가 `cache.poisIn`을 반환해 셀 수 있으므로 렌더 게이트가 필요).
- 친구/저장 핀(PlacePin 분기: `saved || fc>0`)은 게이트 없이 항상 렌더.
- 상수는 `_buildPins`가 참조할 수 있게 `google_map_view.dart`에 `static const _ambientMinZoom = 16;`로 둔다. `minBrowseZoom` 기본값(16)과 개념적으로 같은 값이며, 둘 다 16으로 명시한다.

동작: 초기 줌 15 → 친구/저장만(깨끗). 한 번 확대(≥16) → 일반 POI 점 등장.

## 4. 컴포넌트 3 — 카테고리 필터

7종 `PlaceCategory`(restaurant/cafe/bar/attraction/shopping/activity/other) 중 볼 종류만 토글한다. **일반 POI에만 적용**하고 친구/저장 핀은 항상 표시.

### 4.1 상태
`MapScreen`에 `Set<PlaceCategory> _visibleCategories`(기본 = 7종 전부). 필터 시트에서 갱신.

### 4.2 적용
`_runSearch`에서 `TiledPoiSource.load`가 준 일반 POI를 `_visibleCategories.contains(p.bucket)`로 거른 뒤 오버레이 병합. 친구(extraPins)·내 저장(savedOverlay)은 거르지 않는다.

### 4.3 필터 변경 시 재적용(재검색 없음)
필터가 바뀌면 마지막 `_lastBounds`/`_lastZoom`으로 `_runSearch`를 다시 부른다. `TiledPoiSource.load`는 타일이 이미 캐시돼 있으면 `missingTiles`가 비어 네트워크 호출 0 — 캐시에서 즉시 재필터·재병합된다.

### 4.4 UI
- 앱바에 필터 아이콘(`Icons.filter_list`) 추가.
- 탭 → 바텀시트: 7종 토글(각 카테고리 아이콘+색+라벨, on/off) + "전체 선택/해제". 기본 전부 ON.
- 확정 시 `MapScreen`의 `_visibleCategories` 갱신 + 위 재적용.
- 파일: `lib/ui/category_filter_sheet.dart`(신규, `showCategoryFilterSheet(context, current) -> Future<Set<PlaceCategory>?>` 패턴, 취소면 null).

## 5. 데이터 흐름 요약

```
onCameraIdle(bounds, zoom)
  → TiledPoiSource.load(bounds, zoom)         // zoom<16 → 일반 POI 없음
      → ambient POIs (캐시 누적)
  → ambient.where(bucket ∈ _visibleCategories) // 카테고리 필터(일반만)
  → + savedOverlay + friend extraPins          // 항상, 필터/줌 무관
  → setPins(recs)
_buildPins(recs, _camZoom)
  → PlacePin(saved||fc>0)  : 항상 렌더(이름표 포함)
  → CategoryDot(그 외)     : _camZoom>=16 일 때만, 이름표 없이
```

## 6. 테스트

- `CategoryDot`가 이름표를 렌더하지 않음 / `PlacePin`은 이름표 유지(위젯 테스트, place_pin_test).
- 카테고리 필터가 일반 POI만 거르고 친구/저장은 통과시킴(map_screen 병합 로직 — 순수 필터 부분을 테스트 가능하면 단위, 아니면 위젯).
- `category_filter_sheet`가 현재 선택을 표시하고 토글 결과를 반환(위젯 테스트).
- 줌 게이팅(`_buildPins`의 `_camZoom` 분기)·`minBrowseZoom` 상향은 플랫폼뷰라 온디바이스 검증(줌<16 친구/저장만, ≥16 일반 등장).
- 회귀: v2.2 타일 로딩·팝핑 수정, 친구/저장 오버레이, 정보카드 유지.

## 7. 에러 / 엣지

- 필터로 모든 카테고리를 끄면 일반 POI 0 — 친구/저장만(허용, 의도된 상태).
- 이름표 없는 점도 탭 히트영역 유지(`GestureDetector` `HitTestBehavior.opaque`는 이미 CategoryDot에 있음). 점만 남아 히트영역이 작아지므로 필요 시 최소 탭 타깃 확인(온디바이스).
- 줌 임계값 Z=16은 상수 — 온디바이스에서 붐빔/희소 균형 보고 조정.

## 8. 제외 / 다음

- 클러스터링(개수 버블) = 후속(필요 시).
- 친구/저장 핀 필터링·라벨 충돌회피 = 안 함.
- 필터 상태 영속화(앱 재시작 후 유지) = 후속(현재는 세션 한정).
