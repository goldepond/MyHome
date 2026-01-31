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

      // 1. 이미 저장된 토큰이 있는지 확인 (타임아웃 3초)
      Logger.info('[카카오 웹] 2. 기존 토큰 확인 중...');
      bool hasValidToken = false;
      try {
        hasValidToken = await AuthApi.instance.hasToken()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        Logger.info('[카카오 웹] - 토큰 확인 타임아웃: $e');
      }

      if (hasValidToken) {
        Logger.info('[카카오 웹] - 기존 토큰 발견, 유효성 검사 중...');
        try {
          await UserApi.instance.accessTokenInfo()
              .timeout(const Duration(seconds: 3));
          Logger.info('[카카오 웹] - 토큰 유효함');

          // 토큰이 유효하면 바로 사용자 정보 가져오기
          final user = await UserApi.instance.me()
              .timeout(const Duration(seconds: 5));
          final token = await TokenManagerProvider.instance.manager.getToken();

          Logger.info('[카카오 웹] - 기존 세션으로 로그인 성공: ${user.id}');
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
          Logger.info('[카카오 웹] - 토큰 만료됨 또는 타임아웃, 새로 로그인 진행: $e');
        }
      }

      // 2. 새로 로그인 필요
      OAuthToken token;

      Logger.info('[카카오 웹] 3. 카카오 계정 로그인 시도...');
      try {
        // 카카오 계정으로 로그인 (웹에서는 이 방식만 사용)
        // 타임아웃 60초 - 사용자가 카카오 로그인 팝업에서 선택하는 시간 고려
        token = await UserApi.instance.loginWithKakaoAccount()
            .timeout(const Duration(seconds: 60));
        Logger.info('[카카오 웹] 4. 로그인 성공!');
        Logger.info('[카카오 웹] - Access Token: ${token.accessToken.substring(0, 20)}...');
        Logger.info('[카카오 웹] - Token 만료: ${token.expiresAt}');
      } catch (e) {
        Logger.error('[카카오 웹] 4. 로그인 실패 또는 타임아웃: $e');
        Logger.error('[카카오 웹] - 에러 타입: ${e.runtimeType}');
        return null;
      }

      // 사용자 정보 요청 (타임아웃 10초)
      Logger.info('[카카오 웹] 5. 사용자 정보 요청 중...');
      try {
        final user = await UserApi.instance.me()
            .timeout(const Duration(seconds: 10));
        Logger.info('[카카오 웹] 6. 사용자 정보 획득 성공!');
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

        Logger.info('[카카오 웹] 7. 반환 데이터 준비 완료');
        Logger.info('[카카오 웹] ========== 로그인 완료 ==========');
        return result;
      } catch (e) {
        Logger.error('[카카오 웹] 6. 사용자 정보 요청 실패: $e');
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

    // 로컬 토큰도 삭제하여 다음 로그인 시 새로 인증하도록 함
    try {
      await TokenManagerProvider.instance.manager.clear();
      Logger.info('카카오 로컬 토큰 삭제 성공');
    } catch (e) {
      Logger.warning('카카오 로컬 토큰 삭제 실패 (무시): $e');
    }
  }

  /// 다른 계정으로 로그인 (기존 세션 클리어 후 계정 선택 강제)
  static Future<Map<String, dynamic>?> signInWithNewAccount() async {
    try {
      Logger.info('[카카오 웹] 다른 계정으로 로그인 시작');

      // 기존 세션 클리어
      try {
        await UserApi.instance.logout();
        Logger.info('[카카오 웹] 기존 세션 클리어 완료');
      } catch (e) {
        Logger.warning('[카카오 웹] 기존 세션 클리어 실패 (무시): $e');
      }

      // 새로 로그인
      final token = await UserApi.instance.loginWithKakaoAccount();
      Logger.info('[카카오 웹] 새 계정 로그인 성공');

      final user = await UserApi.instance.me();
      Logger.info('[카카오 웹] 새 계정 사용자 정보: ${user.id}');

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
      Logger.error('[카카오 웹] 다른 계정 로그인 오류: $e');
      return null;
    }
  }

  /// 플랫폼 지원 여부
  static bool get isSupported => true;
}
