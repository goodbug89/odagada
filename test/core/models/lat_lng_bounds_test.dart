// test/core/models/lat_lng_bounds_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/lat_lng_bounds.dart';

void main() {
  test('center는 ne/sw의 중점', () {
    const b = LatLngBounds(ne: LatLng(37.6, 127.1), sw: LatLng(37.4, 126.9));
    expect(b.center.lat, closeTo(37.5, 1e-9));
    expect(b.center.lng, closeTo(127.0, 1e-9));
  });
}
