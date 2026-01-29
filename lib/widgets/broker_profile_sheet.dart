import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/apple_design_system.dart';
import '../api_request/firebase_service.dart';

/// 공인중개사 프로필 바텀시트
/// 판매자가 중개사 정보를 조회할 때 사용
class BrokerProfileSheet extends StatefulWidget {
  final String brokerId;
  final String? brokerName;
  final String? brokerCompany;
  final String? brokerPhone;

  const BrokerProfileSheet({
    required this.brokerId, super.key,
    this.brokerName,
    this.brokerCompany,
    this.brokerPhone,
  });

  /// 바텀시트로 표시
  static Future<void> show(
    BuildContext context, {
    required String brokerId,
    String? brokerName,
    String? brokerCompany,
    String? brokerPhone,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => BrokerProfileSheet(
        brokerId: brokerId,
        brokerName: brokerName,
        brokerCompany: brokerCompany,
        brokerPhone: brokerPhone,
      ),
    );
  }

  @override
  State<BrokerProfileSheet> createState() => _BrokerProfileSheetState();
}

class _BrokerProfileSheetState extends State<BrokerProfileSheet> {
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? _brokerData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBrokerData();
  }

  Future<void> _loadBrokerData() async {
    try {
      // brokerId로 조회
      final data = await _firebaseService.getBroker(widget.brokerId);
      if (mounted) {
        setState(() {
          _brokerData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.separator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // 헤더
          Padding(
            padding: const EdgeInsets.all(AppleSpacing.md),
            child: Row(
              children: [
                Text(
                  '중개사 정보',
                  style: AppleTypography.title2.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppleColors.secondaryLabel),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 콘텐츠
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppleSpacing.lg),
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  : _buildProfileContent(),
            ),
          ),

          // 하단 여백
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppleSpacing.md),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    final registrationNumber = _brokerData?['brokerRegistrationNumber'] as String? ?? '';
    final businessName = _brokerData?['businessName'] as String? ?? widget.brokerCompany ?? widget.brokerName ?? '정보 없음';
    final ownerName = _brokerData?['ownerName'] as String? ?? widget.brokerName ?? '';
    final phoneNumber = _brokerData?['phoneNumber'] as String? ?? widget.brokerPhone ?? '';
    final address = _brokerData?['address'] as String? ?? '';
    final isVerified = _brokerData?['verified'] as bool? ?? false;

    // 성과 통계
    final stats = _brokerData?['stats'] as Map<String, dynamic>?;
    final totalDeals = stats?['totalDeals'] as int? ?? 0;
    final totalReviews = stats?['totalReviews'] as int? ?? 0;
    final averageRating = stats?['averageRating'] as double? ?? 0.0;
    final recommendRate = stats?['recommendRate'] as double? ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로필 카드
        Container(
          padding: const EdgeInsets.all(AppleSpacing.lg),
          decoration: BoxDecoration(
            color: AppleColors.secondarySystemGroupedBackground,
            borderRadius: BorderRadius.circular(AppleRadius.md),
            border: Border.all(
              color: isVerified ? AppleColors.systemGreen.withValues(alpha: 0.3) : AppleColors.separator,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더: 프로필 아이콘 + 상호명 + 검증 뱃지
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppleColors.systemBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.store_rounded,
                      color: AppleColors.systemBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppleSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                businessName,
                                style: AppleTypography.title3.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppleColors.systemGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified, size: 14, color: AppleColors.systemGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                      '인증',
                                      style: AppleTypography.caption2.copyWith(
                                        color: AppleColors.systemGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (ownerName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '대표 $ownerName',
                            style: AppleTypography.subheadline.copyWith(
                              color: AppleColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppleSpacing.lg),
              Container(height: 0.5, color: AppleColors.separator),
              const SizedBox(height: AppleSpacing.md),

              // 정보 리스트
              if (registrationNumber.isNotEmpty)
                _buildInfoRow(Icons.badge_outlined, '등록번호', registrationNumber),
              if (phoneNumber.isNotEmpty)
                _buildInfoRow(Icons.phone_outlined, '연락처', _formatPhoneNumber(phoneNumber)),
              if (address.isNotEmpty)
                _buildInfoRow(Icons.location_on_outlined, '소재지', address),
            ],
          ),
        ),

        const SizedBox(height: AppleSpacing.lg),

        // 성과 통계 (있는 경우)
        if (totalDeals > 0 || totalReviews > 0) ...[
          Text(
            '성과',
            style: AppleTypography.headline.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppleSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppleSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppleColors.systemBlue, AppleColors.systemIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppleRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.handshake_outlined,
                    value: '$totalDeals',
                    label: '거래 성사',
                    isLight: true,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.star_outline,
                    value: averageRating > 0 ? averageRating.toStringAsFixed(1) : '-',
                    label: '평점',
                    isLight: true,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.thumb_up_outlined,
                    value: recommendRate > 0 ? '${(recommendRate * 100).toInt()}%' : '-',
                    label: '추천율',
                    isLight: true,
                  ),
                ),
                Expanded(
                  child: _buildStatColumn(
                    icon: Icons.rate_review_outlined,
                    value: '$totalReviews',
                    label: '리뷰',
                    isLight: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppleSpacing.lg),
        ],

        // 전화하기 버튼 (전화번호가 있는 경우)
        if (phoneNumber.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _callBroker(phoneNumber),
              icon: const Icon(Icons.phone),
              label: const Text('전화하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppleColors.systemGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppleSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppleRadius.sm),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppleColors.secondaryLabel),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: AppleTypography.subheadline.copyWith(
                color: AppleColors.secondaryLabel,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label 복사됨'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Text(
                value,
                style: AppleTypography.subheadline.copyWith(
                  color: AppleColors.label,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
    bool isLight = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: isLight ? Colors.white70 : AppleColors.secondaryLabel,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppleTypography.title2.copyWith(
            fontWeight: FontWeight.w700,
            color: isLight ? Colors.white : AppleColors.label,
          ),
        ),
        Text(
          label,
          style: AppleTypography.caption2.copyWith(
            color: isLight ? Colors.white60 : AppleColors.tertiaryLabel,
          ),
        ),
      ],
    );
  }

  String _formatPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      if (digits.startsWith('02')) {
        return '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6)}';
      }
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  Future<void> _callBroker(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
