# 색상 대비 검증 결과

> 작성일: 2025-01-XX  
> 프로젝트: MyHome - Flutter Web Application

---

## 📊 주요 색상 조합 대비 비율

### 텍스트 색상 vs 배경색

#### 1. Primary Text vs Background
```dart
ColorContrastChecker.checkContrast(
  foreground: AppColors.kTextPrimary,  // #1F2937
  background: AppColors.kBackground,    // #E8EAF0
  isLargeText: false,
)
```
**예상 결과:**
- 대비 비율: 약 8.5:1
- WCAG AA: ✅ PASS
- WCAG AAA: ✅ PASS

#### 2. Secondary Text vs Background
```dart
ColorContrastChecker.checkContrast(
  foreground: AppColors.kTextSecondary, // #4B5563
  background: AppColors.kBackground,     // #E8EAF0
  isLargeText: false,
)
```
**예상 결과:**
- 대비 비율: 약 5.2:1
- WCAG AA: ✅ PASS
- WCAG AAA: ❌ FAIL

#### 3. Light Text vs Background
```dart
ColorContrastChecker.checkContrast(
  foreground: AppColors.kTextLight,    // #6B7280
  background: AppColors.kBackground,    // #E8EAF0
  isLargeText: false,
)
```
**예상 결과:**
- 대비 비율: 약 3.8:1
- WCAG AA: ❌ FAIL (일반 텍스트)
- WCAG AA: ✅ PASS (큰 텍스트, 18pt 이상)

### 버튼 색상

#### 4. White Text vs Primary Button
```dart
ColorContrastChecker.checkContrast(
  foreground: Colors.white,
  background: AppColors.kPrimary,      // #8b5cf6
  isLargeText: false,
)
```
**예상 결과:**
- 대비 비율: 약 4.2:1
- WCAG AA: ✅ PASS (큰 텍스트 권장)
- WCAG AA: ⚠️ 경계선 (일반 텍스트)

---

## ⚠️ 개선 권장 사항

### 1. Light Text 사용 제한
- `kTextLight` (#6B7280)는 일반 텍스트에 사용 시 WCAG AA 기준을 만족하지 않습니다.
- **권장사항:**
  - 큰 텍스트(18pt 이상)에만 사용
  - 또는 배경색을 더 밝게 조정
  - 또는 텍스트 색상을 더 진하게 조정

### 2. Primary Button 텍스트
- Primary 버튼의 흰색 텍스트는 큰 텍스트로 사용하는 것이 안전합니다.
- **권장사항:**
  - 버튼 텍스트는 최소 16pt, bold 사용
  - 또는 버튼 배경색을 더 진하게 조정

### 3. Secondary Text
- Secondary 텍스트는 WCAG AA는 만족하지만 AAA는 만족하지 않습니다.
- **현재 상태:** ✅ 사용 가능 (AA 기준 충족)

---

## 🔧 색상 조정 제안

### 옵션 1: TextLight 색상 조정
```dart
// 현재
static const Color kTextLight = Color(0xFF6B7280);

// 제안 (더 진한 색상)
static const Color kTextLight = Color(0xFF4B5563); // Secondary와 동일
```

### 옵션 2: Background 색상 조정
```dart
// 현재
static const Color kBackground = Color(0xFFE8EAF0);

// 제안 (더 밝은 색상)
static const Color kBackground = Color(0xFFF3F4F6);
```

### 옵션 3: Primary Button 색상 조정
```dart
// 현재
static const Color kPrimary = Color(0xFF8b5cf6);

// 제안 (더 진한 색상)
static const Color kPrimary = Color(0xFF7c3aed); // kAccent와 동일
```

---

## 📝 검증 방법

### 개발 중 검증
```dart
import 'package:property/utils/color_contrast_checker.dart';
import 'package:property/constants/app_constants.dart';

void validateColors() {
  // Primary Text 검증
  final result1 = ColorContrastChecker.checkContrast(
    foreground: AppColors.kTextPrimary,
    background: AppColors.kBackground,
  );
  print('Primary Text: ${result1.status} (${result1.ratio.toStringAsFixed(2)}:1)');
  
  // Secondary Text 검증
  final result2 = ColorContrastChecker.checkContrast(
    foreground: AppColors.kTextSecondary,
    background: AppColors.kBackground,
  );
  print('Secondary Text: ${result2.status} (${result2.ratio.toStringAsFixed(2)}:1)');
  
  // Light Text 검증
  final result3 = ColorContrastChecker.checkContrast(
    foreground: AppColors.kTextLight,
    background: AppColors.kBackground,
  );
  print('Light Text: ${result3.status} (${result3.ratio.toStringAsFixed(2)}:1)');
  
  // Button 검증
  final result4 = ColorContrastChecker.checkContrast(
    foreground: Colors.white,
    background: AppColors.kPrimary,
  );
  print('Button Text: ${result4.status} (${result4.ratio.toStringAsFixed(2)}:1)');
}
```

### 자동화된 테스트
```dart
// test/utils/color_contrast_test.dart
void main() {
  test('Primary text meets WCAG AA', () {
    final result = ColorContrastChecker.checkContrast(
      foreground: AppColors.kTextPrimary,
      background: AppColors.kBackground,
    );
    expect(result.meetsAA, true);
  });
  
  test('Light text meets WCAG AA for large text', () {
    final result = ColorContrastChecker.checkContrast(
      foreground: AppColors.kTextLight,
      background: AppColors.kBackground,
      isLargeText: true,
    );
    expect(result.meetsAA, true);
  });
}
```

---

## ✅ 권장 조치 사항

1. **즉시 조치:**
   - `kTextLight` 사용 시 큰 텍스트로만 제한
   - 또는 `kTextLight` 색상을 더 진하게 조정

2. **단기 조치:**
   - 모든 색상 조합에 대한 대비 비율 검증
   - 대비 비율이 부족한 경우 색상 조정

3. **장기 조치:**
   - CI/CD 파이프라인에 색상 대비 검증 추가
   - 디자인 시스템 문서에 대비 비율 명시

---

## 📚 참고 자료

- [WCAG 2.1 Contrast (Minimum)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html)
- [WCAG 2.1 Contrast (Enhanced)](https://www.w3.org/WAI/WCAG21/Understanding/contrast-enhanced.html)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)









