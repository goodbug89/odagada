import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'web/maps_loader.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    // supabase_flutter 2.16+에서 anonKey→publishableKey로 명칭 변경.
    // anon(JWT)·publishable 키 모두 이 파라미터로 동작한다.
    publishableKey: AppConfig.supabaseAnonKey,
  );
  if (kIsWeb) {
    await loadGoogleMapsJs(AppConfig.googleMapsApiKey);
  }
  runApp(const OdagadaApp());
}
