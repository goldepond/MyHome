import 'package:property/api_request/log_service.dart';
import 'analytics_events.dart';

/// 간단한 퍼널/행동 로그 저장용 서비스.
/// 기존에는 직접 Firestore에 저장했으나, 이제 LogService로 통합됨.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final LogService _logService = LogService();

  Future<void> logEvent(
    String name, {
    Map<String, dynamic>? params,
    String? userId,
    String? userName,
    FunnelStage? stage,
  }) async {
    try {
      final sanitizedParams = _sanitizeParams(params ?? const {});
      
      // LogService를 통해 중앙 집중식 로깅
      _logService.log(
        actionType: 'analytics_event', // 또는 name에 따라 분류 가능
        target: name,
        metadata: {
          ...sanitizedParams,
          if (userName != null) 'userName': userName,
          if (stage != null) 'funnelStage': stage.key,
          'source': 'AnalyticsService',
        },
      );
    } catch (_) {
      // 실패 무시
    }
  }

  Map<String, dynamic> _sanitizeParams(Map<String, dynamic> source) {
    final Map<String, dynamic> result = {};
    source.forEach((key, value) {
      if (value == null) {
        return;
      }
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is num || value is String || value is bool) {
        result[key] = value;
      } else if (value is Map<String, dynamic>) {
        result[key] = _sanitizeParams(value);
      } else if (value is Iterable) {
        result[key] = value
            .map((item) => item is DateTime ? item.toIso8601String() : item.toString())
            .toList();
      } else {
        result[key] = value.toString();
      }
    });
    return result;
  }
}
