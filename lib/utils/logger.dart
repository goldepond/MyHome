import 'package:flutter/foundation.dart';

/// 간단한 로깅 유틸리티
/// 디버그 모드에서만 로그를 출력합니다
class Logger {
  /// 에러 로그 출력
  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      final contextStr = context != null ? '[$context] ' : '';
      debugPrint('❌ $contextStr$message');
      
      if (error != null) {
        debugPrint('   오류: $error');
      }
      
      if (stackTrace != null) {
        debugPrint('   스택 트레이스: $stackTrace');
      }
      
      if (metadata != null && metadata.isNotEmpty) {
        debugPrint('   메타데이터: $metadata');
      }
    }
  }

  /// 경고 로그 출력
  static void warning(
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      debugPrint('⚠️ $message');
      if (metadata != null && metadata.isNotEmpty) {
        debugPrint('   메타데이터: $metadata');
      }
    }
  }

  /// 정보 로그 출력
  static void info(
    String message, {
    Map<String, dynamic>? metadata,
  }) {
    if (kDebugMode) {
      debugPrint('ℹ️ $message');
      if (metadata != null && metadata.isNotEmpty) {
        debugPrint('   메타데이터: $metadata');
      }
    }
  }
}
