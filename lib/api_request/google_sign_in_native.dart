// 네이티브(모바일/데스크톱) Google Sign-In 서비스
// 모바일: 실제 google_sign_in 사용
// 데스크톱: 런타임에 지원 불가 반환
import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google Sign-In 처리 클래스 - 네이티브 플랫폼용
class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Google Sign-In 수행
  /// 성공 시 Firebase UserCredential 반환, 실패/취소 시 null 반환
  static Future<UserCredential?> signIn() async {
    // 데스크톱에서는 지원하지 않음
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

  /// Google 계정 정보 가져오기
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }
    return _googleSignIn.currentUser;
  }

  /// Google 로그아웃
  static Future<void> signOut() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return;
    }
    await _googleSignIn.signOut();
  }

  /// 플랫폼 지원 여부
  static bool get isSupported {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    return true; // Android, iOS
  }
}
