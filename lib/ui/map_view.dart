import 'package:flutter/widgets.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';

/// 지도 구현을 로직에서 분리하기 위한 컨트롤러 인터페이스.
abstract class MapController {
  void moveCamera(LatLng center);
  void setPins(List<Recommendation> recs);
  void setSavedIds(Set<String> ids);
}

/// 핀 탭 콜백 시그니처.
typedef PinTapCallback = void Function(Poi poi);

/// 지도 위젯을 만들어주는 빌더. 플랫폼별 구현(카카오/구글)을 MapScreen에서 분리한다.
typedef MapViewBuilder = Widget Function({
  required void Function(MapController) onReady,
  required PinTapCallback onPinTap,
});
