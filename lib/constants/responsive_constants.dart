import 'package:flutter/material.dart';

/// 반응형 디자인을 위한 브레이크포인트 상수
/// 모든 화면에서 일관된 반응형 기준을 사용하기 위한 표준 정의
class ResponsiveBreakpoints {
  /// 모바일 최대 너비 (600px 미만)
  static const double mobile = 600;
  
  /// 태블릿 최대 너비 (600px ~ 900px)
  static const double tablet = 900;
  
  /// 데스크톱 최대 너비 (900px ~ 1200px)
  static const double desktop = 1200;
  
  /// 대형 데스크톱 최소 너비 (1200px 이상)
  static const double largeDesktop = 1200;
}

/// 반응형 디자인 헬퍼 클래스
/// 화면 크기에 따른 레이아웃 결정을 위한 유틸리티
class ResponsiveHelper {
  /// 모바일 화면 여부 확인 (600px 미만)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobile;
  }
  
  /// 태블릿 화면 여부 확인 (600px ~ 900px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobile && 
           width < ResponsiveBreakpoints.tablet;
  }
  
  /// 데스크톱 화면 여부 확인 (900px ~ 1200px)
  static bool isDesktop(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.tablet && 
           width < ResponsiveBreakpoints.desktop;
  }
  
  /// 대형 데스크톱 화면 여부 확인 (1200px 이상)
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktop;
  }
  
  /// 웹 환경 여부 확인 (800px 이상 - 기존 코드와 호환)
  static bool isWeb(BuildContext context) {
    return MediaQuery.of(context).size.width > 800;
  }
  
  /// 화면 크기에 따른 최대 너비 반환
  /// 웹 환경에서 가독성을 위한 최대 너비 제한
  static double getMaxWidth(BuildContext context) {
    if (isLargeDesktop(context)) return 1600;
    if (isDesktop(context)) return 1400;
    if (isTablet(context)) return 900;
    return double.infinity;
  }
  
  /// 화면 크기에 따른 수평 패딩 반환
  static double getHorizontalPadding(BuildContext context) {
    if (isMobile(context)) return 12.0;
    if (isTablet(context)) return 16.0;
    if (isDesktop(context)) return 32.0;
    return 48.0; // largeDesktop
  }
  
  /// 화면 크기에 따른 카드 간격 반환
  static double getCardSpacing(BuildContext context) {
    if (isMobile(context)) return 12.0;
    if (isTablet(context)) return 16.0;
    if (isDesktop(context)) return 20.0;
    return 24.0; // largeDesktop
  }
  
  /// 그리드 컬럼 수 반환
  static int getGridColumns(BuildContext context) {
    if (isMobile(context)) return 1;
    if (isTablet(context)) return 2;
    if (isDesktop(context)) return 2;
    return 3; // largeDesktop
  }
}











