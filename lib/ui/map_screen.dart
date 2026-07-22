import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../core/geo/geo_math.dart';
import '../core/models/lat_lng.dart';
import '../core/models/lat_lng_bounds.dart';
import '../core/models/place_category.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import '../friends/friend_repository.dart';
import '../friends/friend_save.dart';
import '../friends/social_repository.dart';
import '../location/location_source.dart';
import '../poi/poi_provider.dart';
import '../poi/tiled_poi_source.dart';
import '../saved/saved_place.dart';
import '../saved/saved_place_repository.dart';
import '../saved/saved_overlay.dart';
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
  // 임계 줌 16 미만이면 일반 POI 검색 자체를 건너뛴다(렌더 게이트와 같은 값).
  late final TiledPoiSource _poiSource =
      TiledPoiSource(widget.registry, minBrowseZoom: 16);
  Set<PlaceCategory> _visibleCategories = PlaceCategory.values.toSet();

  Timer? _idleDebounce;
  LatLngBounds? _lastSearchBounds;
  double? _lastSearchZoom;
  LatLngBounds? _lastBounds;
  double? _lastZoom;
  int _searchGen = 0;

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
      if (mounted) {
        setState(() {
          _savedIds = {};
          _savedPlaces = const [];
        });
      }
      _map?.setSavedIds(const {});
      return;
    }
    final places = await widget.savedRepo.listMine(u.id);
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
      final last = _lastSearchBounds;
      final lastZ = _lastSearchZoom;
      if (last != null && lastZ != null) {
        final moved = GeoMath.distanceMeters(last.center, bounds.center);
        if (moved < 30 && (zoom - lastZ).abs() < 0.1) return; // 거의 안 움직이고 줌도 그대로 → 스킵
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
    } catch (_) {}
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
    if (_savedIds.contains(poi.id)) {
      await widget.savedRepo.deleteByPlaceId(ownerId: u.id, placeId: poi.id);
    } else {
      final memo = await showMemoSheet(context, placeName: poi.name);
      if (memo == null) return; // 시트 닫음 → 저장 취소
      await widget.savedRepo.save(
          ownerId: u.id, poi: poi, memo: memo.isEmpty ? null : memo);
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
