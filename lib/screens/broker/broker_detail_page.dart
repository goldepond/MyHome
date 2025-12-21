import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/models/broker_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// 공인중개사 상세 소개 / 후기 페이지
///
/// - 공인중개사 찾기 페이지 카드에서 진입
/// - 내집관리(견적 이력) 카드에서 진입
/// - 매물 정보는 표시하지 않고, 중개사 정보와 후기만 표시
class BrokerDetailPage extends StatelessWidget {
  final Broker broker;
  final String? currentUserId;
  final String? currentUserName;
  final String? quoteRequestId;  // 내집관리에서 들어온 경우, 어떤 견적인지
  final String? quoteStatus;     // 견적 상태 (completed 에서만 후기 허용)

  const BrokerDetailPage({
    super.key,
    required this.broker,
    this.currentUserId,
    this.currentUserName,
    this.quoteRequestId,
    this.quoteStatus,
  });

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    
    // 반응형 레이아웃: PC 화면 고려
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1200.0 : screenWidth;
    final horizontalPadding = isWeb ? 24.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('공인중개사 정보'),
        backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
        foregroundColor: AirbnbColors.textPrimary,
      ),
      body: StreamBuilder<List<BrokerReview>>(
        stream: firebaseService.getBrokerReviews(broker.registrationNumber),
        builder: (context, snapshot) {
          final reviews = snapshot.data ?? <BrokerReview>[];

          final recommendCount = reviews.where((r) => r.recommend).length;
          final notRecommendCount = reviews.where((r) => !r.recommend).length;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _buildHeaderCard(
                  reviewCount: reviews.length,
                  recommendCount: recommendCount,
                  notRecommendCount: notRecommendCount,
                ),
                SizedBox(height: AppSpacing.md),
                _buildInfoCard(),
                SizedBox(height: AppSpacing.md),
                _buildActionsRow(context),
                SizedBox(height: AppSpacing.md),
                if (_canWriteReview)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openReviewSheet(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AirbnbColors.primary,
                        side: const BorderSide(color: AirbnbColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: Text(
                        '이 중개사에 후기 남기기 / 수정하기',
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                SizedBox(height: AppSpacing.lg),
                _buildReviewSection(reviews),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _canWriteReview {
    return currentUserId != null &&
        currentUserId!.isNotEmpty &&
        quoteRequestId != null &&
        quoteRequestId!.isNotEmpty &&
        quoteStatus == 'completed';
  }

  /// 상단 요약 카드 (이름 / 대표자 / 등록번호 / 추천·비추천)
  Widget _buildHeaderCard({
    required int reviewCount,
    required int recommendCount,
    required int notRecommendCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            broker.name,
            style: AppTypography.withColor(
              AppTypography.h4.copyWith(fontWeight: FontWeight.bold),
              AirbnbColors.background,
            ),
          ),
          if (broker.ownerName != null && broker.ownerName!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              '중개업자명: ${broker.ownerName}',
              style: AppTypography.withColor(
                AppTypography.bodySmall,
                AirbnbColors.background.withValues(alpha: 0.9),
              ),
            ),
          ],
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.badge, color: AirbnbColors.background.withValues(alpha: 0.9), size: 16),
              const SizedBox(width: 6),
              Text(
                '등록번호: ${broker.registrationNumber}',
                style: AppTypography.withColor(
                  AppTypography.bodySmall,
                  AirbnbColors.background.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          if (reviewCount > 0) ...[
            Text(
              '추천 $recommendCount · 비추천 $notRecommendCount',
              style: TextStyle(
                color: AirbnbColors.background.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            Text(
              '아직 등록된 후기가 없습니다',
              style: AppTypography.withColor(
                AppTypography.bodySmall,
                AirbnbColors.background.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 공인중개사 기본 정보 카드 (주소 / 전화 / 영업상태 / 등록번호 / 고용인원 / 소개란 / 행정처분)
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 전화번호
          if (broker.phoneNumber != null && broker.phoneNumber!.isNotEmpty && broker.phoneNumber != '-') ...[
            _infoRow(Icons.phone, '전화번호', broker.phoneNumber!),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
          ],
          // 주소 표시: 도로명주소 우선, 없으면 지번주소
          if (broker.roadAddress.isNotEmpty || broker.jibunAddress.isNotEmpty) ...[
            _infoRow(
              Icons.location_on,
              '주소',
              broker.roadAddress.isNotEmpty ? broker.roadAddress : broker.jibunAddress,
            ),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
          ],
          // 영업상태
          if (broker.businessStatus != null && broker.businessStatus!.isNotEmpty) ...[
            _infoRow(Icons.store, '영업상태', broker.businessStatus!),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
          ],
          // 등록번호와 고용인원 (한 줄에)
          Row(
            children: [
              Expanded(
                child: _infoRow(Icons.badge, '등록번호', broker.registrationNumber),
              ),
              if (broker.employeeCount.isNotEmpty && 
                  broker.employeeCount != '-' && 
                  broker.employeeCount != '0') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _infoRow(
                    Icons.people,
                    '고용인원',
                    '${broker.employeeCount}명',
                  ),
                ),
              ],
            ],
          ),
          // 소개란 (있는 경우만 표시)
          if (broker.introduction != null && broker.introduction!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AirbnbColors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, color: AirbnbColors.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '중개사 소개',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    broker.introduction!,
                    style: AppTypography.withColor(
                      AppTypography.bodySmall.copyWith(height: 1.5),
                      AirbnbColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // 행정처분 정보 (있는 경우만 표시)
          if ((broker.penaltyStartDate != null && broker.penaltyStartDate!.isNotEmpty) ||
              (broker.penaltyEndDate != null && broker.penaltyEndDate!.isNotEmpty)) ...[
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AirbnbColors.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AirbnbColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AirbnbColors.warning.withValues(alpha: 0.7), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '행정처분 이력',
                        style: AppTypography.withColor(
                          AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                          AirbnbColors.warning.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  if (broker.penaltyStartDate != null &&
                      broker.penaltyStartDate!.isNotEmpty)
                    _smallInfoRow('처분 시작일', broker.penaltyStartDate!),
                  if (broker.penaltyEndDate != null &&
                      broker.penaltyEndDate!.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.xs),
                    _smallInfoRow('처분 종료일', broker.penaltyEndDate!),
                  ],
                ],
              ),
            ),
          ],
          // 글로벌공인중개사무소 정보 (있는 경우만 표시)
          if ((broker.globalBrokerLanguage != null && broker.globalBrokerLanguage!.isNotEmpty) ||
              (broker.globalBrokerAppnYear != null && broker.globalBrokerAppnYear!.isNotEmpty)) ...[
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AirbnbColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, color: AirbnbColors.primary.withValues(alpha: 0.7), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '글로벌공인중개사무소',
                        style: AppTypography.withColor(
                          AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                          AirbnbColors.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  if (broker.globalBrokerLanguage != null && broker.globalBrokerLanguage!.isNotEmpty)
                    _smallInfoRow('사용언어', broker.globalBrokerLanguage!),
                  if (broker.globalBrokerAppnYear != null && broker.globalBrokerAppnYear!.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.xs),
                    _smallInfoRow('지정연도', broker.globalBrokerAppnYear!),
                  ],
                  if (broker.globalBrokerAppnNo != null && broker.globalBrokerAppnNo!.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.xs),
                    _smallInfoRow('지정번호', broker.globalBrokerAppnNo!),
                  ],
                  if (broker.globalBrokerAppnDe != null && broker.globalBrokerAppnDe!.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.xs),
                    _smallInfoRow('지정일', broker.globalBrokerAppnDe!),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AirbnbColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.withColor(
                  AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                  AirbnbColors.textSecondary,
                ),
              ),
              SizedBox(height: AppSpacing.xs / 2),
              Text(
                value,
                style: AppTypography.withColor(
                  AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                  AirbnbColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AirbnbColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.withColor(
              AppTypography.body,
              AirbnbColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// 길찾기 / 전화하기 액션 버튼
  Widget _buildActionsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openMap(broker.roadAddress),
            icon: const Icon(Icons.map, size: 18),
            label: const Text('길찾기'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: broker.phoneNumber == null || broker.phoneNumber!.isEmpty
                ? null
                : () => _callBroker(broker.phoneNumber!),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('전화하기'),
          ),
        ),
      ],
    );
  }

  /// 후기 리스트
  Widget _buildReviewSection(List<BrokerReview> reviews) {
    if (reviews.isEmpty) {
      return         Text(
        '아직 등록된 후기가 없습니다.\n내집관리 > 견적 이력에서 상담이 끝난 중개사에게 후기를 남겨보세요.',
        style: AppTypography.withColor(
          AppTypography.bodySmall,
          AirbnbColors.textSecondary,
        ),
      );
    }

    final dateFormat = DateFormat('yyyy.MM.dd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '후기',
          style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...reviews.map((r) {
          return Container(
            margin: EdgeInsets.only(bottom: AppSpacing.sm),
            padding: EdgeInsets.all(AppSpacing.md - AppSpacing.xs),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      r.recommend ? Icons.thumb_up_alt_outlined : Icons.thumb_down_alt_outlined,
                      size: 16,
                      color: r.recommend ? AirbnbColors.success.withValues(alpha: 0.7) : AirbnbColors.error.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      r.recommend ? '추천' : '비추천',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: r.recommend ? AirbnbColors.success.withValues(alpha: 0.7) : AirbnbColors.error.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateFormat.format(r.createdAt),
                      style: AppTypography.withColor(
                    AppTypography.caption,
                    AirbnbColors.textSecondary,
                  ),
                    ),
                  ],
                ),
                if (r.comment != null && r.comment!.trim().isNotEmpty) ...[
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    r.comment!,
                    style: AppTypography.bodySmall.copyWith(height: 1.3),
                  ),
                ],
                SizedBox(height: AppSpacing.xs / 2),
                Text(
                  r.userName,
                  style: AppTypography.withColor(
                    AppTypography.caption,
                    AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openMap(String address) async {
    final encoded = Uri.encodeComponent(address);
    final uri = Uri.parse('https://map.naver.com/v5/search/$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callBroker(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// 후기 작성 / 수정 바텀시트 (내집관리에서 들어온 경우에만 사용)
  Future<void> _openReviewSheet(BuildContext context) async {
    if (currentUserId == null || currentUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 후기를 작성할 수 있습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }
    if (quoteRequestId == null || quoteRequestId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이 견적에 대한 정보가 없어 후기를 작성할 수 없습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }
    if (quoteStatus != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상담이 완료된 견적에만 후기를 남길 수 있습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    final firebaseService = FirebaseService();
    final existingReview = await firebaseService.getUserReviewForQuote(
      userId: currentUserId!,
      brokerRegistrationNumber: broker.registrationNumber,
      quoteRequestId: quoteRequestId!,
    );

    bool recommend = existingReview?.recommend ?? true;
    final commentController =
        TextEditingController(text: existingReview?.comment ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${broker.name} 후기',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text('추천 여부', style: AppTypography.bodySmall),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('추천'),
                        selected: recommend == true,
                        onSelected: (_) {
                          setState(() {
                            recommend = true;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('비추천'),
                        selected: recommend == false,
                        onSelected: (_) {
                          setState(() {
                            recommend = false;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.md + AppSpacing.xs),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '상담을 받으면서 좋았던 점, 아쉬웠던 점을 자유롭게 작성해주세요.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md + AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final trimmed = commentController.text.trim().isEmpty
                            ? null
                            : commentController.text.trim();

                        final now = DateTime.now();
                        final review = BrokerReview(
                          id: existingReview?.id ?? '',
                          brokerRegistrationNumber: broker.registrationNumber,
                          userId: currentUserId!,
                          userName: currentUserName ?? '알 수 없음',
                          quoteRequestId: quoteRequestId!,
                          rating: recommend ? 5 : 1,
                          recommend: recommend,
                          comment: trimmed,
                          createdAt: existingReview?.createdAt ?? now,
                          updatedAt: now,
                        );

                        final savedId =
                            await firebaseService.saveBrokerReview(review);

                        if (!context.mounted) return;

                        Navigator.pop(context);

                        if (savedId != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('후기가 저장되었습니다.'),
                              backgroundColor: AirbnbColors.success,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('후기 저장에 실패했습니다.'),
                              backgroundColor: AirbnbColors.error,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                        foregroundColor: AirbnbColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        existingReview == null ? '후기 저장' : '후기 수정하기',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}


