import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import '../core/models/lat_lng.dart';
import '../core/models/recommendation.dart';
import 'map_view.dart';

/// google_maps_flutter 기반 지도 위젯. 기존 MapView 인터페이스를 구현해
/// 카카오맵과 교체 가능하다. (웹/모바일 공용)
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
  Set<gmap.Marker> _markers = {};

  static const _initial = gmap.CameraPosition(
    target: gmap.LatLng(37.5665, 126.9780),
    zoom: 15,
  );

  @override
  void moveCamera(LatLng center) {
    _controller?.animateCamera(
      gmap.CameraUpdate.newLatLng(gmap.LatLng(center.lat, center.lng)),
    );
  }

  @override
  void setPins(List<Recommendation> recs) {
    if (!mounted) return;
    setState(() {
      _markers = recs
          .map((r) => gmap.Marker(
                markerId: gmap.MarkerId(r.poi.id),
                position:
                    gmap.LatLng(r.poi.position.lat, r.poi.position.lng),
                infoWindow: gmap.InfoWindow(title: r.poi.name),
                onTap: () => widget.onPinTap(r.poi),
              ))
          .toSet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return gmap.GoogleMap(
      initialCameraPosition: _initial,
      markers: _markers,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      onMapCreated: (c) {
        _controller = c;
        widget.onReady(this);
      },
    );
  }
}
