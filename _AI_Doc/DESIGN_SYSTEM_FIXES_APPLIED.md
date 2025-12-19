# 디자인 시스템 에러 수정 완료

> 작성일: 2025-01-XX  
> 프로젝트: MyHome - Flutter Web Application

---

## 🔧 수정된 에러 유형

### 1. `withColor` 메서드 호출 오류
**문제:**
```dart
// ❌ 잘못된 호출
style: AppTypography.withColor(
  AppTypography.bodySmall,
  fontWeight: FontWeight.w600,  // 잘못된 파라미터
  color: AirbnbColors.primary,  // 잘못된 파라미터
)

// ✅ 올바른 호출
style: AppTypography.withColor(
  AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
  AirbnbColors.primary,
)
```

**수정:**
- `withColor`는 2개의 positional argument를 받음: `(TextStyle style, Color color)`
- `copyWith`를 먼저 호출하여 스타일을 수정한 후 `withColor`로 색상 적용

---

### 2. `const` 표현식에서 메서드 호출 오류
**문제:**
```dart
// ❌ 잘못된 사용
const Text(
  '텍스트',
  style: AppTypography.withColor(...),  // const에서 메서드 호출 불가
)

// ✅ 올바른 사용
Text(
  '텍스트',
  style: AppTypography.withColor(...),  // const 제거
)
```

**수정:**
- 메서드 호출이 있는 경우 `const` 키워드 제거
- `AppTypography.withColor`, `AppTypography.copyWith` 등 메서드 호출 시 `const` 제거

---

### 3. 잘못된 `TextStyle` 패턴
**문제:**
```dart
// ❌ 잘못된 패턴
style: TextStyle(
  style: AppTypography.bodySmall,  // style 파라미터가 아님
  fontWeight: FontWeight.w600,
  color: AirbnbColors.primary,
)

// ✅ 올바른 패턴
style: AppTypography.withColor(
  AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
  AirbnbColors.primary,
)
```

**수정:**
- `TextStyle(style: ...)` 패턴을 모두 제거
- `AppTypography.withColor` 또는 `AppTypography.copyWith` 직접 사용

---

### 4. Import 누락
**문제:**
- `quote_history_page.dart`에 `AppTypography`, `AppSpacing`, `ResponsiveHelper` import 누락

**수정:**
```dart
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/responsive_constants.dart';
```

---

## 📋 수정된 파일 목록

1. ✅ `broker_list_page.dart`
   - `withColor` 호출 방식 수정
   - `const` 키워드 제거
   - 잘못된 `TextStyle` 패턴 수정

2. ✅ `home_page.dart`
   - `const` 키워드 제거
   - 잘못된 `TextStyle` 패턴 수정

3. ✅ `main_page.dart`
   - `withColor` 호출 방식 수정
   - `const` 키워드 제거

4. ✅ `quote_history_page.dart`
   - Import 추가
   - `const` 키워드 제거
   - 잘못된 `TextStyle` 패턴 수정
   - `withColor` 호출 방식 수정

5. ✅ `house_management_page.dart`
   - `const` 키워드 제거
   - 잘못된 `TextStyle` 패턴 수정
   - `withColor` 호출 방식 수정

6. ✅ `quote_comparison_page.dart`
   - `const` 키워드 제거
   - 잘못된 `TextStyle` 패턴 수정

---

## ✅ 수정 완료

모든 컴파일 에러가 수정되었습니다. 이제 프로젝트가 정상적으로 빌드될 것입니다.

---

*이 문서는 디자인 시스템 개선 과정에서 발생한 컴파일 에러 수정 내역을 기록합니다.*







