import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/poi/kakao_client.dart';
import 'package:odagada/poi/restaurant_provider.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

LocationEvent loc() => LocationEvent(
      position: LatLng(37.5, 127.0),
      headingDeg: 0,
      speedMps: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

const _sampleBody = '''
{
  "documents": [
    {
      "id": "111",
      "place_name": "맛있는 국밥",
      "category_name": "음식점 > 한식 > 국밥",
      "x": "127.001",
      "y": "37.501",
      "distance": "150",
      "road_address_name": "서울 어딘가 12",
      "phone": "02-123-4567",
      "place_url": "http://place.map.kakao.com/111"
    }
  ],
  "meta": {"total_count": 1, "is_end": true}
}
''';

void main() {
  setUpAll(() => registerFallbackValue(FakeUri()));

  test('카카오 응답을 Poi 리스트로 매핑한다', () async {
    final mock = MockHttpClient();
    when(() => mock.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response.bytes(utf8.encode(_sampleBody), 200));

    final provider = RestaurantProvider(
      client: KakaoClient(client: mock, restApiKey: 'TEST'),
    );

    final pois = await provider.nearby(loc(), radiusMeters: 1000);

    expect(pois.length, 1);
    expect(pois.first.name, '맛있는 국밥');
    expect(pois.first.category, '음식점 > 한식 > 국밥');
    expect(pois.first.position.lat, closeTo(37.501, 0.0001));
    expect(pois.first.distanceMeters, closeTo(150, 0.1));
    expect(provider.id, 'restaurant');
  });

  test('요청에 FD6 카테고리와 KakaoAK 헤더가 들어간다', () async {
    final mock = MockHttpClient();
    when(() => mock.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response.bytes(utf8.encode(_sampleBody), 200));

    final provider = RestaurantProvider(
      client: KakaoClient(client: mock, restApiKey: 'TEST'),
    );
    await provider.nearby(loc(), radiusMeters: 500);

    final captured = verify(() => mock.get(
          captureAny(),
          headers: captureAny(named: 'headers'),
        )).captured;
    final uri = captured[0] as Uri;
    final headers = captured[1] as Map<String, String>;
    expect(uri.queryParameters['category_group_code'], 'FD6');
    expect(uri.queryParameters['radius'], '500');
    expect(headers['Authorization'], 'KakaoAK TEST');
  });

  test('HTTP 200이 아니면 예외', () async {
    final mock = MockHttpClient();
    when(() => mock.get(any(), headers: any(named: 'headers')))
        .thenAnswer((_) async => http.Response('nope', 429));
    final provider = RestaurantProvider(
      client: KakaoClient(client: mock, restApiKey: 'TEST'),
    );
    expect(() => provider.nearby(loc(), radiusMeters: 500), throwsA(isA<KakaoApiException>()));
  });
}
