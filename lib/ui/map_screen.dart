import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../core/constants.dart';
import '../core/geo/geo_math.dart';
import '../core/models/lat_lng.dart';
import '../core/models/lat_lng_bounds.dart';
import '../core/models/place_category.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../friends/friend_repository.dart';
import '../friends/friend_save.dart';
import '../friends/invite_link.dart';
import '../friends/social_repository.dart';
import '../location/location_source.dart';
import '../poi/poi_provider.dart';
import '../poi/research_policy.dart';
import '../poi/tiled_poi_source.dart';
import '../saved/saved_place.dart';
import '../saved/saved_place_repository.dart';
import '../saved/saved_overlay.dart';
import 'accept_invite_flow.dart';
import 'account_button.dart';
import 'category_filter_sheet.dart';
import 'friends_screen.dart';
import 'map_view.dart';
import 'info_card.dart';
import 'login_sheet.dart';
import 'memo_sheet.dart';
import 'module_selector.dart';
import 'navigation_launcher.dart';
import 'saved_list_screen.dart';
import 'search_screen.dart';

class MapScreen extends StatefulWidget {
  final AuthController auth;
  final LocationSource locationSource;
  final ProviderRegistry registry;
  final NavigationLauncher navigationLauncher;
  final MapViewBuilder mapBuilder;
  final SavedPlaceRepository savedRepo;
  final FriendRepository friendRepo;
  final SocialRepository socialRepo;
  final Future<List<Poi>> Function(String query, LatLng? bias) textSearch;

  const MapScreen({
    super.key,
    required this.auth,
    required this.locationSource,
    required this.registry,
    required this.navigationLauncher,
    required this.mapBuilder,
    required this.savedRepo,
    required this.friendRepo,
    required this.socialRepo,
    required this.textSearch,
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
  List<SavedPlace> _savedPlaces = const [];
  Map<String, FriendSave> _friendSaves = const {};
  bool _following = true;
  // 임계 줌 미만이면 일반 POI 검색 자체를 건너뛴다(렌더 게이트와 같은 값).
  late final TiledPoiSource _poiSource =
      TiledPoiSource(widget.registry, minBrowseZoom: ambientPoiMinZoom);
  Set<PlaceCategory> _visibleCategories = PlaceCategory.values.toSet();

  Timer? _idleDebounce;
  LatLngBounds? _lastSearchBounds;
  double? _lastSearchZoom;
  LatLngBounds? _lastBounds;
  double? _lastZoom;
  int _searchGen = 0;
  StreamSubscription<Uri>? _linkSub;
  String? _pendingInviteToken; // 미로그인 상태로 받은 초대(로그인 후 이어서 수락)
  String? _lastAuthUserId; // 로그인/로그아웃 감지용(토큰 갱신 알림에는 재로딩 안 함)

  @override
  void initState() {
    super.initState();
    _lastAuthUserId = widget.auth.user?.id; // _start()가 초기 저장 로딩을 하므로 중복 방지
    _start();
    _initDeepLinks();
    widget.auth.addListener(_onAuthChanged);
  }

  /// 앱 시작 시 최초 링크 + 실행 중 들어오는 링크를 함께 구독한다.
  Future<void> _initDeepLinks() async {
    final links = AppLinks();
    Uri? initial;
    try {
      initial = await links.getInitialLink();
    } catch (_) {
      // 최초 링크 조회 실패는 무시(딥링크 없이 실행된 경우 포함)
    }
    if (!mounted) return; // await 도중 위젯이 dispose된 경우 구독하지 않는다.
    if (initial != null) _handleUri(initial);
    if (!mounted) return; // _handleUri가 await를 거치는 동안 dispose됐을 수 있다.
    _linkSub = links.uriLinkStream.listen(_handleUri, onError: (_) {});
  }

  /// 초대 링크만 처리한다. 로그인 콜백 등 다른 URI는 무시.
  void _handleUri(Uri uri) {
    final token = inviteTokenFromUri(uri);
    if (token == null) return;
    if (widget.auth.user == null) {
      _pendingInviteToken = token; // 로그인되면 _onAuthChanged가 이어서 처리
      if (!mounted) return;
      showLoginSheet(context, onGoogle: widget.auth.signInWithGoogle);
      return;
    }
    _acceptInvite(token);
  }

  /// 로그인/로그아웃 시 내 저장·오버레이를 갱신하고,
  /// 로그인이 완료되면 보류해 둔 초대를 이어서 수락한다.
  void _onAuthChanged() {
    final uid = widget.auth.user?.id;
    if (uid != _lastAuthUserId) {
      _lastAuthUserId = uid; // 계정이 실제로 바뀐 경우에만(토큰 갱신 알림 제외)
      _reloadSaved(); // 로그인→내 저장 표시, 로그아웃→저장·오버레이 제거
    }
    final token = _pendingInviteToken;
    if (token == null || widget.auth.user == null) return;
    _pendingInviteToken = null;
    _acceptInvite(token);
  }

  Future<void> _acceptInvite(String token) async {
    if (!mounted) return;
    final ok = await runAcceptInviteFlow(context, widget.friendRepo, token);
    if (!ok || !mounted) return;
    // 새 친구의 저장이 지도에 바로 뜨도록 현재 영역 재검색.
    final b = _lastBounds, z = _lastZoom;
    if (b != null && z != null) _runSearch(b, z);
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
    }, onError: (_) {}); // GPS 꺼짐 등 스트림 에러가 unhandled zone error가 되지 않도록
    await _reloadSaved();
  }

  Future<void> _reloadSaved() async {
    final u = widget.auth.user;
    if (u == null) {
      if (mounted) {
        setState(() {
          _savedIds = {};
          _savedPlaces = const [];
        });
      }
      _map?.setSavedIds(const {});
      return;
    }
    List<SavedPlace> places;
    try {
      places = await widget.savedRepo.listMine(u.id);
    } catch (_) {
      return; // 일시적 실패 → 기존 상태 유지
    }
    final ids = places.map((p) => p.placeId).whereType<String>().toSet();
    if (mounted) {
      setState(() {
        _savedPlaces = places;
        _savedIds = ids;
      });
    }
    _map?.setSavedIds(ids);
    // 저장이 바뀌면 현재 화면에 즉시 반영(마지막 검색 영역으로 재병합)
    final b = _lastBounds, z = _lastZoom;
    if (b != null && z != null) _runSearch(b, z);
  }

  // 카메라 정지 → 디바운스 → 중심 30m 이상 이동했을 때만 뷰포트 검색.
  void _onCameraIdle(LatLngBounds bounds, double zoom) {
    _idleDebounce?.cancel();
    _idleDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!shouldResearch(
          lastBounds: _lastSearchBounds,
          lastZoom: _lastSearchZoom,
          bounds: bounds,
          zoom: zoom)) {
        return; // 거의 안 움직이고 줌도 그대로 → 스킵
      }
      _lastSearchBounds = bounds;
      _lastSearchZoom = zoom;
      _runSearch(bounds, zoom);
    });
  }

  Future<void> _runSearch(LatLngBounds bounds, double zoom) async {
    _lastBounds = bounds;
    _lastZoom = zoom;
    final gen = ++_searchGen;
    // 일반 POI만 카테고리 필터 적용(친구/저장 오버레이는 아래에서 무관하게 병합).
    final pois = (await _poiSource.load(bounds, zoom))
        .where((p) => _visibleCategories.contains(p.bucket))
        .toList();
    // 오버레이·친구조회용 중심·반경을 뷰포트에서 파생
    final center = bounds.center;
    final radius = GeoMath.distanceMeters(center, bounds.ne);
    // 친구 저장(실패해도 나머지는 진행)
    List<FriendSave> friendSaves = const [];
    try {
      friendSaves = await widget.socialRepo.friendSavesNear(center, radius);
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'map_screen',
        context: ErrorDescription('friendSavesNear 조회 실패'),
      ));
    }
    if (!mounted || gen != _searchGen) return; // 더 최신 검색이 시작됐으면 이 결과는 버림
    final ids = pois.map((p) => p.id).toSet();
    final savedOverlay = savedPoisInViewport(_savedPlaces, center, radius)
        .where((p) => !ids.contains(p.id)) // 검색결과에 이미 있으면 중복 제거
        .toList();
    final existing = {...ids, ...savedOverlay.map((p) => p.id)};
    final social = friendOverlay(friendSaves, existing, center);
    _friendSaves = {for (final fs in friendSaves) fs.placeId: fs};
    final recs = [...pois, ...savedOverlay, ...social.extraPins]
        .map((p) => Recommendation(poi: p, score: 0))
        .toList();
    _map?.setPins(recs);
    _map?.setSavedIds(_savedIds);
    _map?.setFriendCounts(social.friendCounts);
  }

  Future<void> _onSaveToggle(Poi poi) async {
    final u = widget.auth.user;
    if (u == null) {
      showLoginSheet(context, onGoogle: widget.auth.signInWithGoogle);
      return;
    }
    try {
      if (_savedIds.contains(poi.id)) {
        await widget.savedRepo.deleteByPlaceId(ownerId: u.id, placeId: poi.id);
      } else {
        final memo = await showMemoSheet(context, placeName: poi.name);
        if (memo == null) return; // 시트 닫음 → 저장 취소
        await widget.savedRepo.save(
            ownerId: u.id, poi: poi, memo: memo.isEmpty ? null : memo);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('저장에 실패했어요.')));
      }
    }
    await _reloadSaved();
  }

  void _onPinTap(Poi poi) => setState(() => _selected = poi);

  String? _myMemoFor(String placeId) {
    for (final p in _savedPlaces) {
      if (p.placeId == placeId) return p.memo;
    }
    return null;
  }

  @override
  void dispose() {
    _idleDebounce?.cancel();
    _sub?.cancel();
    _linkSub?.cancel();
    widget.auth.removeListener(_onAuthChanged);
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
          AccountButton(
            auth: widget.auth,
            onFriends: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FriendsScreen(repo: widget.friendRepo),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchScreen(
                textSearch: widget.textSearch,
                bias: _lastBounds?.center,
                savedRepo: widget.savedRepo,
                auth: widget.auth,
                onChanged: _reloadSaved,
              ),
            )),
          ),
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
              onMapTap: () {
                if (_selected != null) setState(() => _selected = null);
              },
              onFollowChanged: (f) {
                if (mounted) setState(() => _following = f);
              },
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
                onClose: () => setState(() => _selected = null),
                myMemo: _myMemoFor(_selected!.id),
                friendNames: _friendSaves[_selected!.id]?.friendNames,
                friendMemos: _friendSaves[_selected!.id]?.memos,
              ),
            ),
        ],
      ),
    );
  }
}
