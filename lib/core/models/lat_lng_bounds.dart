import 'lat_lng.dart';

/// 지도에 보이는 사각 영역(북동·남서 코너). google_maps_flutter의 LatLngBounds와
/// 분리된 앱 내부 값 객체(로직·타일 계산용).
class LatLngBounds {
  final LatLng ne;
  final LatLng sw;
  const LatLngBounds({required this.ne, required this.sw});

  LatLng get center =>
      LatLng((ne.lat + sw.lat) / 2, (ne.lng + sw.lng) / 2);
}
