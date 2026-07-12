import 'package:url_launcher/url_launcher.dart';
import '../core/models/poi.dart';

/// 카카오맵 길찾기로 연결. 앱 딥링크 우선, 실패 시 웹 폴백.
class NavigationLauncher {
  Future<void> launch(Poi poi) async {
    final lat = poi.position.lat;
    final lng = poi.position.lng;
    final appUri = Uri.parse('kakaomap://route?ep=$lat,$lng&by=CAR');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }
    final webUri = Uri.parse(
        'https://map.kakao.com/link/to/${Uri.encodeComponent(poi.name)},$lat,$lng');
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
