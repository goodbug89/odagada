import 'package:flutter_test/flutter_test.dart';
import 'package:odagada/ui/navigation_launcher.dart';

void main() {
  test('googleDirectionsUri는 구글 지도 자동차 경로 링크', () {
    final uri = googleDirectionsUri(37.5665, 126.9780);
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '37.5665,126.978');
    expect(uri.queryParameters['travelmode'], 'driving');
  });
}
