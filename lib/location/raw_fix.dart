import '../core/models/lat_lng.dart';

/// 위치 소스가 내보내는 원시 픽스. heading은 기기가 제공 못하면 null.
class RawFix {
  final LatLng position;
  final double speedMps;
  final double? headingDeg;
  final DateTime timestamp;

  const RawFix({
    required this.position,
    required this.speedMps,
    required this.headingDeg,
    required this.timestamp,
  });
}
