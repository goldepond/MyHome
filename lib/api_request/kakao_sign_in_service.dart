// 웹용 카카오 로그인 서비스
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:property/utils/logger.dart';

/// 카카오 로그인 처리 클래스 - 웹 플랫폼용
class KakaoSignInService {
  /// 카카오 로그인 수행
  /// 성공 시 사용자 정보 Map 반환, 실패/취소 시 null 반환
  static Future<Map<String, dynamic>?> signIn() async {
    try {
      // 1. 이미 저장된 토큰이 있는지 확인 (타임아웃 3초)
      bool hasValidToken = false;
      try {
        hasValidToken = await AuthApi.instance.hasToken()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        // 토큰 확인 실패 시 무시
      }

      if (hasValidToken) {
        try {
          await UserApi.instance.accessTokenInfo()
              .timeout(const Duration(seconds: 3));

          // 토큰이 유효하면 바로 사용자 정보 가져오기
          final user = await UserApi.instance.me()
              .timeout(const Duration(seconds: 5));
          final token = await TokenManagerProvider.instance.manager.getToken();

          return {
            'id': user.id.toString(),
            'nickname': user.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
            'email': user.kakaoAccount?.email,
            'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
            'thumbnailImageUrl': user.kakaoAccount?.profile?.thumbnailImageUrl,
            'accessToken': token?.accessToken,
            'refreshToken': token?.refreshToken,
          };
        } catch (e) {
          // 토큰 만료됨, 새로 로그인 진행
        }
      }

      // 2. 새로 로그인 필요
      OAuthToken token;

      try {
        // 카카오 계정으로 로그인 (웹에서는 이 방식만 사용)
        // 타임아웃 60초 - 사용자가 카카오 로그인 팝업에서 선택하는 시간 고려
        token = await UserApi.instance.loginWithKakaoAccount()
            .timeout(const Duration(seconds: 60));
      } catch (e) {
        return null;
      }

      // 사용자 정보 요청 (타임아웃 10초)
      try {
        final user = await UserApi.instance.me()
            .timeout(const Duration(seconds: 10));

        return {
          'id': user.id.toString(),
          'nickname': user.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
          'email': user.kakaoAccount?.email,
          'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
          'thumbnailImageUrl': user.kakaoAccount?.profile?.thumbnailImageUrl,
          'accessToken': token.accessToken,
          'refreshToken': token.refreshToken,
        };
      } catch (e) {
        return null;
      }
    } catch (e) {
      Logger.error('카카오 로그인 오류', error: e);
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
    } catch (e) {
      Logger.warning('카카오 로그아웃 실패: $e');
    }

    // 로컬 토큰도 삭제하여 다음 로그인 시 새로 인증하도록 함
    try {
      await TokenManagerProvider.instance.manager.clear();
    } catch (e) {
      // 무시
    }
  }

  /// 다른 계정으로 로그인 (기존 세션 클리어 후 계정 선택 강제)
  static Future<Map<String, dynamic>?> signInWithNewAccount() async {
    try {
      // 기존 세션 클리어
      try {
        await UserApi.instance.logout();
      } catch (e) {
        // 무시
      }

      // 새로 로그인
      final token = await UserApi.instance.loginWithKakaoAccount();
      final user = await UserApi.instance.me();

      return {
        'id': user.id.toString(),
        'nickname': user.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
        'email': user.kakaoAccount?.email,
        'profileImageUrl': user.kakaoAccount?.profile?.profileImageUrl,
        'thumbnailImageUrl': user.kakaoAccount?.profile?.thumbnailImageUrl,
        'accessToken': token.accessToken,
        'refreshToken': token.refreshToken,
      };
    } catch (e) {
      Logger.error('카카오 다른 계정 로그인 오류', error: e);
      return null;
    }
  }

  /// 플랫폼 지원 여부
  static bool get isSupported => true;
}
