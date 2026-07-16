import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth/auth_controller.dart';
import 'core/models/lat_lng.dart';
import 'location/location_source.dart';
import 'poi/poi_provider.dart';
import 'poi/google_places_provider.dart';
import 'config/app_config.dart';
import 'friends/friend_repository.dart';
import 'saved/saved_place_repository.dart';
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
    final placesProvider = GooglePlacesProvider(
      client: http.Client(),
      apiKey: AppConfig.googleMapsApiKey,
    );
    final registry = ProviderRegistry()..register(placesProvider);

    final LocationSource locationSource =
        kIsWeb ? const FixedLocationSource() : GeolocatorLocationSource();

    Widget mapBuilder({
      required void Function(MapController) onReady,
      required PinTapCallback onPinTap,
      required void Function(LatLng center, double radiusMeters) onCameraIdle,
      required VoidCallback onMapTap,
      required void Function(bool following) onFollowChanged,
    }) =>
        GoogleMapView(
          onReady: onReady,
          onPinTap: onPinTap,
          onCameraIdle: onCameraIdle,
          onMapTap: onMapTap,
          onFollowChanged: onFollowChanged,
        );

    return MaterialApp(
      title: '오다가다',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      home: MapScreen(
        auth: _auth,
        locationSource: locationSource,
        registry: registry,
        navigationLauncher: NavigationLauncher(),
        mapBuilder: mapBuilder,
        savedRepo: SavedPlaceRepository(),
        friendRepo: SupabaseFriendRepository(),
        textSearch: (query, bias) =>
            placesProvider.searchText(query, bias: bias),
      ),
    );
  }
}
