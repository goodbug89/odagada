import 'dart:async';
import 'dart:html' as html;

/// 웹에서 Google Maps JavaScript API를 런타임에 로드한다.
/// 키를 web/index.html에 하드코딩하지 않고 .env에서 주입해 커밋 노출을 피한다.
Future<void> loadGoogleMapsJs(String apiKey) async {
  if (html.document.querySelector('#google-maps-js') != null) return;
  final completer = Completer<void>();
  final script = html.ScriptElement()
    ..id = 'google-maps-js'
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$apiKey'
    ..async = true
    ..defer = true;
  script.onLoad.listen((_) => completer.complete());
  script.onError.listen((_) =>
      completer.completeError('Google Maps JS 로드 실패 (키/API 설정 확인)'));
  html.document.head!.append(script);
  return completer.future;
}
