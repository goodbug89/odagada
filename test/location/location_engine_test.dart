import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/location/raw_fix.dart';
import 'package:odagada/location/location_engine.dart';

RawFix fix(double lat, double lng, {double speed = 10, double? heading}) =>
    RawFix(
      position: LatLng(lat, lng),
      speedMps: speed,
      headingDeg: heading,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

void main() {
  test('첫 픽스는 즉시 방출된다', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    final out = await engine.process(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out.length, 1);
    expect(out.first.position, LatLng(37.5, 127.0));
  });

  test('200m 미만 이동은 방출하지 않는다', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    // 약 11m 떨어진 두 점
    final out = await engine
        .process(Stream.fromIterable([fix(37.5, 127.0), fix(37.5001, 127.0)]))
        .toList();
    expect(out.length, 1); // 첫 점만
  });

  test('200m 이상 이동하면 다시 방출한다', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    // 약 330m 떨어진 두 점(위도 0.003도 ≈ 333m)
    final out = await engine
        .process(Stream.fromIterable([fix(37.5, 127.0), fix(37.503, 127.0)]))
        .toList();
    expect(out.length, 2);
  });

  test('heading이 없으면 이동 방향으로 보정된다(정북≈0)', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    final out = await engine
        .process(Stream.fromIterable([
          fix(37.5, 127.0, heading: null),
          fix(37.503, 127.0, heading: null), // 북쪽으로 이동
        ]))
        .toList();
    expect(out.last.headingDeg, closeTo(0, 2));
  });

  test('음수 heading도 이동 방향으로 보정된다(정북≈0)', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    final out = await engine
        .process(Stream.fromIterable([
          fix(37.5, 127.0, heading: -5),
          fix(37.503, 127.0, heading: -5), // 북쪽으로 이동, 센서 heading은 음수(-5)
        ]))
        .toList();
    // 음수 heading은 무시하고 bearing(≈0)으로 보정
    expect(out.last.headingDeg, closeTo(0, 2));
  });

  test('정확히 200m 경계 이동은 방출한다(>= 경계 포함)', () async {
    final engine = LocationEngine(minMoveMeters: 200);
    // 위도 델타 0.0018 ≈ 200.15m (200m 바로 위, >= 경계를 실제로 검증)
    final out = await engine
        .process(Stream.fromIterable([fix(37.5, 127.0), fix(37.5018, 127.0)]))
        .toList();
    expect(out.length, 2);
  });
}
