import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'web/maps_loader.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  if (kIsWeb) {
    // 웹에서는 Google Maps JS를 키와 함께 런타임 로드한 뒤 앱을 띄운다.
    await loadGoogleMapsJs(AppConfig.googleMapsApiKey);
  }
  runApp(const OdagadaApp());
}
