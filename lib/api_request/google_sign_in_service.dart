// 모바일/웹용 Google Sign-In 서비스
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/logger.dart';

/// Google Sign-In 처리 클래스
class GoogleSignInService {
  // serverClientId: google-services.json의 client_type: 3 (Web) OAuth 클라이언트 ID
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '1018586798653-nr1i1kl3eejtjmpebfiol2bkfd83ulmj.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  /// Google Sign-In 수행
  /// 성공 시 Firebase UserCredential 반환, 실패/취소 시 null 반환
  static Future<UserCredential?> signIn() async {
    try {
      Logger.info('[GoogleSignIn] 로그인 시작');

      // 1. 먼저 이미 로그인된 계정이 있는지 확인 (silent sign-in)
      // 타임아웃 3초 - 무한 대기 방지
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signInSilently()
            .timeout(const Duration(seconds: 3));
        Logger.info('[GoogleSignIn] silent 로그인 결과: ${googleUser?.email ?? "null"}');
      } catch (e) {
        Logger.info('[GoogleSignIn] silent 로그인 타임아웃 또는 실패: $e');
        googleUser = null;
      }

      // 2. silent 로그인 실패시 계정 선택 UI 표시
      if (googleUser == null) {
        Logger.info('[GoogleSignIn] 계정 선택 UI 표시');
        googleUser = await _googleSignIn.signIn();
      }
      Logger.info('[GoogleSignIn] googleUser: ${googleUser?.email ?? "null"}');

      if (googleUser == null) {
        Logger.info('[GoogleSignIn] 사용자가 로그인 취소');
        return null;
      }

      // Google 인증 정보 가져오기
      Logger.info('[GoogleSignIn] 인증 정보 가져오는 중...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      Logger.info('[GoogleSignIn] accessToken: ${googleAuth.accessToken != null ? "있음" : "없음"}');
      Logger.info('[GoogleSignIn] idToken: ${googleAuth.idToken != null ? "있음" : "없음"}');

      // Firebase credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      Logger.info('[GoogleSignIn] Firebase 로그인 시도...');
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      Logger.info('[GoogleSignIn] Firebase 로그인 성공: ${result.user?.uid}');
      return result;
    } catch (e, stackTrace) {
      Logger.error('[GoogleSignIn] 오류 발생: $e');
      Logger.error('[GoogleSignIn] 스택: $stackTrace');
      rethrow;
    }
  }

  /// Google 계정 정보 가져오기
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    return _googleSignIn.currentUser;
  }

  /// Google 로그아웃
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// 다른 계정으로 로그인 (기존 세션 클리어 후 계정 선택 UI 강제 표시)
  static Future<UserCredential?> signInWithNewAccount() async {
    try {
      Logger.info('[GoogleSignIn] 다른 계정으로 로그인 시작');

      // 기존 세션 클리어
      await _googleSignIn.signOut();
      Logger.info('[GoogleSignIn] 기존 세션 클리어 완료');

      // 계정 선택 UI 강제 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      Logger.info('[GoogleSignIn] 선택된 계정: ${googleUser?.email ?? "null"}');

      if (googleUser == null) {
        Logger.info('[GoogleSignIn] 사용자가 계정 선택 취소');
        return null;
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      Logger.info('[GoogleSignIn] 다른 계정 로그인 성공: ${result.user?.uid}');
      return result;
    } catch (e, stackTrace) {
      Logger.error('[GoogleSignIn] 다른 계정 로그인 오류: $e');
      Logger.error('[GoogleSignIn] 스택: $stackTrace');
      rethrow;
    }
  }

  /// 플랫폼 지원 여부
  static bool get isSupported => true;
}
