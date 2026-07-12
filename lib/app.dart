import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'location/location_source.dart';
import 'location/location_engine.dart';
import 'pipeline/recommendation_pipeline.dart';
import 'poi/poi_provider.dart';
import 'poi/kakao_client.dart';
import 'poi/restaurant_provider.dart';
import 'recommend/recommend_engine.dart';
import 'config/app_config.dart';
import 'ui/map_screen.dart';
import 'ui/navigation_launcher.dart';

class OdagadaApp extends StatelessWidget {
  const OdagadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = ProviderRegistry()
      ..register(RestaurantProvider(
        client: KakaoClient(
          client: http.Client(),
          restApiKey: AppConfig.kakaoRestApiKey,
        ),
      ));

    final pipeline = RecommendationPipeline(
      locationEngine: LocationEngine(minMoveMeters: 200),
      registry: registry,
      recommendEngine: RecommendEngine(),
    );

    return MaterialApp(
      title: '오다가다',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: MapScreen(
        locationSource: LocationSource(),
        pipeline: pipeline,
        registry: registry,
        navigationLauncher: NavigationLauncher(),
      ),
    );
  }
}
