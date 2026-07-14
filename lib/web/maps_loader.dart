// 플랫폼별 Google Maps JS 로더. 웹에서만 실제 로드하고, 그 외엔 no-op.
export 'maps_loader_stub.dart'
    if (dart.library.html) 'maps_loader_web.dart';
