import 'package:geolocator/geolocator.dart';
import '../core/models/lat_lng.dart';
import 'raw_fix.dart';

/// 플랫폼 GPS를 RawFix 스트림으로 변환하는 어댑터.
class LocationSource {
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Stream<RawFix> stream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10m마다 raw 픽스(엔진이 200m로 다시 스로틀)
      ),
    ).map((p) => RawFix(
          position: LatLng(p.latitude, p.longitude),
          speedMps: p.speed,
          headingDeg: p.heading >= 0 ? p.heading : null,
          timestamp: p.timestamp,
        ));
  }
}
