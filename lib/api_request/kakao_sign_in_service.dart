// 웹용 카카오 로그인 서비스
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:property/utils/logger.dart';

/// 카카오 로그인 처리 클래스 - 웹 플랫폼용
class KakaoSignInService {
  /// 카카오 로그인 수행
  /// 성공 시 사용자 정보 Map 반환, 실패/취소 시 null 반환
  static Future<Map<String, dynamic>?> signIn() async {
    Logger.info('[카카오 웹] ========== 로그인 시작 ==========');

    try {
      // SDK 초기화 상태 확인
      Logger.info('[카카오 웹] 1. SDK 상태 확인 중...');
      try {
        final appKey = KakaoSdk.appKey;
        Logger.info('[카카오 웹] - Native App Key: $appKey');
      } catch (e) {
        Logger.error('[카카오 웹] - SDK 초기화 안됨: $e');
      }

      // 카카오톡 설치 여부와 무관하게 웹에서는 카카오 계정 로그인 사용
      OAuthToken token;

      Logger.info('[카카오 웹] 2. 카카오 계정 로그인 시도...');
      try {
        // 카카오 계정으로 로그인 (웹에서는 이 방식만 사용)
        token = await UserApi.instance.loginWithKakaoAccount();
        Logger.info('[카카오 웹] 3. 로그인 성공!');
        Logger.info('[카카오 웹] - Access Token: ${token.accessToken.substring(0, 20)}...');
        Logger.info('[카카오 웹] - Token 만료: ${token.expiresAt}');
      } catch (e) {
        Logger.error('[카카오 웹] 3. 로그인 실패: $e');
        Logger.error('[카카오 웹] - 에러 타입: ${e.runtimeType}');
        return null;
      }

      // 사용자 정보 요청
      Logger.info('[카카오 웹] 4. 사용자 정보 요청 중...');
      try {
        final user = await UserApi.instance.me();
        Logger.info('[카카오 웹] 5. 사용자 정보 획득 성공!');
        Logger.info('[카카오 웹] - 사용자 ID: ${user.id}');
        Logger.info('[카카오 웹] - 닉네임: ${user.kakaoAccount?.profile?.nickname}');
        Logger.info('[카카오 웹] - 이메일: ${user.kakaoAccount?.email}');
        Logger.info('[카카오 웹] - 프로필 이미지: ${user.kakaoAccount?.profile?.profileImageUrl != null ? "있음" : "없음"}');

        final result = {
          'id': user.id.toString(),
          'nickname': user.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
          'email': user.kakaoAccount?.email,
          'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
          'thumbnailImageUrl': user.kakaoAccount?.profile?.thumbnailImageUrl,
          'accessToken': token.accessToken,
          'refreshToken': token.refreshToken,
        };

        Logger.info('[카카오 웹] 6. 반환 데이터 준비 완료');
        Logger.info('[카카오 웹] ========== 로그인 완료 ==========');
        return result;
      } catch (e) {
        Logger.error('[카카오 웹] 5. 사용자 정보 요청 실패: $e');
        return null;
      }
    } catch (e) {
      Logger.error('[카카오 웹] 예외 발생: $e');
      Logger.error('[카카오 웹] 에러 타입: ${e.runtimeType}');
      return null;
    }
  }

  /// 카카오 계정 정보 가져오기
  static Future<User?> getCurrentUser() async {
    try {
      return await UserApi.instance.me();
    } catch (e) {
      Logger.error('카카오 사용자 정보 조회 실패: $e');
      return null;
    }
  }

  /// 카카오 로그아웃
  static Future<void> signOut() async {
    try {
      await UserApi.instance.logout();
      Logger.info('카카오 로그아웃 성공');
    } catch (e) {
      Logger.error('카카오 로그아웃 실패: $e');
    }
  }

  /// 플랫폼 지원 여부
  static bool get isSupported => true;
}
