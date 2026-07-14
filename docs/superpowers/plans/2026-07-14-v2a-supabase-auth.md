# 오다가다 v2.0a — Supabase + 구글 인증 토대 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 오다가다에 Supabase 백엔드 연결과 **구글 로그인**을 붙여, 익명으로 둘러보다가 로그인하면 프로필이 생기고 세션이 유지되는 토대를 만든다. (저장 기능은 다음 계획 v2.0b에서 이 위에 얹는다.)

**Architecture:** `supabase_flutter`로 Supabase Auth를 초기화하고, 얇은 `AuthController`(ChangeNotifier)가 Supabase 인증 상태를 앱 모델 `AppUser`로 변환해 노출한다. Supabase User→AppUser 매핑은 순수 함수로 분리해 단위 테스트한다. 로그인은 첫 실행 강제가 아니라, 앱바의 계정 아이콘에서 로그인 시트를 띄우는 방식. 프로필 행은 회원가입 시 DB 트리거가 자동 생성한다.

**Tech Stack:** Flutter, `supabase_flutter`(Auth+DB), Google OAuth(Supabase provider), 기존 `flutter_dotenv`.

## Global Constraints

- 설계 문서: `docs/superpowers/specs/2026-07-14-social-map-v2-design.md`. 이 계획은 그 문서의 **v2.0 중 "로그인 + 백엔드 토대"** 범위.
- **로그인은 첫 실행 강제 금지** — 익명 둘러보기 허용, 계정 아이콘에서 로그인 유도.
- 이번 계획의 로그인 제공자는 **구글만**. Apple/카카오는 후속 계획(추가 플랫폼 설정 필요).
- 비밀키는 **`.env`(gitignore)** 로만. `SUPABASE_URL`은 공개돼도 무방하나 관례상 `.env`에 둠. `SUPABASE_ANON_KEY`는 공개 가능한 anon 키(RLS로 보호). 서비스롤 키는 절대 앱에 넣지 않음.
- 패키지명 `odagada`, 앱 번들 ID `com.odagada.app`, Android namespace `com.odagada.odagada`.
- OAuth 콜백 딥링크 스킴: **`io.supabase.odagada://login-callback/`** (Android intent-filter + Supabase redirect 등록 일치해야 함).
- 프라이버시 원칙: RLS로 "본인 데이터만" DB 레벨 강제(이 계획에선 profiles에 적용).
- 순수 로직(매핑)은 `flutter test`로 단위 테스트. 기존 v1 테스트 27개 회귀 유지.
- Flutter 3.44.6, Dart 3.12. 에뮬레이터 실행: `flutter run -d emulator-5554`.

---

## File Structure

```
lib/
  config/app_config.dart          # (수정) SUPABASE_URL / SUPABASE_ANON_KEY getter 추가
  main.dart                       # (수정) Supabase.initialize 추가
  auth/
    app_user.dart                 # AppUser 모델 + appUserFrom(id, metadata) 순수 매핑
    auth_controller.dart          # ChangeNotifier: Supabase auth → AppUser, signInWithGoogle, signOut
  ui/
    login_sheet.dart              # 로그인 바텀시트(구글 버튼)
    account_button.dart           # 앱바 계정 아이콘(익명→로그인시트 / 로그인→메뉴+로그아웃)
supabase/
  migrations/0001_profiles.sql    # profiles 테이블 + RLS + 회원가입 트리거
test/
  auth/app_user_test.dart         # appUserFrom 단위 테스트
  ui/login_sheet_test.dart        # 로그인 시트 위젯 테스트
docs/superpowers/plans/...        # 이 문서
android/app/src/main/AndroidManifest.xml  # (수정) OAuth 콜백 intent-filter
```

---

## Task 0: 외부 셋업 + supabase_flutter 의존성 + 초기화

**Files:**
- Modify: `pubspec.yaml`
- Modify: `.env`, `.env.example`
- Modify: `lib/config/app_config.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `AppConfig.supabaseUrl` (String), `AppConfig.supabaseAnonKey` (String). `Supabase.instance.client` 전역 사용 가능.

- [ ] **Step 1: Supabase 프로젝트 생성 (사용자)**

https://supabase.com → 새 프로젝트 생성(무료). 생성 후 **Project Settings → API** 에서:
- **Project URL** (예: `https://abcd.supabase.co`)
- **anon public key** (긴 JWT)
두 값을 복사.

- [ ] **Step 2: 구글 OAuth provider 설정 (사용자 + 안내)**

1. **Google Cloud Console**(이미 사용 중인 프로젝트) → API 및 서비스 → 사용자 인증 정보 → **OAuth 2.0 클라이언트 ID 만들기** → 유형 **웹 애플리케이션**.
2. **승인된 리디렉션 URI**에 Supabase 콜백 추가: `https://<project-ref>.supabase.co/auth/v1/callback`
3. 생성된 **클라이언트 ID / 시크릿**을 복사.
4. **Supabase 대시보드 → Authentication → Providers → Google** 사용 설정 후 클라이언트 ID/시크릿 붙여넣기 → 저장.
5. **Supabase → Authentication → URL Configuration → Redirect URLs** 에 딥링크 추가: `io.supabase.odagada://login-callback/`

- [ ] **Step 3: 키를 .env에 추가**

`.env`(커밋 안 됨)에 추가:
```
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_ANON_KEY=<anon public key>
```
`.env.example`에도 자리표시 추가:
```
SUPABASE_URL=여기에_프로젝트_URL
SUPABASE_ANON_KEY=여기에_anon_public_key
```

- [ ] **Step 4: 의존성 추가**

Run:
```bash
cd ~/dev/odagada
flutter pub add supabase_flutter
```
Expected: `pubspec.yaml`에 `supabase_flutter` 추가.

- [ ] **Step 5: AppConfig에 getter 추가**

`lib/config/app_config.dart`의 마지막 getter 뒤(클래스 닫는 `}` 앞)에 추가:
```dart
  static String get supabaseUrl {
    final v = dotenv.env['SUPABASE_URL'];
    if (v == null || v.isEmpty) {
      throw StateError('SUPABASE_URL이 .env에 없습니다.');
    }
    return v;
  }

  static String get supabaseAnonKey {
    final v = dotenv.env['SUPABASE_ANON_KEY'];
    if (v == null || v.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY가 .env에 없습니다.');
    }
    return v;
  }
```

- [ ] **Step 6: main.dart에서 Supabase 초기화**

`lib/main.dart`를 아래로 교체:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'web/maps_loader.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  if (kIsWeb) {
    await loadGoogleMapsJs(AppConfig.googleMapsApiKey);
  }
  runApp(const OdagadaApp());
}
```

- [ ] **Step 7: 빌드 확인 + 커밋**

Run:
```bash
cd ~/dev/odagada
flutter analyze
flutter test
```
Expected: analyze 에러 없음, 기존 27개 테스트 통과.
```bash
git add pubspec.yaml pubspec.lock lib/config/app_config.dart lib/main.dart .env.example
git commit -m "chore: Supabase 초기화 + AppConfig 키 (v2.0a 토대)"
```
(`.env`는 gitignore로 커밋 안 됨.)

---

## Task 1: profiles 스키마 + RLS + 회원가입 트리거

**Files:**
- Create: `supabase/migrations/0001_profiles.sql`

**Interfaces:**
- Produces: `public.profiles(id, display_name, avatar_url, auth_provider, created_at)` 테이블. 회원가입 시 자동 프로필 생성.

- [ ] **Step 1: 마이그레이션 SQL 작성**

Create `supabase/migrations/0001_profiles.sql`:
```sql
-- 프로필: auth.users 1:1
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  auth_provider text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- 본인 프로필만 접근
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- 회원가입 시 프로필 자동 생성
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, avatar_url, auth_provider)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url',
    new.raw_app_meta_data->>'provider'
  );
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

- [ ] **Step 2: Supabase에 적용 (사용자)**

Supabase 대시보드 → **SQL Editor** → 위 파일 내용을 붙여넣고 **Run**.
Expected: "Success. No rows returned". **Table Editor**에 `profiles` 테이블이 보임.

- [ ] **Step 3: 커밋**

```bash
git add supabase/migrations/0001_profiles.sql
git commit -m "feat(db): profiles 테이블 + RLS + 회원가입 트리거"
```

---

## Task 2: AppUser 모델 + 순수 매핑

**Files:**
- Create: `lib/auth/app_user.dart`
- Test: `test/auth/app_user_test.dart`

**Interfaces:**
- Produces:
  - `class AppUser { final String id; final String? displayName; final String? avatarUrl; const AppUser({required id, displayName, avatarUrl}); }`
  - `AppUser appUserFrom(String id, Map<String, dynamic>? metadata)` — metadata의 `full_name`/`name`, `avatar_url`에서 표시명·아바타 추출.

- [ ] **Step 1: 실패 테스트 작성**

Create `test/auth/app_user_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/auth/app_user.dart';

void main() {
  test('full_name과 avatar_url을 매핑한다', () {
    final u = appUserFrom('uid-1', {
      'full_name': '홍길동',
      'avatar_url': 'https://img/a.png',
    });
    expect(u.id, 'uid-1');
    expect(u.displayName, '홍길동');
    expect(u.avatarUrl, 'https://img/a.png');
  });

  test('full_name이 없으면 name을 쓴다', () {
    final u = appUserFrom('uid-2', {'name': 'Gildong'});
    expect(u.displayName, 'Gildong');
  });

  test('metadata가 null이면 표시명/아바타는 null', () {
    final u = appUserFrom('uid-3', null);
    expect(u.id, 'uid-3');
    expect(u.displayName, isNull);
    expect(u.avatarUrl, isNull);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/auth/app_user_test.dart`
Expected: FAIL — `app_user.dart` 미존재.

- [ ] **Step 3: 구현 작성**

Create `lib/auth/app_user.dart`:
```dart
/// 앱 내부에서 쓰는 로그인 사용자 표현(Supabase User와 분리).
class AppUser {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  const AppUser({required this.id, this.displayName, this.avatarUrl});
}

/// Supabase user id + userMetadata를 AppUser로 변환(순수).
AppUser appUserFrom(String id, Map<String, dynamic>? metadata) {
  final m = metadata ?? const {};
  return AppUser(
    id: id,
    displayName: (m['full_name'] ?? m['name']) as String?,
    avatarUrl: m['avatar_url'] as String?,
  );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/auth/app_user_test.dart`
Expected: PASS (3개).

- [ ] **Step 5: 커밋**

```bash
git add lib/auth/app_user.dart test/auth/app_user_test.dart
git commit -m "feat(auth): AppUser 모델 + 순수 매핑"
```

---

## Task 3: AuthController (Supabase 인증 래퍼)

**Files:**
- Create: `lib/auth/auth_controller.dart`

**Interfaces:**
- Consumes: `AppUser`, `appUserFrom`, `Supabase.instance.client`.
- Produces:
  - `class AuthController extends ChangeNotifier { AppUser? get user; bool get isSignedIn; Future<void> signInWithGoogle(); Future<void> signOut(); }`
  - 생성 시 현재 세션 반영 + `onAuthStateChange` 구독으로 상태 변화 시 `notifyListeners()`.

- [ ] **Step 1: 구현 작성**

> 참고: `AuthController`는 Supabase 클라이언트에 의존하는 얇은 통합 래퍼라 단위 테스트 대신 Task 5의 실기기 E2E로 검증한다(핵심 매핑은 Task 2에서 이미 순수 테스트됨). 이는 의도된 설계다.

Create `lib/auth/auth_controller.dart`:
```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_user.dart';

/// Supabase Auth를 앱 모델(AppUser)로 노출하는 얇은 컨트롤러.
class AuthController extends ChangeNotifier {
  final SupabaseClient _client;
  StreamSubscription<AuthState>? _sub;
  AppUser? _user;

  AuthController([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client {
    _user = _mapCurrent();
    _sub = _client.auth.onAuthStateChange.listen((_) {
      _user = _mapCurrent();
      notifyListeners();
    });
  }

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  AppUser? _mapCurrent() {
    final u = _client.auth.currentUser;
    return u == null ? null : appUserFrom(u.id, u.userMetadata);
  }

  /// 구글 OAuth 로그인. 모바일은 딥링크 콜백으로 복귀, 웹은 리다이렉트.
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo:
          kIsWeb ? null : 'io.supabase.odagada://login-callback/',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 2: 컴파일 확인**

Run: `flutter analyze lib/auth/auth_controller.dart`
Expected: 에러 없음.

- [ ] **Step 3: 커밋**

```bash
git add lib/auth/auth_controller.dart
git commit -m "feat(auth): AuthController — 구글 로그인/로그아웃/상태"
```

---

## Task 4: 로그인 바텀시트 UI

**Files:**
- Create: `lib/ui/login_sheet.dart`
- Test: `test/ui/login_sheet_test.dart`

**Interfaces:**
- Produces:
  - `class LoginSheet extends StatelessWidget { LoginSheet({required VoidCallback onGoogle}); }` — "계속하려면 로그인" 안내 + "구글로 계속하기" 버튼(탭 시 `onGoogle`).
  - `Future<void> showLoginSheet(BuildContext context, {required VoidCallback onGoogle})` — 바텀시트로 띄우는 헬퍼.

- [ ] **Step 1: 위젯 테스트 작성**

Create `test/ui/login_sheet_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/ui/login_sheet.dart';

void main() {
  testWidgets('구글 버튼을 표시하고 탭하면 콜백을 호출한다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LoginSheet(onGoogle: () => tapped = true)),
    ));

    expect(find.textContaining('로그인'), findsWidgets);
    expect(find.text('구글로 계속하기'), findsOneWidget);

    await tester.tap(find.text('구글로 계속하기'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/ui/login_sheet_test.dart`
Expected: FAIL — `login_sheet.dart` 미존재.

- [ ] **Step 3: 구현 작성**

Create `lib/ui/login_sheet.dart`:
```dart
import 'package:flutter/material.dart';

/// 로그인 유도 바텀시트 내용. 이번 계획은 구글만.
class LoginSheet extends StatelessWidget {
  final VoidCallback onGoogle;
  const LoginSheet({super.key, required this.onGoogle});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('오다가다 로그인',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('저장·친구 기능을 쓰려면 로그인하세요.',
                style: TextStyle(fontSize: 15, color: Colors.black54),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: onGoogle,
                icon: const Icon(Icons.login),
                label: const Text('구글로 계속하기',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 로그인 시트를 바텀시트로 띄운다.
Future<void> showLoginSheet(BuildContext context,
    {required VoidCallback onGoogle}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => LoginSheet(onGoogle: onGoogle),
  );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/ui/login_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/ui/login_sheet.dart test/ui/login_sheet_test.dart
git commit -m "feat(ui): 로그인 바텀시트(구글)"
```

---

## Task 5: 앱 배선 — 계정 버튼 + OAuth 콜백 + E2E 검증

**Files:**
- Create: `lib/ui/account_button.dart`
- Modify: `lib/app.dart`
- Modify: `lib/ui/map_screen.dart:80-90` (앱바 actions에 계정 버튼 추가)
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `AuthController`, `showLoginSheet`, `AppUser`.
- Produces: `class AccountButton extends StatelessWidget { AccountButton({required AuthController auth}); }` — 앱바 액션. 익명이면 계정 아이콘→로그인 시트, 로그인 상태면 아바타/이니셜→메뉴(표시명 + 로그아웃).

- [ ] **Step 1: AccountButton 작성**

Create `lib/ui/account_button.dart`:
```dart
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import 'login_sheet.dart';

/// 앱바 계정 버튼. 익명↔로그인 상태를 AuthController로부터 반영.
class AccountButton extends StatelessWidget {
  final AuthController auth;
  const AccountButton({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (!auth.isSignedIn) {
          return IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: '로그인',
            onPressed: () =>
                showLoginSheet(context, onGoogle: auth.signInWithGoogle),
          );
        }
        final name = auth.user?.displayName ?? '사용자';
        return PopupMenuButton<String>(
          icon: const Icon(Icons.account_circle),
          tooltip: name,
          onSelected: (v) {
            if (v == 'signout') auth.signOut();
          },
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text(name)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'signout', child: Text('로그아웃')),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 2: app.dart에서 AuthController 생성·주입**

`lib/app.dart`를 StatefulWidget으로 바꿔 `AuthController`를 보유하고 MapScreen에 전달한다. `OdagadaApp`을 아래로 교체:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth/auth_controller.dart';
import 'location/location_source.dart';
import 'location/location_engine.dart';
import 'pipeline/recommendation_pipeline.dart';
import 'poi/poi_provider.dart';
import 'poi/google_places_provider.dart';
import 'recommend/recommend_engine.dart';
import 'config/app_config.dart';
import 'ui/map_screen.dart';
import 'ui/map_view.dart';
import 'ui/google_map_view.dart';
import 'ui/navigation_launcher.dart';

class OdagadaApp extends StatefulWidget {
  const OdagadaApp({super.key});
  @override
  State<OdagadaApp> createState() => _OdagadaAppState();
}

class _OdagadaAppState extends State<OdagadaApp> {
  final AuthController _auth = AuthController();

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ProviderRegistry()
      ..register(GooglePlacesProvider(
        client: http.Client(),
        apiKey: AppConfig.googleMapsApiKey,
      ));

    final LocationSource locationSource =
        kIsWeb ? const FixedLocationSource() : GeolocatorLocationSource();

    Widget mapBuilder({
      required void Function(MapController) onReady,
      required PinTapCallback onPinTap,
    }) =>
        GoogleMapView(onReady: onReady, onPinTap: onPinTap);

    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );

    return MaterialApp(
      title: '오다가다',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: MapScreen(
        auth: _auth,
        locationSource: locationSource,
        pipeline: pipeline,
        registry: registry,
        navigationLauncher: NavigationLauncher(),
        mapBuilder: mapBuilder,
      ),
    );
  }
}
```

- [ ] **Step 3: MapScreen에 auth 파라미터 + 앱바 계정 버튼 추가**

`lib/ui/map_screen.dart`에서:
(a) import 추가(파일 상단 import 목록에):
```dart
import '../auth/auth_controller.dart';
import 'account_button.dart';
```
(b) `MapScreen` 위젯에 `final AuthController auth;` 필드와 생성자 `required this.auth,` 추가.
(c) 앱바 `actions:` 리스트의 기존 `IconButton(icon: const Icon(Icons.tune) ...)` **앞에** 계정 버튼 추가:
```dart
          AccountButton(auth: widget.auth),
```

- [ ] **Step 4: Android OAuth 콜백 intent-filter 추가**

`android/app/src/main/AndroidManifest.xml`의 `.MainActivity` `<activity>` 안(기존 LAUNCHER intent-filter 뒤)에 추가:
```xml
            <intent-filter android:label="odagada_oauth">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="io.supabase.odagada" android:host="login-callback"/>
            </intent-filter>
```

- [ ] **Step 5: 분석 + 전체 테스트**

Run:
```bash
cd ~/dev/odagada
flutter analyze
flutter test
```
Expected: analyze 에러 없음. 기존 27개 + 신규(app_user 3, login_sheet 1) 포함 전부 통과.

- [ ] **Step 6: 실기기 E2E 검증 (에뮬레이터)**

에뮬레이터가 없으면 먼저 실행:
```bash
export PATH="$HOME/Library/Android/sdk/emulator:$HOME/Library/Android/sdk/platform-tools:/opt/homebrew/bin:$PATH"
emulator -avd odagada_pixel -gpu auto -no-boot-anim &
adb wait-for-device
cd ~/dev/odagada && flutter run -d emulator-5554
```
확인 항목:
- [ ] 앱바 우측에 **계정 아이콘** 표시(익명 상태).
- [ ] 아이콘 탭 → **로그인 시트**("구글로 계속하기") 표시.
- [ ] "구글로 계속하기" → 브라우저로 구글 로그인 → 앱으로 복귀(딥링크).
- [ ] 복귀 후 아이콘이 **로그인 상태**로 바뀌고, 탭하면 표시명 + 로그아웃 메뉴.
- [ ] Supabase 대시보드 **Table Editor → profiles** 에 새 행(내 프로필) 생성 확인.
- [ ] 로그아웃 → 다시 익명 상태로.

문제 시 systematic-debugging으로 원인부터 재현/격리. (자주 나오는 이슈: Supabase Redirect URLs에 `io.supabase.odagada://login-callback/` 미등록, 구글 OAuth 리디렉션 URI 불일치.)

- [ ] **Step 7: 커밋**

```bash
git add lib/ui/account_button.dart lib/app.dart lib/ui/map_screen.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat(auth): 계정 버튼 + OAuth 콜백 배선 + 앱 통합 (v2.0a 완성)"
```

---

## Self-Review (작성자 점검)

- **스펙 커버리지 (v2.0a 범위):**
  - 로그인(구글) + Supabase Auth → Task 0·3·4·5. ✅
  - 백엔드 셋업(Supabase 초기화) → Task 0. ✅
  - profiles + RLS + 자동 프로필 → Task 1. ✅
  - 첫 실행 강제 아님(계정 버튼에서 유도) → Task 5. ✅
  - 카카오는 로그인용만/이번 계획 제외, Apple 제외 → Global Constraints 명시. ✅
  - RLS로 본인 데이터만(profiles) → Task 1. ✅
  - (v2.0 나머지: 저장/카테고리/직접추가/내 목록 → **다음 계획 v2.0b**. v2.1 소셜은 그 이후.)
- **플레이스홀더 스캔:** TBD/TODO 없음. 각 코드 스텝에 실제 코드 포함. (사용자 대시보드 값 입력은 외부 설정이라 자리표시 안내로 처리.) ✅
- **타입 일관성:** `appUserFrom(String,Map?)`, `AuthController.signInWithGoogle/signOut/user/isSignedIn`, `AccountButton(auth:)`, `MapScreen(auth:...)`, `showLoginSheet(context, onGoogle:)` 이름·시그니처가 태스크 전반에서 일치. ✅
- **알려진 통합 검증:** AuthController는 Supabase 의존 래퍼라 단위 테스트 대신 Task 5 E2E로 검증(설계 의도, 순수 매핑은 Task 2 테스트). ✅

---

## 후속 계획 (이 계획 다음)
- **v2.0b — 저장**: SavedPlace 모델 + 카테고리 매핑(7종, TDD) + saved_places 스키마/RLS + SavedPlaceRepository + 저장 UI(핀탭/검색/직접추가) + 내 저장 목록·지도 표시.
- **v2.1 — 소셜**: 친구 초대 링크/QR + 딥링크 + 친구 저장 레이어("N명", 핀 3상태 겹침 강조) + 통합 정보카드 + 주행 추천 전환.

---

## 실행 방법
1. **Subagent-Driven (권장)** — 태스크마다 새 서브에이전트 구현 + 태스크 사이 리뷰.
2. **Inline Execution** — 현재 세션에서 체크포인트 단위로 실행.
