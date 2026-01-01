// 웹 전용 파일 - 웹 빌드에서만 사용됩니다.
import 'package:web/web.dart' as web;

/// 웹 전용: Flutter 앱 준비 완료 신호 전송
void dispatchFlutterAppReady() {
  web.window.dispatchEvent(web.Event('flutterAppReady'));
}

