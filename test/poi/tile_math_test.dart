import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/lat_lng_bounds.dart';
import 'package:odagada/poi/tile_math.dart';

void main() {
  const z = 14;

  test('tileKeyOf가 만든 타일의 bounds가 그 좌표를 포함', () {
    final k = tileKeyOf(37.5665, 126.9780, z);
    final b = tileBounds(k);
    expect(37.5665, inInclusiveRange(b.sw.lat, b.ne.lat));
    expect(126.9780, inInclusiveRange(b.sw.lng, b.ne.lng));
    expect(b.ne.lat, greaterThan(b.sw.lat));
    expect(b.ne.lng, greaterThan(b.sw.lng));
  });

  test('tileCenter는 bounds 안, radius는 양수', () {
    final k = tileKeyOf(37.5, 127.0, z);
    final b = tileBounds(k);
    final c = tileCenter(k);
    expect(c.lat, inInclusiveRange(b.sw.lat, b.ne.lat));
    expect(c.lng, inInclusiveRange(b.sw.lng, b.ne.lng));
    expect(tileRadiusMeters(k), greaterThan(0));
  });

  test('TileKey 값 동등성', () {
    expect(const TileKey(14, 1, 2), const TileKey(14, 1, 2));
    expect(const TileKey(14, 1, 2) == const TileKey(14, 1, 3), isFalse);
  });

  test('타일 내부로 좁힌 bounds는 정확히 1개 타일을 덮는다', () {
    final k = tileKeyOf(37.5, 127.0, z);
    final b = tileBounds(k);
    final dLat = b.ne.lat - b.sw.lat, dLng = b.ne.lng - b.sw.lng;
    final inset = LatLngBounds(
      ne: LatLng(b.ne.lat - dLat * 0.25, b.ne.lng - dLng * 0.25),
      sw: LatLng(b.sw.lat + dLat * 0.25, b.sw.lng + dLng * 0.25),
    );
    final covering = tilesCovering(inset, z);
    expect(covering, [k]);
  });

  test('인접 타일 두 중심을 잇는 bounds는 2x2 블록(4타일)을 덮는다', () {
    final k = tileKeyOf(37.5, 127.0, z);
    final k2 = TileKey(z, k.x + 1, k.y + 1);
    final c1 = tileCenter(k), c2 = tileCenter(k2);
    final span = LatLngBounds(
      ne: LatLng(c1.lat > c2.lat ? c1.lat : c2.lat,
          c1.lng > c2.lng ? c1.lng : c2.lng),
      sw: LatLng(c1.lat < c2.lat ? c1.lat : c2.lat,
          c1.lng < c2.lng ? c1.lng : c2.lng),
    );
    final covering = tilesCovering(span, z).toSet();
    expect(covering.length, 4);
    expect(covering.contains(k), isTrue);
    expect(covering.contains(k2), isTrue);
  });
}
