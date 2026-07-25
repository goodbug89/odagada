import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env에서 카카오 키를 읽어 앱 전역에 노출한다.
class AppConfig {
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get kakaoRestApiKey {
    final key = dotenv.env['KAKAO_REST_API_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('KAKAO_REST_API_KEY가 .env에 없습니다.');
    }
    return key;
  }

  static String get kakaoJsAppKey {
    final key = dotenv.env['KAKAO_JS_APP_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('KAKAO_JS_APP_KEY가 .env에 없습니다.');
    }
    return key;
  }

  static String get googleMapsApiKey {
    final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError('GOOGLE_MAPS_API_KEY가 .env에 없습니다.');
    }
    return key;
  }

  static String get supabaseUrl {
    final v = dotenv.env['SUPABASE_URL'];
    if (v == null || v.isEmpty) {
      throw StateError('SUPABASE_URL이 .env에 없습니다.');
    }
    return v;
  }

  static String get supabaseAnonKey {
    final v = dotenv.env['SUPABASE_ANON_KEY'];
    if (v == null || v.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY가 .env에 없습니다.');
    }
    return v;
  }
}
