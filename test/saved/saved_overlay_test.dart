import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/saved/saved_place.dart';
import 'package:odagada/saved/saved_overlay.dart';

SavedPlace _s(String id, double lat, double lng, String cat) => SavedPlace(
    id: id, placeId: id, name: id, lat: lat, lng: lng, category: cat);

void main() {
  test('반경 안의 저장만 Poi로 변환(버킷·거리 포함)', () {
    final center = const LatLng(37.5, 127.0);
    final saved = [
      _s('near', 37.5008, 127.0, 'cafe'),   // ~89m
      _s('far', 37.6, 127.0, 'bar'),        // ~11km
    ];
    final pois = savedPoisInViewport(saved, center, 500);
    expect(pois.map((p) => p.id), ['near']);
    expect(pois.single.bucket, PlaceCategory.cafe);
    expect(pois.single.distanceMeters, greaterThan(0));
  });
}
