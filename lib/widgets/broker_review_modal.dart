import 'package:flutter/material.dart';
import '../constants/apple_design_system.dart';
import '../api_request/firebase_service.dart';
import '../models/broker_review.dart';
import '../utils/logger.dart';

/// 거래 완료 후 중개사 리뷰 작성 모달
///
/// 거래 완료 시 자동으로 표시되어 사용자의 리뷰를 수집합니다.
class BrokerReviewModal extends StatefulWidget {
  final String brokerRegistrationNumber;
  final String brokerName;
  final String? brokerCompany;
  final String userId;
  final String userName;
  final String? relatedId; // 견적 ID 또는 매물 ID
  final VoidCallback? onReviewSubmitted;

  const BrokerReviewModal({
    Key? key,
    required this.brokerRegistrationNumber,
    required this.brokerName,
    this.brokerCompany,
    required this.userId,
    required this.userName,
    this.relatedId,
    this.onReviewSubmitted,
  }) : super(key: key);

  /// 리뷰 모달을 표시합니다.
  static Future<void> show(
    BuildContext context, {
    required String brokerRegistrationNumber,
    required String brokerName,
    String? brokerCompany,
    required String userId,
    required String userName,
    String? relatedId,
    VoidCallback? onReviewSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => BrokerReviewModal(
        brokerRegistrationNumber: brokerRegistrationNumber,
        brokerName: brokerName,
        brokerCompany: brokerCompany,
        userId: userId,
        userName: userName,
        relatedId: relatedId,
        onReviewSubmitted: onReviewSubmitted,
      ),
    );
  }

  @override
  State<BrokerReviewModal> createState() => _BrokerReviewModalState();
}

class _BrokerReviewModalState extends State<BrokerReviewModal> {
  final _firebaseService = FirebaseService();
  final _commentController = TextEditingController();

  int _rating = 0;
  bool? _recommend; // null: 미선택, true: 추천, false: 비추천
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppleRadius.xl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppleSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 핸들
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppleColors.separator,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                const SizedBox(height: AppleSpacing.lg),

                // 헤더
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppleColors.systemGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppleRadius.md),
                      ),
                      child: const Icon(
                        Icons.rate_review_outlined,
                        color: AppleColors.systemGreen,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppleSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '거래는 어떠셨나요?',
                            style: AppleTypography.title2.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.brokerName} 중개사님에 대한 평가를 남겨주세요',
                            style: AppleTypography.subheadline.copyWith(
                              color: AppleColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppleSpacing.xl),

                // 별점
                _buildRatingSection(),
                const SizedBox(height: AppleSpacing.lg),

                // 추천/비추천
                _buildRecommendSection(),
                const SizedBox(height: AppleSpacing.lg),

                // 코멘트
                _buildCommentSection(),
                const SizedBox(height: AppleSpacing.xl),

                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppleRadius.md),
                          ),
                          side: const BorderSide(color: AppleColors.separator),
                        ),
                        child: Text(
                          '나중에',
                          style: AppleTypography.body.copyWith(
                            color: AppleColors.secondaryLabel,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppleSpacing.md),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _submitReview : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppleColors.systemBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppleColors.tertiarySystemFill,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppleRadius.md),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                '리뷰 등록',
                                style: AppleTypography.body.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '만족도',
          style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppleSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starIndex = index + 1;
            return GestureDetector(
              onTap: () => setState(() => _rating = starIndex),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: starIndex <= _rating
                      ? AppleColors.systemYellow
                      : AppleColors.tertiaryLabel,
                  size: 44,
                ),
              ),
            );
          }),
        ),
        if (_rating > 0)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppleSpacing.xs),
              child: Text(
                _getRatingText(_rating),
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.systemYellow,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '이 중개사를 추천하시겠어요?',
          style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppleSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _buildRecommendButton(
                isRecommend: true,
                icon: Icons.thumb_up_alt_outlined,
                selectedIcon: Icons.thumb_up_alt,
                label: '추천해요',
                color: AppleColors.systemGreen,
              ),
            ),
            const SizedBox(width: AppleSpacing.md),
            Expanded(
              child: _buildRecommendButton(
                isRecommend: false,
                icon: Icons.thumb_down_alt_outlined,
                selectedIcon: Icons.thumb_down_alt,
                label: '아쉬워요',
                color: AppleColors.systemRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendButton({
    required bool isRecommend,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required Color color,
  }) {
    final isSelected = _recommend == isRecommend;
    return GestureDetector(
      onTap: () => setState(() => _recommend = isRecommend),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppleSpacing.md),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppleColors.tertiarySystemFill,
          borderRadius: BorderRadius.circular(AppleRadius.md),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? color : AppleColors.tertiaryLabel,
              size: 32,
            ),
            const SizedBox(height: AppleSpacing.xs),
            Text(
              label,
              style: AppleTypography.subheadline.copyWith(
                color: isSelected ? color : AppleColors.secondaryLabel,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '상세 후기',
              style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppleSpacing.xs),
            Text(
              '(선택)',
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.tertiaryLabel,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppleSpacing.sm),
        TextField(
          controller: _commentController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: '중개 서비스에 대한 경험을 자유롭게 작성해주세요',
            hintStyle: AppleTypography.body.copyWith(
              color: AppleColors.tertiaryLabel,
            ),
            filled: true,
            fillColor: AppleColors.tertiarySystemFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppleRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppleRadius.md),
              borderSide: const BorderSide(color: AppleColors.systemBlue),
            ),
            counterStyle: AppleTypography.caption2.copyWith(
              color: AppleColors.tertiaryLabel,
            ),
          ),
        ),
      ],
    );
  }

  bool get _canSubmit => _rating > 0 && _recommend != null && !_isSubmitting;

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return '별로예요';
      case 2:
        return '아쉬워요';
      case 3:
        return '괜찮아요';
      case 4:
        return '좋아요';
      case 5:
        return '최고예요!';
      default:
        return '';
    }
  }

  Future<void> _submitReview() async {
    if (!_canSubmit) return;

    setState(() => _isSubmitting = true);

    try {
      final review = BrokerReview(
        id: '',
        brokerRegistrationNumber: widget.brokerRegistrationNumber,
        userId: widget.userId,
        userName: widget.userName,
        quoteRequestId: widget.relatedId ?? '',
        rating: _rating,
        recommend: _recommend!,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      final success = await _firebaseService.createBrokerReview(review);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
        widget.onReviewSubmitted?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('리뷰가 등록되었습니다. 감사합니다!'),
            backgroundColor: AppleColors.systemGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppleRadius.sm),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('리뷰 등록에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AppleColors.systemRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppleRadius.sm),
            ),
          ),
        );
      }
    } catch (e) {
      Logger.error('Failed to submit review', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
