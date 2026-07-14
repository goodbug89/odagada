import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import 'map_view.dart';

/// google_maps_flutter 기반 지도 위젯.
///
/// 네이티브 Marker 대신 **커스텀 핀 위젯을 지도 위에 오버레이**한다.
/// 이유: google_maps_flutter_web이 네이티브 마커를 렌더링하지 못하는 한계가 있어,
/// Web Mercator 투영으로 각 POI의 화면 좌표를 직접 계산해 Flutter 위젯으로 그린다.
/// 이 방식은 웹·모바일 전 플랫폼에서 동일하게 동작하고 브랜드 핀을 쓸 수 있다.
class GoogleMapView extends StatefulWidget {
  final void Function(MapController controller) onReady;
  final PinTapCallback onPinTap;
  const GoogleMapView({
    super.key,
    required this.onReady,
    required this.onPinTap,
  });

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> implements MapController {
  gmap.GoogleMapController? _controller;
  List<Recommendation> _recs = const [];

  static const _initialTarget = gmap.LatLng(37.5665, 126.9780);
  static const _initialZoom = 15.0;

  // 현재 카메라 상태(오버레이 핀 위치 계산용). onCameraMove로 갱신.
  gmap.LatLng _camTarget = _initialTarget;
  double _camZoom = _initialZoom;

  @override
  void moveCamera(LatLng center) {
    _controller?.animateCamera(
      gmap.CameraUpdate.newLatLng(gmap.LatLng(center.lat, center.lng)),
    );
  }

  @override
  void setPins(List<Recommendation> recs) {
    if (!mounted) return;
    setState(() => _recs = recs);
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
              onCameraMove: (pos) {
                setState(() {
                  _camTarget = pos.target;
                  _camZoom = pos.zoom;
                });
              },
              onMapCreated: (c) {
                _controller = c;
                widget.onReady(this);
              },
            ),
            ..._buildPins(size),
          ],
        );
      },
    );
  }

  List<Widget> _buildPins(Size size) {
    const pinSize = 40.0;
    final pins = <Widget>[];
    for (final r in _recs) {
      final s = _screenOf(r.poi.position, size);
      // 화면 밖 핀은 그리지 않음(여유 마진 포함).
      if (s.dx < -pinSize ||
          s.dy < -pinSize ||
          s.dx > size.width + pinSize ||
          s.dy > size.height + pinSize) {
        continue;
      }
      pins.add(Positioned(
        left: s.dx - pinSize / 2,
        top: s.dy - (pinSize + 6), // 핀 꼬리 끝점(=원+꼬리 높이)이 좌표에 오도록
        child: _Pin(
          poi: r.poi,
          size: pinSize,
          onTap: () => widget.onPinTap(r.poi),
        ),
      ));
    }
    return pins;
  }
}

/// 브랜드 주황 핀. 탭하면 콜백.
class _Pin extends StatelessWidget {
  final Poi poi;
  final double size;
  final VoidCallback onTap;
  const _Pin({required this.poi, required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5E13),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
          ),
          // 핀 꼬리(작은 삼각형 대용)
          Container(
            width: 3,
            height: 6,
            color: const Color(0xFFFF5E13),
          ),
        ],
      ),
    );
  }
}
