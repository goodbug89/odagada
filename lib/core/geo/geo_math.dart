import 'dart:math' as math;
import '../models/lat_lng.dart';

class GeoMath {
  static const double _earthRadiusM = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double _deg(double rad) => rad * 180.0 / math.pi;

  /// 두 좌표 간 대권 거리(미터). 하버사인.
  static double distanceMeters(LatLng a, LatLng b) {
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final la1 = _rad(a.lat);
    final la2 = _rad(b.lat);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return 2 * _earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// from에서 to를 바라보는 방위각(0~360, 정북 0, 시계방향).
  static double bearingDeg(LatLng from, LatLng to) {
    final la1 = _rad(from.lat);
    final la2 = _rad(to.lat);
    final dLng = _rad(to.lng - from.lng);
    final y = math.sin(dLng) * math.cos(la2);
    final x = math.cos(la1) * math.sin(la2) -
        math.sin(la1) * math.cos(la2) * math.cos(dLng);
    final brng = _deg(math.atan2(y, x));
    return (brng + 360) % 360;
  }

  /// 두 방위각의 최소 각도차(0~180).
  static double angularDifferenceDeg(double a, double b) {
    var diff = (a - b).abs() % 360;
    if (diff > 180) diff = 360 - diff;
    return diff;
  }
}
