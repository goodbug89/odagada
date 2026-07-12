import '../core/models/location_event.dart';
import '../core/models/poi.dart';

/// 모든 "주변 정보 모듈"의 공통 인터페이스. 맛집이 첫 구현체.
abstract class PoiProvider {
  String get id;          // "restaurant", "realEstate", "golf"
  String get displayName;
  Future<List<Poi>> nearby(LocationEvent loc, {required double radiusMeters});
}

/// 활성 Provider들을 등록/조회하는 레지스트리(다중 모듈 확장 지점).
class ProviderRegistry {
  final List<PoiProvider> _providers = [];
  void register(PoiProvider p) => _providers.add(p);
  List<PoiProvider> get all => List.unmodifiable(_providers);
  PoiProvider? byId(String id) {
    for (final p in _providers) {
      if (p.id == id) return p;
    }
    return null;
  }
}
