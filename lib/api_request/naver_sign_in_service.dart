// 웹용 네이버 로그인 서비스
// 현재 flutter_naver_login은 웹을 지원하지 않음
// 웹에서 네이버 로그인이 필요한 경우 네이버 JavaScript SDK를 별도로 연동해야 함
import 'package:property/utils/logger.dart';

/// 네이버 로그인 처리 클래스 - 웹 플랫폼용
/// 현재 웹에서는 지원되지 않음
class NaverSignInService {
  /// 네이버 로그인 수행 - 웹에서는 미지원
  static Future<Map<String, dynamic>?> signIn() async {
    Logger.warning('[네이버 웹] 네이버 로그인은 현재 웹에서 지원되지 않습니다.');
    Logger.info('[네이버 웹] 모바일 앱에서 네이버 로그인을 이용해주세요.');
    return null;
  }

  /// 네이버 계정 정보 - 웹에서는 미지원
  static Future<dynamic> getCurrentUser() async {
    return null;
  }

  /// 네이버 로그아웃 - no-op
  static Future<void> signOut() async {}

  /// 네이버 연결 해제 - no-op
  static Future<void> unlink() async {}

  /// 플랫폼 지원 여부 - 웹은 미지원
  static bool get isSupported => false;
}
