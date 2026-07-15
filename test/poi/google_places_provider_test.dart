import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:odagada/core/models/lat_lng.dart';
import 'package:odagada/core/models/location_event.dart';
import 'package:odagada/core/models/place_category.dart';
import 'package:odagada/poi/google_places_provider.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

LocationEvent loc() => LocationEvent(
      position: LatLng(37.5665, 126.9780),
      headingDeg: 0,
      speedMps: 10,
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    );

const _sampleBody = '''
{
  "places": [
    {
      "id": "place-1",
      "displayName": {"text": "카츠삼삼", "languageCode": "ko"},
      "location": {"latitude": 37.5670, "longitude": 126.9788},
      "primaryTypeDisplayName": {"text": "돈가스 전문점"},
      "formattedAddress": "서울 중구 어딘가 12"
    }
  ]
}
''';

void main() {
  setUpAll(() => registerFallbackValue(FakeUri()));

  test('Places API (New) 응답을 Poi 리스트로 매핑한다', () async {
    final mock = MockHttpClient();
    when(() => mock.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response.bytes(utf8.encode(_sampleBody), 200));

    final provider = GooglePlacesProvider(client: mock, apiKey: 'TEST');
    final pois = await provider.nearby(loc(), radiusMeters: 1000);

    expect(pois.length, 1);
    expect(pois.first.name, '카츠삼삼');
    expect(pois.first.category, '돈가스 전문점');
    expect(pois.first.position.lat, closeTo(37.5670, 0.0001));
    expect(pois.first.distanceMeters, greaterThan(0));
    expect(provider.id, 'restaurant');
  });

  test('요청에 API 키 헤더와 restaurant 타입이 들어간다', () async {
    final mock = MockHttpClient();
    when(() => mock.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response.bytes(utf8.encode(_sampleBody), 200));

    final provider = GooglePlacesProvider(client: mock, apiKey: 'TESTKEY');
    await provider.nearby(loc(), radiusMeters: 500);

    final captured = verify(() => mock.post(
          captureAny(),
          headers: captureAny(named: 'headers'),
          body: captureAny(named: 'body'),
        )).captured;
    final uri = captured[0] as Uri;
    final headers = captured[1] as Map<String, String>;
    final body = captured[2] as String;
    expect(uri.toString(), contains('places:searchNearby'));
    expect(headers['X-Goog-Api-Key'], 'TESTKEY');
    expect(body, contains('restaurant'));
  });

  test('HTTP 200이 아니면 예외', () async {
    final mock = MockHttpClient();
    when(() => mock.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response.bytes(utf8.encode('nope'), 403));

    final provider = GooglePlacesProvider(client: mock, apiKey: 'TEST');
    expect(() => provider.nearby(loc(), radiusMeters: 500),
        throwsA(isA<GooglePlacesException>()));
  });

  test('primaryType으로 bucket을 채운다', () async {
    final mock = MockHttpClient();
    when(() => mock.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'places': [
                  {
                    'id': 'p1',
                    'displayName': {'text': '스타벅스'},
                    'location': {'latitude': 37.5, 'longitude': 127.0},
                    'primaryType': 'coffee_shop',
                    'primaryTypeDisplayName': {'text': '카페'},
                  },
                ],
              })),
              200,
            ));

    final provider = GooglePlacesProvider(client: mock, apiKey: 'TEST');
    final pois = await provider.nearby(loc(), radiusMeters: 500);

    expect(pois.single.bucket, PlaceCategory.cafe);
  });

  test('전화·영업시간을 파싱한다', () async {
    final mock = MockHttpClient();
    when(() => mock.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'places': [
                  {
                    'id': 'p1',
                    'displayName': {'text': '카페A'},
                    'location': {'latitude': 37.5, 'longitude': 127.0},
                    'primaryType': 'cafe',
                    'nationalPhoneNumber': '02-123-4567',
                    'regularOpeningHours': {
                      'openNow': true,
                      'weekdayDescriptions': [
                        '월요일: 09:00~18:00',
                        '화요일: 09:00~18:00',
                      ],
                    },
                  },
                ],
              })),
              200,
            ));

    final provider = GooglePlacesProvider(client: mock, apiKey: 'TEST');
    final pois = await provider.nearby(loc(), radiusMeters: 500);

    expect(pois.single.phone, '02-123-4567');
    expect(pois.single.openNow, true);
    expect(pois.single.weekdayHours, hasLength(2));
  });
}
