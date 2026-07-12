import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/geo/geo_math.dart';

void main() {
  group('distanceMeters', () {
    test('같은 지점은 0m', () {
      final p = LatLng(37.5665, 126.9780);
      expect(GeoMath.distanceMeters(p, p), closeTo(0, 0.5));
    });

    test('서울시청~강남역 약 8~9km', () {
      final cityHall = LatLng(37.5663, 126.9779);
      final gangnam = LatLng(37.4979, 127.0276);
      final d = GeoMath.distanceMeters(cityHall, gangnam);
      expect(d, closeTo(8300, 800));
    });
  });

  group('bearingDeg', () {
    test('정북 방향은 0도 근처', () {
      final from = LatLng(37.50, 127.00);
      final north = LatLng(37.51, 127.00);
      expect(GeoMath.bearingDeg(from, north), closeTo(0, 1));
    });

    test('정동 방향은 90도 근처', () {
      final from = LatLng(37.50, 127.00);
      final east = LatLng(37.50, 127.01);
      expect(GeoMath.bearingDeg(from, east), closeTo(90, 1));
    });
  });

  group('angularDifferenceDeg', () {
    test('10도와 350도의 차이는 20도', () {
      expect(GeoMath.angularDifferenceDeg(10, 350), closeTo(20, 0.001));
    });
    test('0도와 180도의 차이는 180도', () {
      expect(GeoMath.angularDifferenceDeg(0, 180), closeTo(180, 0.001));
    });
  });
}
