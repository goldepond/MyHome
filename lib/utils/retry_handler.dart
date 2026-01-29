import 'dart:async';
import 'dart:math';
import 'package:property/utils/logger.dart';

/// 재시도 설정
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool Function(Object)? shouldRetry;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.shouldRetry,
  });
}

/// 네트워크 재시도 유틸리티
class RetryHandler {
  /// 지수 백오프를 사용한 재시도
  /// 
  /// [operation] 실행할 비동기 작업
  /// [config] 재시도 설정
  /// 
  /// 예외가 발생하면 자동으로 재시도하며, 최대 시도 횟수에 도달하면 마지막 예외를 던집니다.
  static Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    RetryConfig config = const RetryConfig(),
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;
    
    while (attempt < config.maxAttempts) {
      try {
        return await operation();
      } catch (e, stackTrace) {
        attempt++;
        
        // 재시도 여부 확인
        if (config.shouldRetry != null && !config.shouldRetry!(e)) {
          Logger.warning('재시도하지 않음 (shouldRetry=false)', metadata: {
            'error': e.toString(),
            'attempt': attempt,
          });
          rethrow;
        }
        
        // 마지막 시도인 경우 예외를 던짐
        if (attempt >= config.maxAttempts) {
          Logger.error(
            '재시도 실패: 최대 시도 횟수 도달',
            error: e,
            stackTrace: stackTrace,
            metadata: {
              'maxAttempts': config.maxAttempts,
              'finalAttempt': attempt,
            },
          );
          rethrow;
        }
        
        // 지수 백오프로 대기 시간 계산
        final jitter = Duration(
          milliseconds: Random().nextInt(500), // 0-500ms 랜덤 지터 추가
        );
        final totalDelay = Duration(
          milliseconds: (delay.inMilliseconds * config.backoffMultiplier).round(),
        ) + jitter;
        
        // 최대 지연 시간 제한
        final finalDelay = totalDelay > config.maxDelay 
            ? config.maxDelay 
            : totalDelay;
        
        Logger.warning('재시도 대기 중', metadata: {
          'attempt': attempt,
          'maxAttempts': config.maxAttempts,
          'delayMs': finalDelay.inMilliseconds,
          'error': e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length),
        });
        
        await Future.delayed(finalDelay);
        delay = finalDelay;
      }
    }
    
    // 이 코드는 도달하지 않지만 컴파일러를 위해 필요
    throw StateError('재시도 로직 오류');
  }
  
  /// 네트워크 오류에 대한 기본 재시도 설정
  static RetryConfig get networkRetryConfig => const RetryConfig(
    maxDelay: Duration(seconds: 10),
    shouldRetry: _isNetworkError,
  );
  
  /// 네트워크 오류인지 확인
  static bool _isNetworkError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
        errorString.contains('timeoutexception') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('unavailable') ||
        errorString.contains('failed host lookup');
  }
  
  /// 서버 오류에 대한 재시도 설정 (5xx 에러)
  static RetryConfig get serverRetryConfig => const RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 15),
    shouldRetry: _isServerError,
  );
  
  /// 서버 오류인지 확인
  static bool _isServerError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504') ||
        errorString.contains('server error');
  }
}

