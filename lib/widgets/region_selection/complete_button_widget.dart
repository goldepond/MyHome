import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 완료 버튼 위젯
/// 
/// 주소 선택을 완료하는 버튼입니다.
/// 주소가 있을 때만 활성화됩니다.
class CompleteButtonWidget extends StatelessWidget {
  /// 주소가 있는지 여부
  final bool hasAddress;
  
  /// 완료 버튼 클릭 콜백
  final VoidCallback onComplete;

  const CompleteButtonWidget({
    super.key,
    required this.hasAddress,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: hasAddress ? onComplete : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: hasAddress
              ? AirbnbColors.primary
              : AirbnbColors.border,
          foregroundColor: hasAddress
              ? AirbnbColors.background
              : AirbnbColors.textSecondary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: hasAddress ? 2 : 0,
          shadowColor: hasAddress
              ? AirbnbColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        child: Text(
          '완료',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: hasAddress
                ? AirbnbColors.background
                : AirbnbColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
