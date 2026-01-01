import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 도로명 주소 검색 결과 리스트 위젯
class RoadAddressList extends StatelessWidget {
  final List<Map<String, String>> fullAddrAPIDatas;
  final List<String> addresses;
  final String selectedAddress;
  final void Function(Map<String, String>, String) onSelect;

  const RoadAddressList({
    required this.fullAddrAPIDatas,
    required this.addresses,
    required this.selectedAddress,
    required this.onSelect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final horizontalMargin = isMobile ? 16.0 : 40.0;
    final itemPadding = isMobile ? 14.0 : 12.0;
    final fontSize = isMobile ? 17.0 : 15.0;
    // 18pt 이상인 경우 배경 사용, 미만인 경우 테두리/아이콘 강조
    final isLargeText = fontSize >= 18.0;

    List<Widget> listItems = [];
    for (int i = 0; i < addresses.length; i++) {
      final addr = addresses[i];
      final fullData = fullAddrAPIDatas[i];
      final isSelected = selectedAddress.trim() == addr.trim();

      // 선택된 항목의 스타일 결정: 큰 텍스트는 배경, 작은 텍스트는 테두리/아이콘 강조
      final selectedBackgroundColor = isSelected && isLargeText
          ? AirbnbColors.primaryDark // 18pt 이상: 더 진한 보라색 배경
          : (isSelected && !isLargeText
              ? AirbnbColors.primaryDark.withValues(alpha: 0.08) // 18pt 미만: 연한 배경
              : AirbnbColors.background);
      final selectedBorderColor = isSelected
          ? AirbnbColors.primaryDark // 선택된 항목: 더 진한 보라색 테두리
          : AirbnbColors.border;
      final selectedBorderWidth =
          isSelected ? (isLargeText ? 1.0 : 2.0) : 1.0; // 작은 텍스트는 테두리 두껍게
      final selectedTextColor = isSelected && isLargeText
          ? AirbnbColors.background // 큰 텍스트: 흰색
          : (isSelected && !isLargeText
              ? AirbnbColors.primaryDark // 작은 텍스트: 보라색
              : AirbnbColors.textPrimary);

      listItems.add(
        Material(
          color: Colors.transparent,
          child: Semantics(
            label: '주소 선택: $addr',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(fullData, addr),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs), // 4px
                padding: EdgeInsets.symmetric(
                    vertical: itemPadding, horizontal: AppSpacing.lg), // 24px (18px → 24px)
                decoration: BoxDecoration(
                  color: selectedBackgroundColor,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: selectedBorderColor,
                    width: selectedBorderWidth,
                  ),
                  // 선택된 항목에 더 부드러운 그림자 적용 (에어비앤비 스타일)
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AirbnbColors.primaryDark.withValues(alpha: 0.2), // 0.3 → 0.2 (더 부드럽게)
                            blurRadius: 12, // 8 → 12 (더 부드러운 그림자)
                            offset: const Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ]
                      : [
                          // 선택되지 않은 항목에도 미세한 그림자 추가 (깊이감)
                          BoxShadow(
                            color: AirbnbColors.textPrimary.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                            spreadRadius: 0,
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    // 선택된 항목 체크 아이콘 - 더 명확한 시각적 피드백
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded, // rounded 스타일로 통일성 강화
                        color: isLargeText
                            ? AirbnbColors.background // 보라색 배경 위: 흰색
                            : AirbnbColors.primaryDark, // 연한 배경 위: 보라색
                        size: 22,
                      ), // 20 → 22로 약간 크게
                    if (isSelected) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            addr,
                            style: AppTypography.withColor(
                              AppTypography.body.copyWith(
                                fontSize: fontSize,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                height: 1.4,
                              ),
                              selectedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: listItems,
      ),
    );
  }
}

