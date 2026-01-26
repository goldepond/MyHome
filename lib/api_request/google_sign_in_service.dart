// 모바일/웹용 Google Sign-In 서비스
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In 처리 클래스
class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Google Sign-In 수행
  /// 성공 시 Firebase UserCredential 반환, 실패/취소 시 null 반환
  static Future<UserCredential?> signIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 사용자가 로그인 취소
        return null;
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Firebase credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase에 로그인
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
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

  /// 플랫폼 지원 여부
  static bool get isSupported => true;
}
