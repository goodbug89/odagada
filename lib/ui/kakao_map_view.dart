import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../config/app_config.dart';
import '../core/models/lat_lng.dart';
import '../core/models/poi.dart';
import '../core/models/recommendation.dart';
import 'map_view.dart';

/// 카카오맵 JS SDK를 webview_flutter로 렌더링하는 지도 위젯.
class KakaoMapView extends StatefulWidget {
  final PinTapCallback onPinTap;
  final void Function(MapController controller) onReady;
  const KakaoMapView({super.key, required this.onPinTap, required this.onReady});

  @override
  State<KakaoMapView> createState() => _KakaoMapViewState();
}

class _KakaoMapViewState extends State<KakaoMapView> implements MapController {
  late final WebViewController _web;
  List<Recommendation> _lastRecs = const [];

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('MapReady',
          onMessageReceived: (_) => widget.onReady(this))
      ..addJavaScriptChannel('PinChannel', onMessageReceived: (msg) {
        final poi = _findPoi(msg.message);
        if (poi != null) widget.onPinTap(poi);
      });
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      var html = await rootBundle.loadString('assets/kakao_map.html');
      html = html.replaceAll('__KAKAO_JS_KEY__', AppConfig.kakaoJsAppKey);
      await _web.loadHtmlString(html);
    } catch (e, st) {
      // 에셋 누락이나 빈 키(StateError)가 조용히 삼켜지지 않도록 표면화한다.
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'odagada',
        context: ErrorDescription('카카오맵 로드 실패'),
      ));
    }
  }

  Poi? _findPoi(String id) {
    for (final r in _lastRecs) {
      if (r.poi.id == id) return r.poi;
    }
    return null;
  }

  @override
  void setCar(LatLng car) {} // 레거시(구글로 전환됨) — 미사용
  @override
  void recenter() {} // 레거시 — 미사용

  @override
  void setPins(List<Recommendation> recs) {
    _lastRecs = recs;
    final items = recs
        .map((r) => {
              'id': r.poi.id,
              'name': r.poi.name,
              'lat': r.poi.position.lat,
              'lng': r.poi.position.lng,
            })
        .toList();
    final json = jsonEncode(items);
    _web.runJavaScript('window.setPins(${jsonEncode(json)});');
  }

  @override
  void setSavedIds(Set<String> ids) {} // 레거시(구글로 전환됨) — 미사용

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
