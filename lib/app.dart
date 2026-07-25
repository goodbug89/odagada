import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth/auth_controller.dart';
import 'core/models/lat_lng_bounds.dart';
import 'location/location_source.dart';
import 'poi/poi_provider.dart';
import 'poi/google_places_provider.dart';
import 'config/app_config.dart';
import 'friends/friend_repository.dart';
import 'friends/social_repository.dart';
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

  // build()가 재실행돼도 http.Client·ProviderRegistry·저장소를 다시 만들지 않도록
  // initState에서 한 번만 생성해 인스턴스 필드로 보관한다(MapScreen._poiSource가
  // registry를 캡처하므로 rebuild마다 새 registry가 생기면 기존 캡처가 고아가 되고
  // http.Client가 leak된다).
  late final http.Client _httpClient;
  late final GooglePlacesProvider _placesProvider;
  late final ProviderRegistry _registry;
  late final SavedPlaceRepository _savedRepo;
  late final FriendRepository _friendRepo;
  late final SocialRepository _socialRepo;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _placesProvider = GooglePlacesProvider(
      client: _httpClient,
      apiKey: AppConfig.googleMapsApiKey,
    );
    _registry = ProviderRegistry()..register(_placesProvider);
    _savedRepo = SavedPlaceRepository();
    _friendRepo = SupabaseFriendRepository();
    _socialRepo = SupabaseSocialRepository();
  }

  @override
  void dispose() {
    _auth.dispose();
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placesProvider = _placesProvider;
    final registry = _registry;

    final LocationSource locationSource =
        kIsWeb ? const FixedLocationSource() : GeolocatorLocationSource();

    Widget mapBuilder({
      required void Function(MapController) onReady,
      required PinTapCallback onPinTap,
      required void Function(LatLngBounds bounds, double zoom) onCameraIdle,
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
        savedRepo: _savedRepo,
        friendRepo: _friendRepo,
        socialRepo: _socialRepo,
        textSearch: (query, bias) =>
            placesProvider.searchText(query, bias: bias),
      ),
    );
  }
}
