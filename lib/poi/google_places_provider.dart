import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/models/lat_lng.dart';
import '../core/models/location_event.dart';
import '../core/models/place_category.dart';
import '../core/models/poi.dart';
import '../core/geo/geo_math.dart';
import 'poi_provider.dart';

class GooglePlacesException implements Exception {
  final int statusCode;
  final String message;
  GooglePlacesException(this.statusCode, this.message);
  @override
  String toString() => 'GooglePlacesException($statusCode): $message';
}

/// Google Places API (New)의 Nearby Search로 주변 음식점을 조회하는 Provider.
/// 브라우저(웹)에서도 CORS 없이 호출 가능. http.Client를 주입받아 테스트 가능.
class GooglePlacesProvider implements PoiProvider {
  final http.Client client;
  final String apiKey;
  GooglePlacesProvider({required this.client, required this.apiKey});

  static const _endpoint =
      'https://places.googleapis.com/v1/places:searchNearby';

  @override
  String get id => 'restaurant';
  @override
  String get displayName => '맛집';

  @override
  Future<List<Poi>> nearby(LocationEvent loc,
      {required double radiusMeters}) async {
    final res = await client.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.primaryType,places.primaryTypeDisplayName,places.formattedAddress,places.nationalPhoneNumber,places.regularOpeningHours',
      },
      body: jsonEncode({
        'includedTypes': const [
          'restaurant', 'cafe', 'bar', 'bakery',
          'tourist_attraction', 'park', 'museum',
          'shopping_mall', 'department_store',
          'movie_theater', 'amusement_park',
        ],
        'maxResultCount': 20,
        'locationRestriction': {
          'circle': {
            'center': {
              'latitude': loc.position.lat,
              'longitude': loc.position.lng,
            },
            'radius': radiusMeters.clamp(1.0, 50000.0),
          }
        },
        'languageCode': 'ko',
        'rankPreference': 'DISTANCE',
      }),
    );
    if (res.statusCode != 200) {
      throw GooglePlacesException(res.statusCode, res.body);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final places = (body['places'] as List?) ?? const [];
    return places
        .map((p) => _toPoi(loc.position, p as Map<String, dynamic>))
        .toList();
  }

  static const _textEndpoint =
      'https://places.googleapis.com/v1/places:searchText';

  Future<List<Poi>> searchText(String query, {LatLng? bias}) async {
    final res = await client.post(
      Uri.parse(_textEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.location,places.primaryType,places.primaryTypeDisplayName,places.formattedAddress,places.nationalPhoneNumber,places.regularOpeningHours',
      },
      body: jsonEncode({
        'textQuery': query,
        if (bias != null)
          'locationBias': {
            'circle': {
              'center': {'latitude': bias.lat, 'longitude': bias.lng},
              'radius': 20000.0,
            }
          },
        'maxResultCount': 15,
        'languageCode': 'ko',
      }),
    );
    if (res.statusCode != 200) {
      throw GooglePlacesException(res.statusCode, res.body);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final places = (body['places'] as List?) ?? const [];
    return places.map((p) => _toPoi(bias, p as Map<String, dynamic>)).toList();
  }

  Poi _toPoi(LatLng? ref, Map<String, dynamic> p) {
    final l = p['location'] as Map<String, dynamic>;
    final pos = LatLng(
      (l['latitude'] as num).toDouble(),
      (l['longitude'] as num).toDouble(),
    );
    return Poi(
      id: (p['id'] as String?) ?? '${pos.lat},${pos.lng}',
      name: (p['displayName']?['text'] as String?) ?? '이름 없음',
      position: pos,
      category: (p['primaryTypeDisplayName']?['text'] as String?) ?? '음식점',
      bucket: PlaceCategory.fromGooglePrimaryType(p['primaryType'] as String?),
      address: p['formattedAddress'] as String?,
      phone: p['nationalPhoneNumber'] as String?,
      openNow: (p['regularOpeningHours'] as Map<String, dynamic>?)?['openNow']
          as bool?,
      weekdayHours: ((p['regularOpeningHours'] as Map<String, dynamic>?)?
              ['weekdayDescriptions'] as List?)
          ?.cast<String>(),
      distanceMeters: ref == null ? 0 : GeoMath.distanceMeters(ref, pos),
    );
  }
}
