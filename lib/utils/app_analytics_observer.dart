import 'package:flutter/material.dart';
import '../api_request/log_service.dart';

/// 화면 전환을 자동으로 감지하여 LogService에 기록하는 Observer
class AppAnalyticsObserver extends RouteObserver<PageRoute<dynamic>> {
  final LogService _logService = LogService();

  void _logScreenView(PageRoute<dynamic> route) {
    final String screenName = route.settings.name ?? route.runtimeType.toString();
    
    // BottomSheet 등은 제외하거나 구분 가능
    // 'MaterialPageRoute' 같은 기본 이름만 있는 경우 제외하거나 실제 위젯 이름 추출 시도
    if (screenName == 'MaterialPageRoute<dynamic>' || screenName == '/') {
       // 필요한 경우 route.builder 등을 통해 위젯 이름을 유추할 수도 있으나 복잡함.
       // settings.name을 잘 활용하는 것이 좋음.
    }

    _logService.logScreenView(screenName);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _logScreenView(route);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute && route is PageRoute) {
      _logScreenView(previousRoute);
    }
  }
  
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _logScreenView(newRoute);
    }
  }
}

