import 'lat_lng.dart';

/// 거리 스로틀을 통과한, 앱이 실제로 사용하는 위치 이벤트.
class LocationEvent {
  final LatLng position;
  final double headingDeg; // 진행 방향(0~360, 정북 0). 미상이면 -1.
  final double speedMps;   // m/s
  final DateTime timestamp;

  const LocationEvent({
    required this.position,
    required this.headingDeg,
    required this.speedMps,
    required this.timestamp,
  });

  bool get isMoving => speedMps >= 1.5; // 약 5.4km/h 이상이면 주행으로 간주
}
