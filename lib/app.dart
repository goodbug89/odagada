import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth/auth_controller.dart';
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

class OdagadaApp extends StatefulWidget {
  const OdagadaApp({super.key});
  @override
  State<OdagadaApp> createState() => _OdagadaAppState();
}

class _OdagadaAppState extends State<OdagadaApp> {
  final AuthController _auth = AuthController();

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = ProviderRegistry()
      ..register(GooglePlacesProvider(
        client: http.Client(),
        apiKey: AppConfig.googleMapsApiKey,
      ));

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
        auth: _auth,
        locationSource: locationSource,
        pipeline: pipeline,
        registry: registry,
        navigationLauncher: NavigationLauncher(),
        mapBuilder: mapBuilder,
      ),
    );
  }
}
