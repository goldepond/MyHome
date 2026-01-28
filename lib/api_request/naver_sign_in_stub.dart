// Stub 파일 - 데스크톱 빌드용 (Windows/Linux/macOS)
// flutter_naver_login 패키지가 데스크톱을 지원하지 않아 stub으로 대체

/// 네이버 로그인 Stub - 데스크톱에서는 지원되지 않음
class NaverSignInService {
  /// 네이버 로그인 수행 - 데스크톱에서는 항상 null 반환
  static Future<Map<String, dynamic>?> signIn() async {
    return null;
  }

  /// 네이버 계정 정보 - 데스크톱에서는 항상 null
  static Future<dynamic> getCurrentUser() async {
    return null;
  }

  /// 네이버 로그아웃 - no-op
  static Future<void> signOut() async {}

  /// 플랫폼 지원 여부 - 데스크톱은 미지원
  static bool get isSupported => false;
}
