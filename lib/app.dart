import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'location/location_source.dart';
import 'location/location_engine.dart';
import 'pipeline/recommendation_pipeline.dart';
import 'poi/poi_provider.dart';
import 'poi/kakao_client.dart';
import 'poi/restaurant_provider.dart';
import 'poi/google_places_provider.dart';
import 'recommend/recommend_engine.dart';
import 'config/app_config.dart';
import 'ui/map_screen.dart';
import 'ui/map_view.dart';
import 'ui/google_map_view.dart';
import 'ui/kakao_map_view.dart';
import 'ui/navigation_launcher.dart';

class OdagadaApp extends StatelessWidget {
  const OdagadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ProviderRegistry registry;
    final LocationSource locationSource;
    final MapViewBuilder mapBuilder;

    if (kIsWeb) {
      // 웹(Chrome) 데모: 구글맵 + 고정 위치 + 실제 Google Places 맛집.
      registry = ProviderRegistry()
        ..register(GooglePlacesProvider(
          client: http.Client(),
          apiKey: AppConfig.googleMapsApiKey,
        ));
      locationSource = const FixedLocationSource();
      mapBuilder = ({required onReady, required onPinTap}) =>
          GoogleMapView(onReady: onReady, onPinTap: onPinTap);
    } else {
      // 모바일: 기존 카카오맵 + 실제 GPS + 카카오 로컬 API.
      registry = ProviderRegistry()
        ..register(RestaurantProvider(
          client: KakaoClient(
            client: http.Client(),
            restApiKey: AppConfig.kakaoRestApiKey,
          ),
        ));
      locationSource = GeolocatorLocationSource();
      mapBuilder = ({required onReady, required onPinTap}) =>
          KakaoMapView(onReady: onReady, onPinTap: onPinTap);
    }

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
