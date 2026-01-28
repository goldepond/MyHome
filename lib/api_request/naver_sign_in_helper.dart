// 조건부 export: 플랫폼에 따라 다른 구현 선택
// - 웹: naver_sign_in_service.dart
// - 네이티브: naver_sign_in_native.dart (런타임에 Platform 체크)
export 'naver_sign_in_stub.dart'
    if (dart.library.io) 'naver_sign_in_native.dart'
    if (dart.library.html) 'naver_sign_in_service.dart';
