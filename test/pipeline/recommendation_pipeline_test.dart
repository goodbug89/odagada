import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/poi.dart';
import 'package:odagada/location/location_engine.dart';
import 'package:odagada/location/raw_fix.dart';
import 'package:odagada/poi/poi_provider.dart';
import 'package:odagada/recommend/recommend_engine.dart';
import 'package:odagada/pipeline/recommendation_pipeline.dart';

class FakeProvider implements PoiProvider {
  final List<Poi> Function() supplier;
  FakeProvider(this.supplier);
  @override
  String get id => 'fake';
  @override
  String get displayName => 'fake';
  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async =>
      supplier();
}

class ThrowingProvider implements PoiProvider {
  @override
  String get id => 'boom';
  @override
  String get displayName => 'boom';
  @override
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters}) async =>
      throw Exception('network down');
}

RawFix fix(double lat, double lng) => RawFix(
      position: LatLng(lat, lng),
      speedMps: 10,
      headingDeg: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

Poi poi(String id, double lat) =>
    Poi(id: id, name: id, position: LatLng(lat, 127.0), category: 'c', distanceMeters: 100);

void main() {
  test('LocationEvent마다 추천 리스트를 방출한다', () async {
    final registry = ProviderRegistry()
      ..register(FakeProvider(() => [poi('a', 37.502)]));
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    final out = await pipeline.run(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out.length, 1);
    expect(out.first.recommendations.map((r) => r.poi.id), ['a']);
  });

  test('Provider 예외는 삼키고 빈 방출을 하지 않는다', () async {
    final registry = ProviderRegistry()..register(ThrowingProvider());
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    final out = await pipeline.run(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out, isEmpty); // 방출 없음(직전 결과 유지)
  });

  test('같은 POI가 다음 위치 업데이트에도 계속 포함된다(핀이 사라지지 않는다)', () async {
    final registry = ProviderRegistry()
      ..register(FakeProvider(() => [poi('a', 37.502)]));
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    // 두 위치 모두 같은 POI 'a'를 반환 → 전체 핀 필드이므로 두 번째에도 계속 포함되어야 한다.
    final out = await pipeline
        .run(Stream.fromIterable([fix(37.5, 127.0), fix(37.503, 127.0)]))
        .toList();
    expect(out.length, 2);
    expect(out[0].recommendations.map((r) => r.poi.id), ['a']);
    expect(out[1].recommendations.map((r) => r.poi.id), ['a']);
  });

  test('성공했으나 후보가 비면 빈 recommendations로 emit된다(카메라 추적 유지)', () async {
    final registry = ProviderRegistry()..register(FakeProvider(() => []));
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    final out = await pipeline.run(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out.length, 1);
    expect(out.first.recommendations, isEmpty);
    expect(out.first.location.position, LatLng(37.5, 127.0));
  });

  test('emit된 RecommendationUpdate.location이 입력 위치와 일치한다', () async {
    final registry = ProviderRegistry()
      ..register(FakeProvider(() => [poi('a', 37.502)]));
    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );
    final out = await pipeline.run(Stream.fromIterable([fix(37.5, 127.0)])).toList();
    expect(out.first.location.position, LatLng(37.5, 127.0));
  });
}
