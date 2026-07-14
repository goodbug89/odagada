import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/poi.dart';
import '../location/location_source.dart';
import '../pipeline/recommendation_pipeline.dart';
import '../poi/poi_provider.dart';
import 'map_view.dart';
import 'info_card.dart';
import 'module_selector.dart';
import 'navigation_launcher.dart';

class MapScreen extends StatefulWidget {
  final LocationSource locationSource;
  final RecommendationPipeline pipeline;
  final ProviderRegistry registry;
  final NavigationLauncher navigationLauncher;
  final MapViewBuilder mapBuilder;

  const MapScreen({
    super.key,
    required this.locationSource,
    required this.pipeline,
    required this.registry,
    required this.navigationLauncher,
    required this.mapBuilder,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _map;
  StreamSubscription? _sub;
  Poi? _selected;
  String? _error;
  RecommendationUpdate? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await widget.locationSource.ensurePermission();
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '위치 권한이 필요합니다. 설정에서 허용해 주세요.');
      return;
    }
    _sub = widget.pipeline.run(widget.locationSource.stream()).listen(_onUpdate);
  }

  void _onUpdate(RecommendationUpdate u) {
    _lastUpdate = u;
    _applyToMap(u);
  }

  void _applyToMap(RecommendationUpdate u) {
    _map?.setPins(u.recommendations); // 전체 현재 추천 = 안정적인 핀 필드
    _map?.moveCamera(u.location.position); // 카메라는 차량(현재 위치) 추적
  }

  void _onPinTap(Poi poi) => setState(() => _selected = poi);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('오다가다'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ModuleSelector(registry: widget.registry),
            )),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.mapBuilder(
              onReady: (c) {
                _map = c;
                final last = _lastUpdate;
                if (last != null) _applyToMap(last);
              },
              onPinTap: _onPinTap,
            ),
          ),
          if (_selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: InfoCard(
                poi: _selected!,
                onNavigate: () => widget.navigationLauncher.launch(_selected!),
              ),
            ),
        ],
      ),
    );
  }
}
