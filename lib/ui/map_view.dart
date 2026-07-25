import 'package:flutter/widgets.dart';
import '../core/models/lat_lng.dart';
import '../core/models/lat_lng_bounds.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';

/// 지도 구현을 로직에서 분리하기 위한 컨트롤러 인터페이스.
abstract class MapController {
  /// 차(GPS) 위치 갱신. 따라가는 중이면 카메라가 이 위치로 이동.
  void setCar(LatLng car);

  /// 따라가기를 재개하고 차 위치로 카메라 복귀('내 위치' 버튼).
  void recenter();

  /// 따라가기 해제(카메라 그대로).
  void stopFollowing();

  void setPins(List<Recommendation> recs);
  void setSavedIds(Set<String> ids);
  void setFriendCounts(Map<String, int> byPlaceId);
}

/// 핀 탭 콜백 시그니처.
typedef PinTapCallback = void Function(Poi poi);

/// 지도 위젯을 만들어주는 빌더. 플랫폼별 구현(카카오/구글)을 MapScreen에서 분리한다.
typedef MapViewBuilder = Widget Function({
  required void Function(MapController) onReady,
  required PinTapCallback onPinTap,
  required void Function(LatLngBounds bounds, double zoom) onCameraIdle,
  required VoidCallback onMapTap,
  required void Function(bool following) onFollowChanged,
});
