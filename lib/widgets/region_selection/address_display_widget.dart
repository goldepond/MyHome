import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 주소 표시 위젯
/// 
/// 현재 선택된 주소를 읽기 전용으로 표시합니다.
/// 로딩 상태와 에러 상태도 처리합니다.
class AddressDisplayWidget extends StatelessWidget {
  /// 표시할 주소
  final String? address;
  
  /// 로딩 중 여부
  final bool isLoading;
  
  /// 에러 메시지
  final String? error;

  const AddressDisplayWidget({
    super.key,
    this.address,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AirbnbColors.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라벨
          Text(
            '주소',
            style: AppTypography.caption.copyWith(
              color: AirbnbColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          
          // 주소 내용
          if (isLoading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '주소를 불러오는 중...',
                  style: AppTypography.body.copyWith(
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            )
          else if (error != null)
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AirbnbColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    error!,
                    style: AppTypography.body.copyWith(
                      color: AirbnbColors.error,
                    ),
                  ),
                ),
              ],
            )
          else if (address != null && address!.isNotEmpty)
            Text(
              address!,
              style: AppTypography.body.copyWith(
                color: AirbnbColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              '주소를 선택해주세요',
              style: AppTypography.body.copyWith(
                color: AirbnbColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
