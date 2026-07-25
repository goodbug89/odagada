import 'package:url_launcher/url_launcher.dart';
import '../core/models/poi.dart';

/// 구글 지도 길찾기로 연결(글로벌). 구글 지도 앱이 있으면 앱에서, 없으면 브라우저에서 열린다.
class NavigationLauncher {
  Future<void> launch(Poi poi) async {
    await launchUrl(
      googleDirectionsUri(poi.position.lat, poi.position.lng),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// 목적지까지 자동차 경로를 여는 구글 지도 URL(api=1 유니버설 링크).
/// 앱이 설치돼 있으면 구글 지도 앱, 아니면 웹에서 경로가 열린다.
Uri googleDirectionsUri(double lat, double lng) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
