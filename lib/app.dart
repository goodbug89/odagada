import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'location/location_source.dart';
import 'location/location_engine.dart';
import 'pipeline/recommendation_pipeline.dart';
import 'poi/poi_provider.dart';
import 'poi/google_places_provider.dart';
import 'recommend/recommend_engine.dart';
import 'config/app_config.dart';
import 'ui/map_screen.dart';
import 'ui/map_view.dart';
import 'ui/google_map_view.dart';
import 'ui/navigation_launcher.dart';

class OdagadaApp extends StatelessWidget {
  const OdagadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 전 플랫폼 구글맵 + Google Places(글로벌 커버리지).
    // 카카오(국내 전용)는 심사 승인 후 국내 옵션으로 되살릴 수 있게 파일만 남겨둠.
    final registry = ProviderRegistry()
      ..register(GooglePlacesProvider(
        client: http.Client(),
        apiKey: AppConfig.googleMapsApiKey,
      ));

    // 모바일은 실제 GPS, 웹은 권한 흐름 없이 고정 위치(데모).
    final LocationSource locationSource =
        kIsWeb ? const FixedLocationSource() : GeolocatorLocationSource();

    Widget mapBuilder({
      required void Function(MapController) onReady,
      required PinTapCallback onPinTap,
    }) =>
        GoogleMapView(onReady: onReady, onPinTap: onPinTap);

    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );

    return MaterialApp(
      title: '오다가다',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: MapScreen(
        locationSource: locationSource,
        pipeline: pipeline,
        registry: registry,
        navigationLauncher: NavigationLauncher(),
        mapBuilder: mapBuilder,
      ),
    );
  }
}
