import 'package:flutter/foundation.dart' show kDebugMode;

/// 보안 관련 유틸리티
class SecurityUtils {
  /// API 키를 마스킹하여 로그에 안전하게 출력
  /// 
  /// [apiKey] 마스킹할 API 키
  /// [visibleChars] 앞뒤로 보여줄 문자 수 (기본값: 4)
  /// 
  /// 예: "ABCD1234EFGH5678" -> "ABCD...5678"
  static String maskApiKey(String apiKey, {int visibleChars = 4}) {
    if (apiKey.isEmpty) {
      return '[EMPTY]';
    }
    
    if (apiKey.length <= visibleChars * 2) {
      return '***';
    }
    
    final prefix = apiKey.substring(0, visibleChars);
    final suffix = apiKey.substring(apiKey.length - visibleChars);
    return '$prefix...$suffix';
  }
  
  /// 이메일을 마스킹하여 로그에 안전하게 출력
  /// 
  /// [email] 마스킹할 이메일
  /// 
  /// 예: "user@example.com" -> "u***@example.com"
  static String maskEmail(String email) {
    if (email.isEmpty || !email.contains('@')) {
      return email;
    }
    
    final parts = email.split('@');
    if (parts.length != 2) {
      return email;
    }
    
    final localPart = parts[0];
    final domain = parts[1];
    
    if (localPart.length <= 1) {
      return '***@$domain';
    }
    
    final maskedLocal = '${localPart[0]}***';
    return '$maskedLocal@$domain';
  }
  
  /// 전화번호를 마스킹하여 로그에 안전하게 출력
  /// 
  /// [phone] 마스킹할 전화번호
  /// 
  /// 예: "010-1234-5678" -> "010-****-5678"
  static String maskPhone(String phone) {
    if (phone.isEmpty) {
      return phone;
    }
    
    // 하이픈이 있는 경우
    if (phone.contains('-')) {
      final parts = phone.split('-');
      if (parts.length == 3) {
        return '${parts[0]}-****-${parts[2]}';
      }
    }
    
    // 하이픈이 없는 경우 (예: 01012345678)
    if (phone.length >= 7) {
      final prefix = phone.substring(0, 3);
      final suffix = phone.substring(phone.length - 4);
      return '$prefix****$suffix';
    }
    
    return '***';
  }
  
  /// 사용자 ID를 마스킹하여 로그에 안전하게 출력
  /// 
  /// [userId] 마스킹할 사용자 ID
  /// 
  /// 예: "user123456789" -> "user***789"
  static String maskUserId(String userId) {
    if (userId.isEmpty) {
      return '[EMPTY]';
    }
    
    if (userId.length <= 6) {
      return '***';
    }
    
    final prefix = userId.substring(0, 4);
    final suffix = userId.substring(userId.length - 3);
    return '$prefix***$suffix';
  }
  
  /// 민감한 정보가 포함된 문자열을 검사하고 마스킹
  /// 
  /// [text] 검사할 문자열
  /// [sensitivePatterns] 민감한 패턴 목록
  /// 
  /// API 키, 이메일, 전화번호 등이 포함되어 있으면 마스킹
  static String sanitizeForLogging(String text, {
    List<RegExp>? sensitivePatterns,
  }) {
    if (text.isEmpty) {
      return text;
    }
    
    // 기본 민감한 패턴
    final defaultPatterns = [
      // API 키 패턴 (Base64, UUID 등)
      RegExp(r'[A-Za-z0-9+/=]{20,}'),
      // 이메일
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      // 전화번호
      RegExp(r'\d{2,3}-\d{3,4}-\d{4}'),
      RegExp(r'\d{10,11}'),
    ];
    
    final patterns = sensitivePatterns ?? defaultPatterns;
    String sanitized = text;
    
    for (final pattern in patterns) {
      sanitized = sanitized.replaceAllMapped(pattern, (match) {
        return '***[REDACTED]***';
      });
    }
    
    return sanitized;
  }
  
  /// 프로덕션 모드에서 민감한 정보 로깅 방지
  /// 
  /// [value] 로깅할 값
  /// [maskFunction] 마스킹 함수 (옵션)
  /// 
  /// 프로덕션 모드에서는 항상 마스킹된 값만 반환
  static String safeLogValue(String value, String Function(String)? maskFunction) {
    if (kDebugMode) {
      // 개발 모드에서는 마스킹 함수가 있으면 사용, 없으면 원본 반환
      return maskFunction != null ? maskFunction(value) : value;
    } else {
      // 프로덕션 모드에서는 항상 마스킹
      return maskFunction != null 
          ? maskFunction(value) 
          : sanitizeForLogging(value);
    }
  }
  
  /// URL에서 쿼리 파라미터의 민감한 정보 제거
  /// 
  /// [url] 처리할 URL
  /// [sensitiveParams] 민감한 파라미터 이름 목록
  /// 
  /// 예: "https://api.example.com?key=secret123" -> "https://api.example.com?key=***"
  static String sanitizeUrl(String url, {List<String>? sensitiveParams}) {
    try {
      final uri = Uri.parse(url);
      final defaultSensitiveParams = [
        'key', 'apiKey', 'apikey', 'api_key',
        'token', 'access_token', 'accessToken',
        'secret', 'password', 'pwd',
        'auth', 'authorization',
      ];
      
      final paramsToMask = sensitiveParams ?? defaultSensitiveParams;
      final queryParams = Map<String, String>.from(uri.queryParameters);
      
      for (final param in paramsToMask) {
        if (queryParams.containsKey(param)) {
          queryParams[param] = '***';
        }
      }
      
      return uri.replace(queryParameters: queryParams).toString();
    } catch (e) {
      // URL 파싱 실패 시 원본 반환
      return url;
    }
  }
}

