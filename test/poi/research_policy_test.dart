import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/lat_lng_bounds.dart';
import 'package:odagada/poi/research_policy.dart';

/// 중심이 [lat], [lng]인 작은 사각 영역(테스트용).
LatLngBounds _boundsAt(double lat, double lng) => LatLngBounds(
      ne: LatLng(lat + 0.001, lng + 0.001),
      sw: LatLng(lat - 0.001, lng - 0.001),
    );

void main() {
  test('이전 검색 없음 → true', () {
    expect(
        shouldResearch(
          lastBounds: null,
          lastZoom: null,
          bounds: _boundsAt(37.5665, 126.9780),
          zoom: 15,
        ),
        isTrue);
  });

  test('아주 조금 이동 + 줌 동일 → false(스킵)', () {
    final last = _boundsAt(37.5665, 126.9780);
    // 위도 0.00001도 ≈ 1.1m 이동 → 30m 미만
    final current = _boundsAt(37.56651, 126.9780);
    expect(
        shouldResearch(
          lastBounds: last,
          lastZoom: 15,
          bounds: current,
          zoom: 15,
        ),
        isFalse);
  });

  test('30m 이상 이동 → true', () {
    final last = _boundsAt(37.5665, 126.9780);
    // 위도 0.001도 ≈ 111m 이동 → 30m 이상
    final current = _boundsAt(37.5675, 126.9780);
    expect(
        shouldResearch(
          lastBounds: last,
          lastZoom: 15,
          bounds: current,
          zoom: 15,
        ),
        isTrue);
  });

  test('줌 변화 0.1 이상 → true', () {
    final last = _boundsAt(37.5665, 126.9780);
    final current = _boundsAt(37.5665, 126.9780);
    expect(
        shouldResearch(
          lastBounds: last,
          lastZoom: 15,
          bounds: current,
          zoom: 15.2,
        ),
        isTrue);
  });
}
