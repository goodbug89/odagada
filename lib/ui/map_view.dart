import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';

/// 지도 구현을 로직에서 분리하기 위한 컨트롤러 인터페이스.
abstract class MapController {
  void moveCamera(LatLng center);
  void setPins(List<Recommendation> recs);
}

/// 핀 탭 콜백 시그니처.
typedef PinTapCallback = void Function(Poi poi);
