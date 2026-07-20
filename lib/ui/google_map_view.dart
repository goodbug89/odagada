import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../core/models/lat_lng.dart';
import '../core/models/lat_lng_bounds.dart';
import '../core/models/recommendation.dart';
import 'map_view.dart';
import 'place_pin.dart';

/// google_maps_flutter 기반 지도 위젯.
///
/// 네이티브 Marker 대신 **커스텀 핀 위젯을 지도 위에 오버레이**한다.
/// 이유: google_maps_flutter_web이 네이티브 마커를 렌더링하지 못하는 한계가 있어,
/// Web Mercator 투영으로 각 POI의 화면 좌표를 직접 계산해 Flutter 위젯으로 그린다.
/// 이 방식은 웹·모바일 전 플랫폼에서 동일하게 동작하고 브랜드 핀을 쓸 수 있다.
class GoogleMapView extends StatefulWidget {
  final void Function(MapController controller) onReady;
  final PinTapCallback onPinTap;
  final void Function(LatLngBounds bounds, double zoom) onCameraIdle;
  final VoidCallback onMapTap;
  final void Function(bool following) onFollowChanged;
  const GoogleMapView({
    super.key,
    required this.onReady,
    required this.onPinTap,
    required this.onCameraIdle,
    required this.onMapTap,
    required this.onFollowChanged,
  });

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> implements MapController {
  gmap.GoogleMapController? _controller;
  List<Recommendation> _recs = const [];
  Set<String> _savedIds = const {};
  Map<String, int> _friendCounts = const {};

  static const _initialTarget = gmap.LatLng(37.5665, 126.9780);
  static const _initialZoom = 15.0;

  // 구글 기본의 "파란 숫자 마커"(우리 친구배지와 혼동)를 모두 제거해 우리 핀만 보이게.
  // - poi 전체 off: 구글 상호 아이콘·라벨 제거
  // - transit 전체 off: 정류장 마커·라벨·노선 지오메트리 제거
  // - road labels.icon off: 도로 노선번호 shield("48"·"6" 등) 제거(도로 이름·지오메트리는 유지)
  static const _mapStyle =
      '[{"featureType":"poi","stylers":[{"visibility":"off"}]},'
      '{"featureType":"transit","stylers":[{"visibility":"off"}]},'
      '{"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]}]';

  // 현재 카메라 상태(오버레이 핀 위치 계산용). onCameraMove로 갱신.
  gmap.LatLng _camTarget = _initialTarget;
  double _camZoom = _initialZoom;

  gmap.LatLng? _car; // 최근 차 위치
  bool _following = true; // 차 따라가기 여부
  bool _programmaticMove = false; // 우리가 animateCamera로 움직이는 중(제스처와 구분)

  @override
  void setCar(LatLng car) {
    _car = gmap.LatLng(car.lat, car.lng);
    if (_following) _animateTo(_car!);
  }

  @override
  void recenter() {
    _setFollowing(true);
    if (_car != null) _animateTo(_car!);
  }

  @override
  void stopFollowing() => _setFollowing(false);

  void _setFollowing(bool v) {
    if (_following == v) return;
    _following = v;
    widget.onFollowChanged(v);
  }

  void _animateTo(gmap.LatLng pos) {
    _programmaticMove = true; // 이어지는 onCameraMoveStarted는 우리 이동
    _controller?.animateCamera(gmap.CameraUpdate.newLatLng(pos));
  }

  Future<void> _handleCameraIdle() async {
    _programmaticMove = false; // 이동 종료
    final c = _controller;
    if (c == null) return;
    final region = await c.getVisibleRegion();
    final ne = region.northeast;
    final sw = region.southwest;
    if (ne.latitude == sw.latitude && ne.longitude == sw.longitude) return; // 레이아웃 전 퇴화 영역 방어
    final bounds = LatLngBounds(
      ne: LatLng(ne.latitude, ne.longitude),
      sw: LatLng(sw.latitude, sw.longitude),
    );
    widget.onCameraIdle(bounds, _camZoom);
  }

  @override
  void setPins(List<Recommendation> recs) {
    if (!mounted) return;
    setState(() => _recs = recs);
  }

  @override
  void setSavedIds(Set<String> ids) {
    if (!mounted) return;
    setState(() => _savedIds = ids);
  }

  @override
  void setFriendCounts(Map<String, int> byPlaceId) {
    if (!mounted) return;
    setState(() => _friendCounts = byPlaceId);
  }

  /// 위도·경도를 해당 줌의 월드 픽셀 좌표로 투영(Web Mercator).
  Offset _project(double lat, double lng, double zoom) {
    final worldSize = 256.0 * math.pow(2.0, zoom);
    final x = (lng + 180.0) / 360.0 * worldSize;
    final sinLat = math.sin(lat * math.pi / 180.0).clamp(-0.9999, 0.9999);
    final y =
        (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) *
            worldSize;
    return Offset(x, y);
  }

  /// POI의 지도 위 화면 좌표(핀 끝점 기준). 맵 크기 [size] 필요.
  Offset _screenOf(LatLng pos, Size size) {
    final center = _project(_camTarget.latitude, _camTarget.longitude, _camZoom);
    final p = _project(pos.lat, pos.lng, _camZoom);
    return Offset(
      size.width / 2 + (p.dx - center.dx),
      size.height / 2 + (p.dy - center.dy),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            gmap.GoogleMap(
              initialCameraPosition: const gmap.CameraPosition(
                target: _initialTarget,
                zoom: _initialZoom,
              ),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              style: _mapStyle,
              onTap: (_) => widget.onMapTap(),
              onCameraMoveStarted: () {
                if (_programmaticMove) {
                  _programmaticMove = false; // 우리 이동으로 소비
                } else {
                  _setFollowing(false); // 사용자가 손댐 → 따라가기 해제
                }
              },
              onCameraMove: (pos) {
                setState(() {
                  _camTarget = pos.target;
                  _camZoom = pos.zoom;
                });
              },
              onCameraIdle: _handleCameraIdle,
              onMapCreated: (c) {
                _controller = c;
                widget.onReady(this);
                _handleCameraIdle(); // 최초 뷰포트로 즉시 1회 검색(카메라 이동 없어도)
              },
            ),
            ..._buildPins(size),
          ],
        );
      },
    );
  }

  List<Widget> _buildPins(Size size) {
    const margin = 160.0; // 이름 라벨 폭까지 감안한 컬링 여유
    final pins = <Widget>[];
    for (final r in _recs) {
      final s = _screenOf(r.poi.position, size);
      if (s.dx < -margin ||
          s.dy < -margin ||
          s.dx > size.width + margin ||
          s.dy > size.height + margin) {
        continue;
      }
      final saved = _savedIds.contains(r.poi.id);
      final fc = _friendCounts[r.poi.id] ?? 0;
      if (saved || fc > 0) {
        pins.add(Positioned(
          left: s.dx - 22, // 머리 폭 44의 절반
          top: s.dy - 46,  // 꼬리 끝이 기준점
          child: PlacePin(
            poi: r.poi,
            saved: saved,
            friendCount: fc,
            onTap: () => widget.onPinTap(r.poi),
          ),
        ));
      } else {
        pins.add(Positioned(
          left: s.dx - 15, // 원 지름 30의 절반(원 중심 = 기준점)
          top: s.dy - 15,
          child: CategoryDot(poi: r.poi, onTap: () => widget.onPinTap(r.poi)),
        ));
      }
    }
    return pins;
  }
}
