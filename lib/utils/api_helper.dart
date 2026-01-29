import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

/// API 호출 헬퍼 - 플랫폼에 따라 프록시 사용 여부 결정
///
/// - 웹: CORS 제한으로 인해 프록시 서버 사용
/// - 모바일(Android/iOS): 직접 API 호출 (CORS 제한 없음)
class ApiHelper {
  /// 플랫폼에 맞는 URI 반환
  ///
  /// [originalUri] - 원본 API URI
  /// 웹에서는 프록시를 통해 호출, 모바일에서는 직접 호출
  static Uri getRequestUri(Uri originalUri) {
    if (kIsWeb) {
      // 웹: 프록시 사용
      return Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(originalUri.toString())}',
      );
    } else {
      // 모바일: 직접 호출
      return originalUri;
    }
  }

  /// 플랫폼에 맞는 URI 반환 (String URL 버전)
  static Uri getRequestUriFromString(String url) {
    return getRequestUri(Uri.parse(url));
  }

  /// HTTP GET 요청 수행 (플랫폼에 맞게 프록시 처리)
  static Future<http.Response> get(Uri uri, {Duration? timeout}) async {
    final requestUri = getRequestUri(uri);

    if (timeout != null) {
      return http.get(requestUri).timeout(timeout);
    }
    return http.get(requestUri);
  }

  /// HTTP GET 요청 수행 (String URL 버전)
  static Future<http.Response> getFromString(String url, {Duration? timeout}) async {
    return get(Uri.parse(url), timeout: timeout);
  }
}
