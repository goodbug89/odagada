import 'dart:math' as math;
import '../core/geo/geo_math.dart';
import '../core/models/lat_lng.dart';
import '../core/models/lat_lng_bounds.dart';

/// 슬리피 맵 타일 좌표(z/x/y). 지도 데이터를 타일 단위로 받기 위한 키.
class TileKey {
  final int z, x, y;
  const TileKey(this.z, this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is TileKey && other.z == z && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'TileKey($z/$x/$y)';
}

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;
double _asinh(double x) => math.log(x + math.sqrt(x * x + 1.0));

int _xTile(double lng, int z) {
  final n = 1 << z;
  return ((lng + 180.0) / 360.0 * n).floor().clamp(0, n - 1);
}

int _yTile(double lat, int z) {
  final n = 1 << z;
  final latRad = lat * math.pi / 180.0;
  return ((1.0 - _asinh(math.tan(latRad)) / math.pi) / 2.0 * n)
      .floor()
      .clamp(0, n - 1);
}

double _lngOfTile(int x, int z) => x / (1 << z) * 360.0 - 180.0;

double _latOfTile(int y, int z) {
  final n = 1 << z;
  final t = math.pi * (1.0 - 2.0 * y / n);
  return math.atan(_sinh(t)) * 180.0 / math.pi;
}

/// (lat,lng)이 속한 줌 z 타일.
TileKey tileKeyOf(double lat, double lng, int z) =>
    TileKey(z, _xTile(lng, z), _yTile(lat, z));

/// 타일의 북동·남서 경계.
LatLngBounds tileBounds(TileKey key) {
  final north = _latOfTile(key.y, key.z);
  final south = _latOfTile(key.y + 1, key.z);
  final west = _lngOfTile(key.x, key.z);
  final east = _lngOfTile(key.x + 1, key.z);
  return LatLngBounds(
    ne: LatLng(north, east),
    sw: LatLng(south, west),
  );
}

/// 타일 중심 좌표.
LatLng tileCenter(TileKey key) => tileBounds(key).center;

/// 타일을 원으로 덮는 반경(중심→북동 코너 거리, m).
double tileRadiusMeters(TileKey key) {
  final b = tileBounds(key);
  return GeoMath.distanceMeters(b.center, b.ne);
}

/// bounds를 덮는 줌 z 타일 목록.
List<TileKey> tilesCovering(LatLngBounds bounds, int z) {
  final minX = _xTile(bounds.sw.lng, z);
  final maxX = _xTile(bounds.ne.lng, z);
  final minY = _yTile(bounds.ne.lat, z); // 북쪽 = 작은 y
  final maxY = _yTile(bounds.sw.lat, z); // 남쪽 = 큰 y
  final out = <TileKey>[];
  for (var x = minX; x <= maxX; x++) {
    for (var y = minY; y <= maxY; y++) {
      out.add(TileKey(z, x, y));
    }
  }
  return out;
}
