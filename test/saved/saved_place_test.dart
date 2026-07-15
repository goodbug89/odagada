import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/saved/saved_place.dart';

void main() {
  test('Supabase row를 SavedPlace로 매핑', () {
    final sp = savedPlaceFromRow({
      'id': 'row-1',
      'place_id': 'g-123',
      'name': '소문난 국밥',
      'lat': 37.5665,
      'lng': 126.9780,
      'category': '음식점',
      'memo': '점심 웨이팅 없음',
    });
    expect(sp.id, 'row-1');
    expect(sp.placeId, 'g-123');
    expect(sp.name, '소문난 국밥');
    expect(sp.lat, closeTo(37.5665, 1e-9));
    expect(sp.lng, closeTo(126.9780, 1e-9));
    expect(sp.category, '음식점');
    expect(sp.memo, '점심 웨이팅 없음');
  });

  test('lat/lng가 int로 와도 double로 매핑', () {
    final sp = savedPlaceFromRow({
      'id': 'r', 'place_id': null, 'name': 'X', 'lat': 37, 'lng': 127,
    });
    expect(sp.lat, 37.0);
    expect(sp.lng, 127.0);
    expect(sp.placeId, isNull);
    expect(sp.memo, isNull);
  });

  test('insert map은 owner_id/place_id/name/lat/lng/category/memo를 담는다', () {
    final m = savedPlaceInsert(
      ownerId: 'u-1', placeId: 'g-1', name: '집', lat: 1.0, lng: 2.0,
      category: '카페', memo: null,
    );
    expect(m['owner_id'], 'u-1');
    expect(m['place_id'], 'g-1');
    expect(m['name'], '집');
    expect(m['lat'], 1.0);
    expect(m['lng'], 2.0);
    expect(m['category'], '카페');
    expect(m.containsKey('memo'), isTrue);
  });

  test('category에 저장된 버킷 id를 PlaceCategory로 읽는다', () {
    final row = savedPlaceFromRow({
      'id': 's1', 'place_id': 'p1', 'name': 'x',
      'lat': 37.5, 'lng': 127.0, 'category': 'cafe', 'memo': null,
    });
    expect(row.bucket, PlaceCategory.cafe);
  });

  test('알 수 없는 category는 기타로 폴백', () {
    final row = savedPlaceFromRow({
      'id': 's2', 'place_id': 'p2', 'name': 'y',
      'lat': 37.5, 'lng': 127.0, 'category': '음식점', 'memo': null,
    });
    expect(row.bucket, PlaceCategory.other);
  });

  test('PlaceCategory.fromId', () {
    expect(PlaceCategory.fromId('bar'), PlaceCategory.bar);
    expect(PlaceCategory.fromId(null), PlaceCategory.other);
    expect(PlaceCategory.fromId('nope'), PlaceCategory.other);
  });
}
