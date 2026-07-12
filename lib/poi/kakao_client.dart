import 'dart:convert';
import 'package:http/http.dart' as http;

class KakaoApiException implements Exception {
  final int statusCode;
  final String message;
  KakaoApiException(this.statusCode, this.message);
  @override
  String toString() => 'KakaoApiException($statusCode): $message';
}

/// 카카오 로컬 REST API 래퍼. http.Client를 주입받아 테스트에서 목킹 가능.
class KakaoClient {
  final http.Client client;
  final String restApiKey;
  static const _base = 'https://dapi.kakao.com/v2/local/search/category.json';

  KakaoClient({required this.client, required this.restApiKey});

  /// 카테고리+좌표+반경 검색. documents 리스트(raw map)를 반환.
  Future<List<Map<String, dynamic>>> searchCategory({
    required String categoryCode,
    required double lat,
    required double lng,
    required int radiusMeters,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'category_group_code': categoryCode,
      'x': lng.toString(), // 카카오는 x=경도, y=위도
      'y': lat.toString(),
      'radius': radiusMeters.toString(), // 0~20000
      'sort': 'distance',
      'size': '15',
    });
    final res = await client.get(uri, headers: {
      'Authorization': 'KakaoAK $restApiKey',
    });
    if (res.statusCode != 200) {
      throw KakaoApiException(res.statusCode, utf8.decode(res.bodyBytes));
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final docs = (body['documents'] as List).cast<Map<String, dynamic>>();
    return docs;
  }
}
