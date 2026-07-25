import 'package:geolocator/geolocator.dart';
import '../core/models/lat_lng.dart';
import 'raw_fix.dart';

/// 위치 소스 인터페이스. 실제 GPS(모바일)와 고정 데모(웹)를 교체할 수 있게 한다.
abstract class LocationSource {
  Future<bool> ensurePermission();
  Stream<RawFix> stream();
}

/// 플랫폼 GPS를 RawFix 스트림으로 변환하는 어댑터.
class GeolocatorLocationSource implements LocationSource {
  @override
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  @override
  Stream<RawFix> stream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10m마다 raw 픽스(엔진이 200m로 다시 스로틀)
      ),
    ).map((p) => RawFix(
          position: LatLng(p.latitude, p.longitude),
          speedMps: p.speed,
          headingDeg: p.heading >= 0 ? p.heading : null,
          timestamp: p.timestamp,
        ));
  }
}

/// 웹/데모용: 실제 GPS 없이 고정 좌표(기본 서울시청)를 방출한다.
/// 권한 흐름 없이 결정적으로 지도·핀을 보여주기 위한 것.
class FixedLocationSource implements LocationSource {
  final LatLng center;
  const FixedLocationSource({this.center = const LatLng(37.5665, 126.9780)});

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Stream<RawFix> stream() async* {
    yield RawFix(
      position: center,
      speedMps: 8, // 주행 중으로 간주
      headingDeg: 0, // 북쪽 진행
      timestamp: DateTime.now(),
    );
  }
}
