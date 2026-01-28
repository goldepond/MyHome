// 네이티브(모바일) 네이버 로그인 서비스
// 모바일: flutter_naver_login 사용
// 데스크톱: 런타임에 지원 불가 반환
import 'dart:io' show Platform;
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:property/utils/logger.dart';

/// 네이버 로그인 처리 클래스 - 네이티브 플랫폼용
class NaverSignInService {
  /// 네이버 로그인 수행
  /// 성공 시 사용자 정보 Map 반환, 실패/취소 시 null 반환
  static Future<Map<String, dynamic>?> signIn() async {
    // 데스크톱에서는 지원하지 않음
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      Logger.warning('네이버 로그인은 데스크톱에서 지원되지 않습니다.');
      return null;
    }

    try {
      Logger.info('[네이버] 로그인 시도...');

      // 네이버 로그인 수행
      final NaverLoginResult result = await FlutterNaverLogin.logIn();

      if (result.status == NaverLoginStatus.loggedIn) {
        Logger.info('[네이버] 로그인 성공!');

        // 사용자 정보 가져오기
        final NaverAccountResult account = await FlutterNaverLogin.currentAccount();

        Logger.info('[네이버] 사용자 정보:');
        Logger.info('[네이버] - ID: ${account.id}');
        Logger.info('[네이버] - 이름: ${account.name}');
        Logger.info('[네이버] - 이메일: ${account.email}');
        Logger.info('[네이버] - 닉네임: ${account.nickname}');

        return {
          'id': account.id,
          'name': account.name,
          'nickname': account.nickname,
          'email': account.email,
          'profileImageUrl': account.profileImage,
          'gender': account.gender,
          'birthday': account.birthday,
          'mobile': account.mobile,
          'accessToken': result.accessToken.accessToken,
          'refreshToken': result.accessToken.refreshToken,
          'tokenType': result.accessToken.tokenType,
        };
      } else if (result.status == NaverLoginStatus.cancelledByUser) {
        Logger.info('[네이버] 사용자가 로그인을 취소했습니다.');
        return null;
      } else {
        Logger.error('[네이버] 로그인 실패: ${result.errorMessage}');
        return null;
      }
    } catch (e) {
      Logger.error('[네이버] 로그인 오류: $e');
      return null;
    }
  }

  /// 네이버 계정 정보 가져오기
  static Future<NaverAccountResult?> getCurrentUser() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }

    try {
      return await FlutterNaverLogin.currentAccount();
    } catch (e) {
      Logger.error('[네이버] 사용자 정보 조회 실패: $e');
      return null;
    }
  }

  /// 네이버 로그아웃
  static Future<void> signOut() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return;
    }

    try {
      await FlutterNaverLogin.logOut();
      Logger.info('[네이버] 로그아웃 성공');
    } catch (e) {
      Logger.error('[네이버] 로그아웃 실패: $e');
    }
  }

  /// 네이버 연결 해제 (탈퇴)
  static Future<void> unlink() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return;
    }

    try {
      await FlutterNaverLogin.logOutAndDeleteToken();
      Logger.info('[네이버] 연결 해제 성공');
    } catch (e) {
      Logger.error('[네이버] 연결 해제 실패: $e');
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
