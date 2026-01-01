import 'package:flutter/material.dart';

/// 색상 대비 비율 검증 도구
/// WCAG 2.1 AA 기준 준수 여부를 확인
class ColorContrastChecker {
  /// 상대 휘도 계산 (0.0 ~ 1.0)
  /// WCAG 2.1 표준에 따른 상대 휘도 계산
  static double _getRelativeLuminance(Color color) {
    final r = _linearize(color.r / 255.0);
    final g = _linearize(color.g / 255.0);
    final b = _linearize(color.b / 255.0);
    
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
  
  /// 색상 값을 선형화
  static double _linearize(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    }
    // 2.4 제곱 계산: (value + 0.055) / 1.055의 2.4제곱
    final ratio = (value + 0.055) / 1.055;
    return _pow24(ratio);
  }
  
  /// 2.4 제곱 계산 (근사)
  static double _pow24(double value) {
    if (value <= 0) return 0;
    // 2.4 = 2 + 0.4이므로, value^2 * value^0.4로 근사
    final squared = value * value;
    // value^0.4 = (value^2)^0.2 근사
    final sqrt = _sqrt(value);
    final fourthRoot = _sqrt(sqrt);
    return squared * fourthRoot;
  }
  
  /// 제곱근 계산 (뉴턴 방법)
  static double _sqrt(double value) {
    if (value <= 0) return 0;
    if (value == 1) return 1;
    double guess = value / 2;
    for (int i = 0; i < 20; i++) {
      final newGuess = (guess + value / guess) / 2;
      if ((newGuess - guess).abs() < 0.0001) break;
      guess = newGuess;
    }
    return guess;
  }
  
  /// 두 색상 간의 대비 비율 계산
  /// 반환값: 대비 비율 (예: 4.5, 7.0 등)
  static double getContrastRatio(Color color1, Color color2) {
    final l1 = _getRelativeLuminance(color1);
    final l2 = _getRelativeLuminance(color2);
    
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    
    return (lighter + 0.05) / (darker + 0.05);
  }
  
  /// WCAG 2.1 AA 기준 충족 여부 확인
  /// 일반 텍스트: 4.5:1 이상
  /// 큰 텍스트 (18pt 이상 또는 14pt bold 이상): 3:1 이상
  static bool meetsWCAGAA({
    required Color foreground,
    required Color background,
    bool isLargeText = false,
  }) {
    final ratio = getContrastRatio(foreground, background);
    return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
  }
  
  /// WCAG 2.1 AAA 기준 충족 여부 확인
  /// 일반 텍스트: 7:1 이상
  /// 큰 텍스트: 4.5:1 이상
  static bool meetsWCAGAAA({
    required Color foreground,
    required Color background,
    bool isLargeText = false,
  }) {
    final ratio = getContrastRatio(foreground, background);
    return isLargeText ? ratio >= 4.5 : ratio >= 7.0;
  }
  
  /// 색상 대비 검증 결과 반환
  static ContrastResult checkContrast({
    required Color foreground,
    required Color background,
    bool isLargeText = false,
  }) {
    final ratio = getContrastRatio(foreground, background);
    final meetsAA = meetsWCAGAA(
      foreground: foreground,
      background: background,
      isLargeText: isLargeText,
    );
    final meetsAAA = meetsWCAGAAA(
      foreground: foreground,
      background: background,
      isLargeText: isLargeText,
    );
    
    return ContrastResult(
      ratio: ratio,
      meetsAA: meetsAA,
      meetsAAA: meetsAAA,
      foreground: foreground,
      background: background,
      isLargeText: isLargeText,
    );
  }
}

/// 대비 검증 결과
class ContrastResult {
  final double ratio;
  final bool meetsAA;
  final bool meetsAAA;
  final Color foreground;
  final Color background;
  final bool isLargeText;
  
  ContrastResult({
    required this.ratio,
    required this.meetsAA,
    required this.meetsAAA,
    required this.foreground,
    required this.background,
    required this.isLargeText,
  });
  
  String get status {
    if (meetsAAA) return 'AAA';
    if (meetsAA) return 'AA';
    return 'FAIL';
  }
  
  @override
  String toString() {
    return 'Contrast Ratio: ${ratio.toStringAsFixed(2)}:1\n'
           'WCAG AA: ${meetsAA ? "PASS" : "FAIL"}\n'
           'WCAG AAA: ${meetsAAA ? "PASS" : "FAIL"}';
  }
}


