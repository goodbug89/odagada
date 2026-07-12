import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/recommend/recommend_engine.dart';

LocationEvent north() => LocationEvent(
      position: LatLng(37.5, 127.0),
      headingDeg: 0, // 북쪽 진행
      speedMps: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

Poi poi(String id, double lat, double lng, {double dist = 100, double rating = 0}) =>
    Poi(id: id, name: id, position: LatLng(lat, lng), category: 'c',
        distanceMeters: dist, rating: rating);

void main() {
  test('최대 거리 초과 후보는 제외', () {
    final e = RecommendEngine(maxDistanceMeters: 500);
    final far = poi('far', 37.51, 127.0, dist: 1200);
    final near = poi('near', 37.5009, 127.0, dist: 100);
    final out = e.rank(north(), [far, near]);
    expect(out.map((r) => r.poi.id), ['near']);
  });

  test('전방(북쪽) POI가 후방 POI보다 점수가 높다', () {
    final e = RecommendEngine();
    final ahead = poi('ahead', 37.502, 127.0, dist: 200); // 북쪽 = 전방
    final behind = poi('behind', 37.498, 127.0, dist: 200); // 남쪽 = 후방
    final out = e.rank(north(), [behind, ahead]);
    expect(out.first.poi.id, 'ahead');
  });

  test('이미 표시된 POI는 다음 랭킹에서 제외', () {
    final e = RecommendEngine();
    final a = poi('a', 37.502, 127.0, dist: 100);
    final b = poi('b', 37.5025, 127.0, dist: 150);
    final first = e.rank(north(), [a, b]);
    e.markShown(first.map((r) => r.poi.id));
    final second = e.rank(north(), [a, b]);
    expect(second, isEmpty);
  });

  test('maxResults 개수로 제한', () {
    final e = RecommendEngine(maxResults: 2);
    final pois = List.generate(
        5, (i) => poi('p$i', 37.5 + 0.001 * (i + 1), 127.0, dist: 100.0 * (i + 1)));
    final out = e.rank(north(), pois);
    expect(out.length, 2);
  });
}
