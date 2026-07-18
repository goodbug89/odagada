import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/friends/friend_save.dart';

void main() {
  test('friendSaveFromRow 매핑(category→bucket, 배열)', () {
    final fs = friendSaveFromRow({
      'place_id': 'p1', 'lat': 37.5, 'lng': 127.0, 'name': '금양화로',
      'category': 'restaurant', 'friend_count': 2,
      'friend_names': ['철수', '영희'], 'memos': ['맛있어', ''],
    });
    expect(fs.placeId, 'p1');
    expect(fs.bucket, PlaceCategory.restaurant);
    expect(fs.friendCount, 2);
    expect(fs.friendNames, ['철수', '영희']);
    expect(fs.memos, ['맛있어', '']);
  });

  test('friendOverlay: 카운트 전부, extraPins는 기존에 없는 것만, 거리는 center 기준', () {
    final saves = [
      FriendSave(placeId: 'a', lat: 37.5, lng: 127.0, name: 'A',
          bucket: PlaceCategory.cafe, friendCount: 1, friendNames: ['철수'], memos: ['']),
      FriendSave(placeId: 'b', lat: 37.6, lng: 127.1, name: 'B',
          bucket: PlaceCategory.bar, friendCount: 3, friendNames: [], memos: []),
    ];
    final r = friendOverlay(saves, {'a'}, const LatLng(37.5, 127.0));
    expect(r.friendCounts, {'a': 1, 'b': 3});
    expect(r.extraPins.map((p) => p.id).toList(), ['b']); // b만 추가
    expect(r.extraPins.single.distanceMeters, greaterThan(0)); // center(37.5)↔b(37.6) ~11km
  });
}
