import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:property/utils/logger.dart';

/// 네트워크 연결 상태 관리 유틸리티
class NetworkStatus {
  static final NetworkStatus _instance = NetworkStatus._internal();
  factory NetworkStatus() => _instance;
  NetworkStatus._internal();

  bool? _isOnline;
  DateTime? _lastCheckTime;
  static const Duration _cacheDuration = Duration(seconds: 30);
  // 모바일에서 사용할 테스트 URL (웹에서는 CORS로 사용 불가)
  static const String _testUrl = 'https://www.google.com';
  static const Duration _testTimeout = Duration(seconds: 3);

  /// 네트워크 연결 상태 확인 (캐시된 결과 반환)
  ///
  /// [forceCheck] true이면 캐시 무시하고 새로 확인
  /// Returns true if online, false if offline, null if unknown
  Future<bool?> isOnline({bool forceCheck = false}) async {
    // 웹에서는 CORS로 인해 외부 URL 체크 불가
    // 웹 앱이 로드되었다면 인터넷이 연결된 것으로 간주
    if (kIsWeb) {
      _isOnline = true;
      _lastCheckTime = DateTime.now();
      return true;
    }

    // 캐시된 결과가 있고 최근에 확인했으면 캐시 반환
    if (!forceCheck &&
        _isOnline != null &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < _cacheDuration) {
      return _isOnline;
    }

    // 모바일: 실제 네트워크 상태 확인
    try {
      final response = await http
          .get(Uri.parse(_testUrl))
          .timeout(_testTimeout);

      _isOnline = response.statusCode == 200;
      _lastCheckTime = DateTime.now();

      return _isOnline;
    } catch (e) {
      // 네트워크 오류는 오프라인으로 간주
      _isOnline = false;
      _lastCheckTime = DateTime.now();

      if (kDebugMode) {
        Logger.warning('네트워크 상태 확인 실패: $e');
      }

      return false;
    }
  }

  /// 네트워크 연결 상태 확인 (강제)
  Future<bool> checkOnlineStatus() async {
    final result = await isOnline(forceCheck: true);
    return result ?? false;
  }

  /// 캐시 초기화
  void clearCache() {
    _isOnline = null;
    _lastCheckTime = null;
  }

  /// 오프라인 상태인지 확인
  Future<bool> isOffline() async {
    final online = await isOnline();
    return online == false;
  }
}

