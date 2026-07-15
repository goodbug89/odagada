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
