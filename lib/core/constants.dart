// lib/core/constants.dart

/// 주변(ambient) POI 검색·렌더링 게이트 줌 레벨.
/// 이 값 미만이면 일반 POI를 검색하지도, 그리지도 않는다(친구/저장 핀은 항상 표시).
const int ambientPoiMinZoom = 16;

/// 앱 커스텀 URI 스킴(딥링크 폴백·OAuth 리다이렉트 공용).
const String appUriScheme = 'io.supabase.odagada';
