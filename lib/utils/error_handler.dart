import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/error_messages.dart';
import 'package:property/utils/network_status.dart';
import 'package:property/utils/logger.dart';

/// 에러 타입 구분
enum ErrorType {
  network,
  timeout,
  server,
  auth,
  validation,
  permission,
  notFound,
  unknown,
}

/// 일관된 에러 처리 유틸리티 클래스
class ErrorHandler {
  /// 예외를 사용자 친화적 메시지로 변환
  static String getUserFriendlyMessage(dynamic error, {String? defaultMessage}) {
    try {
      // null 체크
      if (error == null) {
        return defaultMessage ?? ErrorMessages.unknown;
      }

      // String 타입인 경우 그대로 반환 (이미 사용자 친화적 메시지일 가능성)
      if (error is String) {
        if (_isAlreadyUserFriendly(error)) {
          return error;
        }
        return defaultMessage ?? ErrorMessages.unknown;
      }

      // Firebase Auth 예외 처리
      if (error is FirebaseAuthException) {
        return _getFirebaseAuthMessage(error);
      }

      // Firestore 예외 처리
      if (error is FirebaseException) {
        return _getFirebaseMessage(error);
      }

      // HTTP 관련 예외 처리
      if (error is http.ClientException || error.toString().contains('SocketException')) {
        // 오프라인 상태 확인 (비동기이지만 동기적으로 처리)
        // 실제로는 호출하는 쪽에서 네트워크 상태를 먼저 확인하는 것이 좋음
        return ErrorMessages.network;
      }

      // Timeout 예외 처리
      if (error is TimeoutException || error.toString().contains('TimeoutException')) {
        return ErrorMessages.timeout;
      }

      // Format 예외 처리
      if (error is FormatException) {
        return ErrorMessages.validation;
      }

      // 일반 예외 처리
      final errorString = error.toString();
      
      // 이미 사용자 친화적 메시지인 경우
      if (_isAlreadyUserFriendly(errorString)) {
        return errorString;
      }

      // 기술적 오류 메시지 숨기기
      // "Instance of", "minified:" 등은 사용자에게 보여주지 않음
      if (errorString.contains('Instance of') || 
          errorString.contains('minified:') ||
          errorString.startsWith('Exception:') ||
          errorString.startsWith('Error:')) {
        return defaultMessage ?? ErrorMessages.unknown;
      }

      // 특정 패턴이 포함된 경우
      if (errorString.toLowerCase().contains('network') || 
          errorString.toLowerCase().contains('connection')) {
        return ErrorMessages.network;
      }

      if (errorString.toLowerCase().contains('timeout')) {
        return ErrorMessages.timeout;
      }

      if (errorString.toLowerCase().contains('permission') ||
          errorString.toLowerCase().contains('unauthorized')) {
        return ErrorMessages.permission;
      }

      if (errorString.toLowerCase().contains('not found')) {
        return ErrorMessages.notFound;
      }

      // 기본 메시지 반환
      return defaultMessage ?? ErrorMessages.unknown;
    } catch (e) {
      // 에러 처리 중 오류 발생 시 기본 메시지 반환
      Logger.error(
        'ErrorHandler: 에러 처리 중 오류 발생',
        error: e,
        context: 'error_handler',
      );
      return defaultMessage ?? ErrorMessages.unknown;
    }
  }

  /// Firebase Auth 예외를 사용자 친화적 메시지로 변환
  static String _getFirebaseAuthMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        return ErrorMessages.userNotFound;
      case 'wrong-password':
        return ErrorMessages.wrongPassword;
      case 'weak-password':
        return ErrorMessages.weakPassword;
      case 'email-already-in-use':
        return ErrorMessages.emailAlreadyInUse;
      case 'invalid-email':
        return ErrorMessages.invalidEmail;
      case 'requires-recent-login':
        return ErrorMessages.requiresRecentLogin;
      case 'user-disabled':
        return '계정이 비활성화되었습니다.\n고객센터로 문의해주세요.';
      case 'too-many-requests':
        return '너무 많은 시도가 있었습니다.\n잠시 후 다시 시도해주세요.';
      case 'operation-not-allowed':
        return '허용되지 않은 작업입니다.';
      case 'network-request-failed':
        return ErrorMessages.network;
      default:
        return ErrorMessages.authFailed;
    }
  }

  /// Firebase 예외를 사용자 친화적 메시지로 변환
  static String _getFirebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return ErrorMessages.permission;
      case 'not-found':
        return ErrorMessages.notFound;
      case 'unavailable':
        return ErrorMessages.network;
      case 'deadline-exceeded':
        return ErrorMessages.timeout;
      case 'unauthenticated':
        return ErrorMessages.authRequired;
      default:
        return ErrorMessages.server;
    }
  }

  /// 이미 사용자 친화적 메시지인지 확인
  static bool _isAlreadyUserFriendly(String message) {
    // 한국어로 된 문장이 포함되어 있으면 사용자 친화적 메시지로 간주
    final koreanPattern = RegExp(r'[가-힣]+');
    if (koreanPattern.hasMatch(message)) {
      // 기술적 오류 메시지가 아닌 경우만
      if (!message.contains('Instance of') &&
          !message.contains('minified:') &&
          !message.startsWith('Exception:') &&
          !message.startsWith('Error:') &&
          !message.contains('StackTrace')) {
        return true;
      }
    }
    return false;
  }

  /// 에러 타입 분류
  static ErrorType classifyError(dynamic error) {
    if (error is FirebaseAuthException) {
      return ErrorType.auth;
    }
    
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return ErrorType.permission;
      }
      if (error.code == 'not-found') {
        return ErrorType.notFound;
      }
    }

    if (error is http.ClientException || error.toString().contains('SocketException')) {
      return ErrorType.network;
    }

    if (error is TimeoutException || error.toString().contains('TimeoutException')) {
      return ErrorType.timeout;
    }

    if (error is FormatException) {
      return ErrorType.validation;
    }

    return ErrorType.unknown;
  }

  /// 에러 로깅
  /// 
  /// Logger.error()를 사용하세요. 이 메서드는 하위 호환성을 위해 유지됩니다.
  static void logError(dynamic error, [StackTrace? stackTrace, String? context]) {
    Logger.error(
      '에러 발생',
      error: error,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// 안전한 에러 처리 래퍼
  /// 
  /// [operation] 실행할 비동기 작업
  /// [onError] 에러 발생 시 콜백 (옵션)
  /// [defaultErrorMessage] 기본 에러 메시지 (옵션)
  /// 
  /// 반환: 작업 결과 또는 null (에러 발생 시)
  static Future<T?> safeAsyncCall<T>({
    required Future<T> Function() operation,
    Function(String)? onError,
    String? defaultErrorMessage,
  }) async {
    try {
      return await operation();
    } catch (e, stackTrace) {
      final message = getUserFriendlyMessage(e, defaultMessage: defaultErrorMessage);
      logError(e, stackTrace);
      onError?.call(message);
      return null;
    }
  }

  /// 에러를 사용자에게 표시 (SnackBar)
  /// [error] 예외 객체 또는 에러 메시지 문자열
  /// [checkNetwork] 네트워크 상태를 확인할지 여부 (기본값: true)
  static Future<void> showError(
    BuildContext context,
    dynamic error, {
    String? defaultMessage,
    bool checkNetwork = true,
  }) async {
    String message;
    
    // String 타입인 경우 그대로 사용 (이미 사용자 친화적 메시지)
    if (error is String) {
      message = error;
    } else {
      message = getUserFriendlyMessage(error, defaultMessage: defaultMessage);
    }
    
    // 네트워크 오류인 경우 오프라인 상태 확인
    if (checkNetwork && 
        (message == ErrorMessages.network || 
         error.toString().toLowerCase().contains('network') ||
         error.toString().toLowerCase().contains('connection'))) {
      final isOffline = await NetworkStatus().isOffline();
      if (isOffline) {
        message = ErrorMessages.offline;
      }
    }
    
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}

