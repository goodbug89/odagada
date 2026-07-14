# 오다가다 v2 — 소셜 맛집 지도 설계 문서

- 작성일: 2026-07-14
- 상태: 브레인스토밍 승인 → 구현 계획(writing-plans)으로 이어짐 (첫 계획은 v2.0 범위)
- 전제: v1(MVP) 완료 — 구글맵 + Google Places + 브랜드 핀 + 정보카드가 웹·Android에서 동작 확인됨
- 저장소: `~/dev/odagada`

## 1. 비전 / 핵심 가치

오다가다 v2는 **친구들이 큐레이션한 소셜 맛집 지도**다. 지나가다 *"어? 저기는 내 친구 5명이 맛집으로 저장한 곳이네?"* 를 알 수 있게 한다.

핵심 통찰 — **조작 불가능한 신뢰**:
기존 지도/리뷰 앱은 평점이 공개라서 사장님이 보고, 신경 쓰고, 체험단·광고·자작 리뷰로 관리(조작)한다. 오다가다는 반대다. 저장·평가가 **친구 그룹 안에서만** 보이므로 사장님은 자기 가게가 누구에게 어떻게 저장됐는지 알 수도 없다. 볼 수 없으니 조작할 대상이 없고, 광고가 개입할 여지가 사라진다. 남는 신호는 오직 *"나와 취향을 공유하는 친구가 여기 갔다"* 하나 — 그래서 신뢰도가 구조적으로 높다.

## 2. 설계 원칙 (불변)

1. **공개 평점 없음** — 전역 별점·랭킹을 만들지 않는다 (만드는 순간 조작 대상이 생김).
2. **사장/광고 대면 화면 없음** — B2B 측면을 두지 않는다.
3. **신호는 폐쇄 친구그래프 안에서만** — "내 친구 N명이 저장"만 노출한다.

이 원칙은 v2 전 기능이 지켜야 하는 제약이다.

## 3. 사용자 & 맥락

- v1과 동일한 주 사용자(여행·맛집 탐방 운전자)에, **"내가 인정한 곳을 모으고, 취향 맞는 친구들과 공유하고 싶은"** 동기가 더해진다.
- 글로벌 대응: 지도·장소 데이터는 Google(전 세계), 로그인은 Google/Apple + 한국용 카카오.

## 4. 범위 & 단계 (Phasing)

이 문서는 v2 전체 비전을 담되, **구현 계획은 v2.0부터** 작성한다.

### v2.0 — 토대 (첫 구현 계획 대상)
- 로그인 (Google/Apple + 카카오) — Supabase Auth
- 백엔드(Supabase) 셋업 + 데이터 모델
- **저장** 기능: 3가지 진입(핀 탭 / 검색 / 직접 추가) + 한줄 메모 + 카테고리 태그
- **내 저장 목록** 화면 + 내 저장 장소를 지도에 표시
- 소셜은 아직 없음. "로그인하고 내 맛집을 저장·관리"가 端에서 端까지 도는 상태.

### v2.1 — 소셜
- **친구 연결**: 초대 링크 / QR (앱 내 자체 소셜 그래프)
- **친구 저장 레이어**: 지도에 "친구 N명 저장" 배지
- **핀 탭 → 누가 저장했는지 + 각자 메모**
- (킬러) **주행 추천을 친구-저장 신호로 전환** — 주변에서 친구가 저장한 곳을 우선 추천

### 제외 / 나중
- 저장 시 "비공개" 토글 (기본은 친구 공개; 비공개 옵션은 v2.1+)
- 직접 추가형 장소의 사용자 간 자동 병합(근접 좌표 기반)
- 부동산·골프 등 객관 정보 오버레이(별개 축), TTS

## 5. 핵심 결정 (확정)

| 항목 | 결정 | 이유 |
|---|---|---|
| 지도 / 장소 | Google Maps + Google Places (New) | 글로벌 커버리지. v1에서 검증됨 |
| 백엔드 | Supabase (Postgres + Auth + RLS) | 관계형 집계("N명 저장")에 SQL이 자연스럽고, RLS로 "친구만 조회"를 DB가 강제 |
| 로그인 | Google/Apple + 카카오, Supabase Auth OAuth | 글로벌 + 한국. 카카오는 신원용만(친구목록 API 미사용) |
| 로그인 시점 | 첫 실행 강제 아님 | 익명 둘러보기 허용, 저장·소셜 시점에 로그인 유도(이탈↓) |
| 친구 맺기 | 초대 링크(1:1/그룹) / QR (상호 친구) | 카카오 친구목록의 검수·데이터사용 제한 회피. 폐쇄 신뢰 그래프에 적합 |
| 친구 자동발견 | **안 함(연락처 매칭 없음)** | 프라이버시 최우선 — 주소록 업로드는 우리 정체성과 상충. 링크/QR만으로 연결 |
| 초대 링크 전달 | 딥링크 서비스(예: Branch)로 **디퍼드 딥링크** | 앱 없어도 설치→로그인→연결이 매끄럽게. Firebase Dynamic Links는 2025 종료 |
| 저장 액션 | 단일 "보증" + 선택 메모 | 신호가 명확. "저장 = 내가 인정한 곳" |
| 저장 공개 | 친구에게 공개가 기본 | 그게 앱의 목적. 비공개는 나중 |
| 친구 저장 표시 | 지도엔 숫자, 탭하면 누가+메모 | 한눈엔 깔끔, 탭하면 "누가 추천"이라는 신뢰 페이오프 |

### 왜 카카오 친구목록을 안 쓰나 (근거)
카카오 친구 목록 API는 (1) 비즈 앱 전환 + 친구 API 검수가 필요하고(이미 비즈 심사 반려됨), (2) *"친구 정보를 분석·조합하거나 다른 사용자에게 제공하는 일체의 행위 엄격 금지"* 규정이 우리 핵심 기능("친구들 저장을 집계")과 정면 충돌한다. 따라서 카카오는 **로그인(신원)에만** 쓰고, 친구 관계는 앱 내 자체 그래프로 만든다.

## 6. 아키텍처

v1 위에 얹는다. 기존 재사용: `LocationEngine`, `GoogleMapView`(핀 오버레이), `GooglePlacesProvider`, `RecommendEngine`, `RecommendationPipeline`.

```
[Auth]  Supabase Auth (Google/Apple/Kakao OAuth)
   │  로그인된 user
   ▼
[SavedPlaceRepository]  Supabase 저장/조회 (내 저장 CRUD)
[FriendRepository]      초대 링크 생성/수락, 친구 관계 (v2.1)
[SocialAggregator]      "친구 N명 저장" 집계 쿼리 (v2.1)
   │
   ▼
[Map layers]  내 저장 핀 / (v2.1) 친구 저장 핀 — 기존 GoogleMapView 오버레이 확장
[Save UI]     핀 탭 저장 버튼 / 검색 / 길게눌러 직접추가 / 메모 입력
[Friend UI]   초대 링크·QR 생성/수락, 친구 목록 (v2.1)
```

### 설계 원칙 (모듈)
- 각 Repository는 **하나의 책임**(저장 / 친구 / 집계)을 가지며 Supabase 클라이언트를 주입받아 목킹 테스트 가능.
- 로그인·저장·친구 로직을 UI에서 분리해 독립 테스트한다.
- 프라이버시는 앱 코드가 아니라 **RLS(DB)** 가 강제한다 — 코드 실수로도 남의 데이터가 새지 않게.

## 7. 컴포넌트 상세

### 7.1 AuthService
- 책임: Supabase Auth로 Google/Apple/Kakao OAuth 로그인, 세션 유지, 로그아웃. 현재 로그인 사용자 노출.
- 익명 상태 허용. 저장/소셜 액션 시도 시 로그인 시트를 띄운다.

### 7.2 SavedPlaceRepository
- 책임: 내 저장 장소 CRUD(Supabase). 저장/삭제/목록.
- 저장 항목 두 형태: **Places 연결형**(Google place_id 有) / **직접 추가형**(place_id 없이 좌표+이름).

### 7.3 저장 UI / 진입
- **핀 탭 → 정보 카드 "저장" 버튼** (기존 카드 재사용, 기본 진입)
- **검색 → 저장** (Google Places text search 결과에서 저장)
- **지도 길게 누르기 → 직접 추가** (그 좌표에 핀 생성 → 이름 입력 → 저장). 핀 없는 곳(신규·푸드트럭·숨은 스팟) 대응.
- 저장 시 선택적 **한줄 메모** + **카테고리 태그**(유연 태그, 하드코딩 아님).

### 7.4 내 저장 목록
- 저장한 장소 리스트(이름·카테고리·메모·거리) + 지도 핀 표시. 삭제 가능.

### 7.5 FriendRepository + 초대 흐름 (v2.1)
- 초대 링크(토큰) 생성 / QR. **연락처 매칭 없음** — 링크/QR로만 연결(프라이버시 최우선). 1:1 또는 단톡방 공유(한 링크로 여러 명 연결) 모두 지원.
- **상호 친구**: 초대받은 사람이 로그인 후 "수락"하는 순간 양방향 관계 생성.
- **딥링크 흐름** (딥링크 서비스, 예: Branch):
  - 앱 있음 → 링크 탭 시 앱이 유니버설/앱 링크로 바로 열려 "OO님과 친구?" → 수락
  - 앱 없음 → 웹 랜딩 → 스토어 설치 → 첫 실행 시 **디퍼드 딥링크로 초대 토큰 복원** → 로그인 → "OO님과 친구?" → 수락
- 친구 목록 조회/삭제.

### 7.6 SocialAggregator (v2.1)
- 특정 장소(place_id)에 대해 **내 친구 중 저장한 사람 수/명단 + 메모**를 집계.
- Places 연결형만 자동 집계(같은 place_id로 묶임). 직접 추가형은 개별 핀.

### 7.7 지도 레이어 & 주행 추천
- v2.0: 내 위치 + 내 저장 핀 + 발견용 주변 Places.
- v2.1: **친구 저장 핀 레이어**("N명" 배지) + 주행 시 주변 친구-저장 장소 우선 추천(RecommendEngine 입력을 Places→친구저장으로 전환).

## 8. 데이터 모델 (Supabase / Postgres)

```
profiles            (auth.users 1:1)
  id (uuid, FK auth.users)     PK
  display_name text
  avatar_url text
  auth_provider text            -- google|apple|kakao

saved_places
  id uuid PK
  owner_id uuid FK profiles
  place_id text NULL            -- Google Places id (연결형). NULL이면 직접추가형
  name text
  lat double, lng double
  category text NULL            -- 유연 태그
  memo text NULL
  is_public boolean DEFAULT true -- 친구에게 공개(v2.0 항상 true, 토글은 나중)
  created_at timestamptz

friendships                    -- (v2.1) 상호 친구
  user_a uuid FK profiles
  user_b uuid FK profiles
  status text                  -- pending|accepted
  created_at timestamptz
  PK (user_a, user_b)

invites                        -- (v2.1) 초대 링크
  token text PK
  inviter_id uuid FK profiles
  created_at, expires_at timestamptz
  accepted_by uuid NULL
```

### RLS 정책 (프라이버시를 DB가 강제)
- `saved_places`: 소유자는 자기 것 CRUD. **친구는** `is_public`이고 소유자가 내 accepted 친구일 때만 SELECT.
- `friendships` / `invites`: 관련 당사자만 접근.

### "친구 N명 저장" 집계 (v2.1)
주어진 place_id와 내 accepted 친구 집합에 대해 `saved_places ⨝ friendships` 로 저장한 친구 수·명단·메모를 반환.

## 9. 에러 처리
- 네트워크/Supabase 실패: 마지막 조회 결과 유지, 쓰기는 재시도. 사용자 방해 최소화(기존 원칙).
- 로그인 실패/취소: 익명 상태로 되돌리고 둘러보기 계속 허용.
- Places/GPS 실패: v1 기존 처리 유지.

## 10. 테스트 전략
- **Repositories**(SavedPlace/Friend): Supabase 클라이언트 목킹 → CRUD·쿼리 매핑 단위 테스트.
- **SocialAggregator**: 고정 입력(친구 집합 + 저장들) → 집계 결과 순수 함수 테스트.
- **RLS**: 비친구가 남의 저장을 못 읽는지 정책 테스트.
- **Auth 흐름**: 로그인/로그아웃/익명 전환 통합 테스트.
- 기존 v1 단위 테스트(27개) 회귀 유지.

## 11. 미해결 (구현 계획에서 확정)
- Supabase 프로젝트 생성·환경키(.env, gitignore) 관리 방식.
- 카카오 로그인의 Supabase Auth 연동 방식(커스텀 OAuth provider 설정).
- 딥링크 서비스 선택·연동(Branch 등) + 유니버설/앱 링크 도메인 설정(v2.1).
- Apple 로그인의 iOS 설정(추후 iOS 빌드 시).
- 카테고리 태그 UX(자유 입력 vs 추천 태그 목록).
- 주행 중 안전: 저장(특히 직접추가 long-press)은 주행 중 지양 UX 검토.

## 12. 후속(v2 밖) 참고
- v1의 NavigationLauncher(길찾기)가 아직 카카오 딥링크 → 글로벌 위해 구글맵 길찾기로 교체 필요(별도 작업).
- 부동산 시세 등 객관 정보 오버레이는 소셜과 다른 축, 훨씬 나중.
