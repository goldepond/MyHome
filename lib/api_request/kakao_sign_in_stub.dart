// Stub 파일 - 데스크톱 빌드용 (Windows/Linux/macOS)
// kakao_flutter_sdk 패키지가 데스크톱을 완전히 지원하지 않아 stub으로 대체

/// 카카오 로그인 Stub - 데스크톱에서는 지원되지 않음
class KakaoSignInService {
  /// 카카오 로그인 수행 - 데스크톱에서는 항상 null 반환
  static Future<Map<String, dynamic>?> signIn() async {
    return null;
  }

  /// 카카오 계정 정보 - 데스크톱에서는 항상 null
  static Future<dynamic> getCurrentUser() async {
    return null;
  }

  /// 카카오 로그아웃 - no-op
  static Future<void> signOut() async {}

  /// 다른 계정으로 로그인 - 데스크톱에서는 항상 null 반환
  static Future<Map<String, dynamic>?> signInWithNewAccount() async {
    return null;
  }

  /// 플랫폼 지원 여부 - 데스크톱은 미지원
  static bool get isSupported => false;
}
