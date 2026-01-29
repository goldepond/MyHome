// 네이티브(모바일/데스크톱) 카카오 로그인 서비스
// 모바일: 실제 kakao_flutter_sdk 사용
// 데스크톱: 런타임에 지원 불가 반환
import 'dart:io' show Platform;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:property/utils/logger.dart';

/// 카카오 로그인 처리 클래스 - 네이티브 플랫폼용
class KakaoSignInService {
  /// 카카오 로그인 수행
  /// 성공 시 사용자 정보 Map 반환, 실패/취소 시 null 반환
  static Future<Map<String, dynamic>?> signIn() async {
    // 데스크톱에서는 지원하지 않음
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      Logger.warning('카카오 로그인은 데스크톱에서 지원되지 않습니다.');
      return null;
    }

    try {
      Logger.info('[카카오 네이티브] 로그인 시작');

      // 1. 이미 저장된 토큰이 있는지 확인
      if (await AuthApi.instance.hasToken()) {
        Logger.info('[카카오 네이티브] 기존 토큰 발견, 유효성 검사 중...');
        try {
          // 토큰 유효성 검사
          await UserApi.instance.accessTokenInfo();
          Logger.info('[카카오 네이티브] 토큰 유효함 - 바로 사용자 정보 조회');

          // 토큰이 유효하면 바로 사용자 정보 가져오기
          final user = await UserApi.instance.me();
          final token = await TokenManagerProvider.instance.manager.getToken();

          Logger.info('[카카오 네이티브] 기존 세션으로 로그인 성공: ${user.id}');
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
          Logger.info('[카카오 네이티브] 토큰 만료됨, 새로 로그인 진행');
        }
      }

      // 2. 새로 로그인 필요
      OAuthToken token;

      // 카카오톡 설치 여부 확인 (모바일에서만 의미 있음)
      if (await isKakaoTalkInstalled()) {
        try {
          // 카카오톡으로 로그인
          token = await UserApi.instance.loginWithKakaoTalk();
          Logger.info('[카카오 네이티브] 카카오톡 로그인 성공');
        } catch (e) {
          Logger.warning('[카카오 네이티브] 카카오톡 로그인 실패, 카카오 계정으로 시도: $e');
          // 카카오톡 로그인 실패 시 카카오 계정으로 로그인 시도
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        // 카카오톡 미설치 시 카카오 계정으로 로그인
        token = await UserApi.instance.loginWithKakaoAccount();
        Logger.info('[카카오 네이티브] 카카오 계정 로그인 성공');
      }

      // 사용자 정보 요청
      final user = await UserApi.instance.me();
      Logger.info('[카카오 네이티브] 사용자 정보: ${user.id}');

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
      Logger.error('[카카오 네이티브] 로그인 오류: $e');
      return null;
    }
  }

  /// 카카오 계정 정보 가져오기
  static Future<User?> getCurrentUser() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }

    try {
      return await UserApi.instance.me();
    } catch (e) {
      Logger.error('카카오 사용자 정보 조회 실패: $e');
      return null;
    }
  }

  /// 카카오 로그아웃
  static Future<void> signOut() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return;
    }

    try {
      await UserApi.instance.logout();
      Logger.info('카카오 로그아웃 성공');
    } catch (e) {
      Logger.error('카카오 로그아웃 실패: $e');
    }
  }

  /// 다른 계정으로 로그인 (기존 세션 클리어 후 계정 선택 강제)
  static Future<Map<String, dynamic>?> signInWithNewAccount() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      Logger.warning('카카오 로그인은 데스크톱에서 지원되지 않습니다.');
      return null;
    }

    try {
      Logger.info('[카카오 네이티브] 다른 계정으로 로그인 시작');

      // 기존 세션 클리어
      try {
        await UserApi.instance.logout();
        Logger.info('[카카오 네이티브] 기존 세션 클리어 완료');
      } catch (e) {
        Logger.warning('[카카오 네이티브] 기존 세션 클리어 실패 (무시): $e');
      }

      // 새로 로그인
      OAuthToken token;

      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
          Logger.info('[카카오 네이티브] 카카오톡으로 새 계정 로그인 성공');
        } catch (e) {
          Logger.warning('[카카오 네이티브] 카카오톡 로그인 실패, 카카오 계정으로 시도: $e');
          token = await UserApi.instance.loginWithKakaoAccount();
        }
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
        Logger.info('[카카오 네이티브] 카카오 계정으로 새 계정 로그인 성공');
      }

      final user = await UserApi.instance.me();
      Logger.info('[카카오 네이티브] 새 계정 사용자 정보: ${user.id}');

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
      Logger.error('[카카오 네이티브] 다른 계정 로그인 오류: $e');
      return null;
    }
  }

  /// 플랫폼 지원 여부
  static bool get isSupported {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    return true; // Android, iOS
  }
}
