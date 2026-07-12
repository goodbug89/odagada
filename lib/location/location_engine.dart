import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/geo/geo_math.dart';
import 'raw_fix.dart';

/// 원시 GPS 스트림을 거리 스로틀된 LocationEvent 스트림으로 변환하는 순수 로직.
/// 주입된 스트림만 다루므로 모의 트랙으로 단위 테스트 가능하다.
class LocationEngine {
  final double minMoveMeters;
  LocationEngine({this.minMoveMeters = 200});

  Stream<LocationEvent> process(Stream<RawFix> fixes) async* {
    LatLng? lastEmitted;
    await for (final f in fixes) {
      final isFirst = lastEmitted == null;
      final moved =
          isFirst ? double.infinity : GeoMath.distanceMeters(lastEmitted, f.position);
      if (isFirst || moved >= minMoveMeters) {
        yield LocationEvent(
          position: f.position,
          headingDeg: _resolveHeading(f, lastEmitted),
          speedMps: f.speedMps,
          timestamp: f.timestamp,
        );
        lastEmitted = f.position;
      }
    }
  }

  double _resolveHeading(RawFix f, LatLng? prev) {
    if (f.headingDeg != null && f.headingDeg! >= 0) return f.headingDeg!;
    if (prev == null) return -1;
    if (GeoMath.distanceMeters(prev, f.position) < 1) return -1;
    return GeoMath.bearingDeg(prev, f.position);
  }
}
