import 'package:flutter/material.dart';

/// Apple 디자인 시스템
///
/// 애플의 3대 핵심 철학을 구현:
/// - Clarity (명확성): 읽기 쉬운 텍스트, 직관적 아이콘, 충분한 여백
/// - Deference (경외감): UI가 콘텐츠를 가리지 않고 뒤로 물러남
/// - Depth (깊이감): 레이어와 계층 구조로 위치/흐름 설명

class AppleColors {
  AppleColors._();

  // ========== 시스템 색상 (MyHome 브랜드 + iOS 표준) ==========

  /// MyHome Coral - 주요 액션, 링크, 선택 상태 (브랜드 색상)
  static const Color systemBlue = Color(0xFFE07A5F);

  /// Apple Green - 성공, 완료, 활성 상태
  static const Color systemGreen = Color(0xFF34C759);

  /// Apple Indigo - 보조 액션, 정보
  static const Color systemIndigo = Color(0xFF5856D6);

  /// Apple Orange - 경고, 진행 중
  static const Color systemOrange = Color(0xFFFF9500);

  /// Apple Pink - 강조, 특별 상태
  static const Color systemPink = Color(0xFFFF2D55);

  /// Apple Purple - 프리미엄, 특별 기능
  static const Color systemPurple = Color(0xFFAF52DE);

  /// Apple Red - 에러, 위험, 삭제
  static const Color systemRed = Color(0xFFFF3B30);

  /// Apple Teal - 보조 정보
  static const Color systemTeal = Color(0xFF5AC8FA);

  /// Apple Yellow - 주의, 알림
  static const Color systemYellow = Color(0xFFFFCC00);

  // ========== 그레이 스케일 (Light Mode) ==========

  /// 주요 텍스트
  static const Color label = Color(0xFF000000);

  /// 보조 텍스트
  static const Color secondaryLabel = Color(0x99000000); // 60% opacity

  /// 3차 텍스트
  static const Color tertiaryLabel = Color(0x4D000000); // 30% opacity

  /// 비활성 텍스트
  static const Color quaternaryLabel = Color(0x33000000); // 20% opacity

  // ========== 배경 색상 (Light Mode) ==========

  /// 시스템 배경 (최상위)
  static const Color systemBackground = Color(0xFFFFFFFF);

  /// 보조 배경 (컨테이너, 카드)
  static const Color secondarySystemBackground = Color(0xFFF2F2F7);

  /// 3차 배경 (중첩된 컨테이너)
  static const Color tertiarySystemBackground = Color(0xFFFFFFFF);

  // ========== 그룹화된 배경 (Light Mode) ==========

  /// 그룹화된 시스템 배경 (리스트 뷰)
  static const Color systemGroupedBackground = Color(0xFFF2F2F7);

  /// 그룹화된 보조 배경 (리스트 아이템)
  static const Color secondarySystemGroupedBackground = Color(0xFFFFFFFF);

  /// 그룹화된 3차 배경
  static const Color tertiarySystemGroupedBackground = Color(0xFFF2F2F7);

  // ========== 구분선/테두리 ==========

  /// 불투명 구분선
  static const Color separator = Color(0x49000000); // ~29% opacity

  /// 투명 구분선 (블러 배경용)
  static const Color opaqueSeparator = Color(0xFFC6C6C8);

  // ========== 채우기 색상 (UI 요소용) ==========

  static const Color systemFill = Color(0x33787880); // 20% opacity
  static const Color secondarySystemFill = Color(0x28787880); // 16% opacity
  static const Color tertiarySystemFill = Color(0x1E787880); // 12% opacity
  static const Color quaternarySystemFill = Color(0x14787880); // 8% opacity
}

class AppleTypography {
  AppleTypography._();

  // ========== SF Pro Display (Large Titles) ==========

  /// 대형 타이틀 (34pt, Bold)
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    height: 1.21, // 41pt line height
    color: AppleColors.label,
  );

  // ========== SF Pro Text (Titles & Body) ==========

  /// Title 1 (28pt, Regular)
  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.36,
    height: 1.21, // 34pt line height
    color: AppleColors.label,
  );

  /// Title 2 (22pt, Regular)
  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.35,
    height: 1.27, // 28pt line height
    color: AppleColors.label,
  );

  /// Title 3 (20pt, Regular)
  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.38,
    height: 1.25, // 25pt line height
    color: AppleColors.label,
  );

  /// Headline (17pt, Semibold)
  static const TextStyle headline = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.29, // 22pt line height
    color: AppleColors.label,
  );

  /// Body (17pt, Regular)
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.41,
    height: 1.29, // 22pt line height
    color: AppleColors.label,
  );

  /// Callout (16pt, Regular)
  static const TextStyle callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    height: 1.31, // 21pt line height
    color: AppleColors.label,
  );

  /// Subheadline (15pt, Regular)
  static const TextStyle subheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.33, // 20pt line height
    color: AppleColors.label,
  );

  /// Footnote (13pt, Regular)
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.38, // 18pt line height
    color: AppleColors.label,
  );

  /// Caption 1 (12pt, Regular)
  static const TextStyle caption1 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33, // 16pt line height
    color: AppleColors.label,
  );

  /// Caption 2 (11pt, Regular)
  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.07,
    height: 1.27, // 14pt line height
    color: AppleColors.label,
  );
}

class AppleSpacing {
  AppleSpacing._();

  /// 최소 간격 (4pt)
  static const double xxs = 4.0;

  /// 아주 작은 간격 (8pt)
  static const double xs = 8.0;

  /// 작은 간격 (12pt)
  static const double sm = 12.0;

  /// 중간 간격 (16pt)
  static const double md = 16.0;

  /// 큰 간격 (20pt)
  static const double lg = 20.0;

  /// 아주 큰 간격 (24pt)
  static const double xl = 24.0;

  /// 최대 간격 (32pt)
  static const double xxl = 32.0;

  /// 섹션 간격 (40pt)
  static const double section = 40.0;
}

class AppleRadius {
  AppleRadius._();

  /// 아주 작은 라운드 (4pt)
  static const double xs = 4.0;

  /// 작은 라운드 (8pt)
  static const double sm = 8.0;

  /// 중간 라운드 (12pt)
  static const double md = 12.0;

  /// 큰 라운드 (16pt)
  static const double lg = 16.0;

  /// 아주 큰 라운드 (20pt)
  static const double xl = 20.0;

  /// 완전 라운드 - 필(pill) 모양 버튼용 (100pt)
  static const double full = 100.0;
}

class AppleShadows {
  AppleShadows._();

  /// 미세한 그림자 (떠있는 느낌)
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: AppleColors.label.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  /// 일반 그림자 (카드)
  static List<BoxShadow> get card => [
    BoxShadow(
      color: AppleColors.label.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  /// 강한 그림자 (모달, 팝업)
  static List<BoxShadow> get strong => [
    BoxShadow(
      color: AppleColors.label.withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
}

/// Apple 스타일 버튼
class AppleButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isSecondary;
  final bool isSmall;

  const AppleButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isSecondary = false,
    this.isSmall = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (isSecondary ? AppleColors.secondarySystemBackground : AppleColors.systemBlue);
    final fgColor = textColor ??
        (isSecondary ? AppleColors.label : Colors.white);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppleRadius.md),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? AppleSpacing.md : AppleSpacing.lg,
            vertical: isSmall ? AppleSpacing.xs : AppleSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppleRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: isSmall ? 16 : 20, color: fgColor),
                SizedBox(width: AppleSpacing.xs),
              ],
              Text(
                text,
                style: (isSmall ? AppleTypography.subheadline : AppleTypography.body).copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apple 스타일 카드
class AppleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool hasShadow;

  const AppleCard({
    Key? key,
    required this.child,
    this.onTap,
    this.padding,
    this.hasShadow = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppleColors.secondarySystemGroupedBackground,
      borderRadius: BorderRadius.circular(AppleRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppleRadius.lg),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppleSpacing.md),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppleRadius.lg),
            border: Border.all(
              color: AppleColors.separator.withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: hasShadow ? AppleShadows.subtle : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 반응형 그리드 컬럼 계산
class AppleResponsive {
  AppleResponsive._();

  /// 화면 너비에 따른 그리드 컬럼 수
  static int getGridColumns(double width) {
    if (width > 1200) return 4; // Desktop
    if (width > 800) return 3;  // Tablet landscape
    if (width > 600) return 2;  // Tablet portrait
    return 1;                    // Mobile
  }

  /// 최대 콘텐츠 너비 (읽기 최적화)
  static double getMaxContentWidth(double screenWidth) {
    if (screenWidth > 1200) return 1200;
    return screenWidth;
  }

  /// 모바일 여부
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// 태블릿 여부
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// 데스크톱 여부
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }
}
