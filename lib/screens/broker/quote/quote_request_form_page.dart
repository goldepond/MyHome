import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/screens/policy/privacy_policy_page.dart';
import 'package:property/screens/policy/terms_of_service_page.dart';
import 'package:property/screens/common/submit_success_page.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/utils/transaction_type_helper.dart';

/// 견적문의 폼 페이지 (부동산 상담 요청서)
class QuoteRequestFormPage extends StatefulWidget {
  final Broker broker;
  final String userName;
  final String userId;
  final String? userEmail; // 게스트 모드에서 전달받은 이메일
  final String? userPhone; // 게스트 모드에서 전달받은 전화번호
  final String propertyAddress;
  final String? propertyArea;
  final String? transactionType; // 거래 유형 (매매/전세/월세)

  const QuoteRequestFormPage({
    super.key,
    required this.broker,
    required this.userName,
    required this.userId,
    required this.propertyAddress,
    this.userEmail,
    this.userPhone,
    this.propertyArea,
    this.transactionType,
  });

  @override
  State<QuoteRequestFormPage> createState() => _QuoteRequestFormPageState();
}

class _QuoteRequestFormPageState extends State<QuoteRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();

  // 1️⃣ 기본정보 (자동)
  String propertyType = '아파트';
  late String propertyAddress;
  late String propertyArea; // 자동 입력됨
  String transactionType = '매매'; // 거래 유형 (매매/전세/월세)

  // 3️⃣ 추가 정보 (소유자/임대인 입력)
  bool hasTenant = false;
  final TextEditingController _desiredPriceController = TextEditingController();
  final TextEditingController _targetPeriodController = TextEditingController();
  final TextEditingController _specialNotesController = TextEditingController();
  bool _agreeToConsent = false;

  // 확인할 견적 정보 선택 (기본값: 모두 선택)
  bool _requestCommissionRate = true;
  bool _requestRecommendedPrice = true;
  bool _requestPromotionMethod = true;
  bool _requestRecentCases = true;
  bool _isRequestInfoExpanded = true;

  @override
  void initState() {
    super.initState();
    propertyAddress = widget.propertyAddress;
    propertyArea = widget.propertyArea ?? '정보 없음';
    transactionType = widget.transactionType ?? '매매'; // 전달받은 거래 유형 또는 기본값
  }

  /// 사용자 이메일 가져오기
  Future<String> _getUserEmail() async {
    // 1. 게스트 모드에서 전달받은 이메일이 있으면 사용
    final widgetEmail = widget.userEmail;
    if (widgetEmail != null && widgetEmail.isNotEmpty) {
      return widgetEmail;
    }

    // 2. Firebase Auth에서 현재 사용자 이메일 가져오기
    final currentUserEmail = _firebaseService.currentUser?.email;
    if (currentUserEmail != null && currentUserEmail.isNotEmpty) {
      return currentUserEmail;
    }

    // 3. userId가 있으면 Firestore에서 사용자 정보 조회
    if (widget.userId.isNotEmpty) {
      final userData = await _firebaseService.getUser(widget.userId);
      if (userData != null && userData['email'] != null) {
        final email = userData['email'] as String;
        if (email.isNotEmpty) {
          return email;
        }
      }
    }

    // 4. 기본값: userName 기반 이메일 (fallback)
    return '${widget.userName}@example.com';
  }

  /// 사용자 전화번호 가져오기
  Future<String?> _getUserPhone() async {
    // 1. 게스트 모드에서 전달받은 전화번호가 있으면 사용
    final widgetPhone = widget.userPhone;
    if (widgetPhone != null && widgetPhone.isNotEmpty) {
      return widgetPhone;
    }

    // 2. userId가 있으면 Firestore에서 사용자 정보 조회
    if (widget.userId.isNotEmpty) {
      final userData = await _firebaseService.getUser(widget.userId);
      if (userData != null && userData['phone'] != null) {
        final phone = userData['phone'] as String;
        if (phone.isNotEmpty) {
          return phone;
        }
      }
    }

    return null;
  }

  @override
  void dispose() {
    _desiredPriceController.dispose();
    _targetPeriodController.dispose();
    _specialNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = ResponsiveHelper.getMaxWidth(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EAF0), // 배경을 더 진하게
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('부동산 상담 요청서'),
          backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: SafeArea(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(kIsWeb ? 40.0 : 20.0),
                  children: [
            // 제목
            Text(
              '🏠 부동산 상담 요청서',
              style: AppTypography.withColor(
                AppTypography.h2,
                AirbnbColors.textPrimary,
              ),
            ),
                        const SizedBox(height: AppSpacing.sm),
            Text(
              '공인중개사에게 정확한 정보를 전달하여 최적의 제안을 받으세요',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ========== 1️⃣ 매물 정보 (자동 입력) ==========
            _buildSectionTitle('매물 정보', '자동 입력됨', AirbnbColors.info),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              _buildInfoRow('주소', propertyAddress),
              if (propertyArea != '정보 없음') ...[
                const SizedBox(height: AppSpacing.sm),
                _buildInfoRow('면적', propertyArea),
              ],
            ]),

            const SizedBox(height: AppSpacing.xl),

            // ========== 2️⃣ 매물 유형 (필수 입력) ==========
            _buildSectionTitle('매물 유형', '필수 입력', AirbnbColors.success),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              DropdownButtonFormField<String>(
                initialValue: propertyType,
                decoration: InputDecoration(
                  hintText: '매물 유형을 선택하세요',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AirbnbColors.primary, width: 2.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: '아파트', child: Text('아파트')),
                  DropdownMenuItem(value: '오피스텔', child: Text('오피스텔')),
                  DropdownMenuItem(value: '원룸', child: Text('원룸')),
                  DropdownMenuItem(value: '다세대', child: Text('다세대')),
                  DropdownMenuItem(value: '주택', child: Text('주택')),
                  DropdownMenuItem(value: '상가', child: Text('상가')),
                  DropdownMenuItem(value: '기타', child: Text('기타')),
                ],
                onChanged: (value) {
                  setState(() {
                    propertyType = value ?? '아파트';
                  });
                },
              ),
            ]),

            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            const SizedBox(height: AppSpacing.lg),

            // ========== 2️⃣ 거래 유형 (필수 입력) ==========
            _buildSectionTitle('거래 유형', '필수 입력', AirbnbColors.success),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '매매', label: Text('매매')),
                  ButtonSegment(value: '전세', label: Text('전세')),
                  ButtonSegment(value: '월세', label: Text('월세')),
                ],
                selected: {transactionType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    transactionType = newSelection.first;
                  });
                },
              ),
            ]),

            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            const SizedBox(height: AppSpacing.lg),

            // ========== 3️⃣ 확인할 견적 정보 ==========
            Container(
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AirbnbColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  AirbnbColors.cardShadowSubtle,
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 (클릭 가능)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isRequestInfoExpanded = !_isRequestInfoExpanded;
                      });
                    },
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AirbnbColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: AirbnbColors.textWhite,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          const Expanded(
                            child: Row(
                              children: [
                                Text(
                                  '확인할 견적 정보',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AirbnbColors.primary,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  '선택 입력',
                                  style: TextStyle(
                                    color: AirbnbColors.textSecondary,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _isRequestInfoExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: AirbnbColors.primary,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 내용 (접기/펼치기)
                  AnimatedCrossFade(
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Column(
                        children: [
                          _buildRequestItem(
                            '💰',
                            '중개 수수료',
                            '수수료는 얼마인가요?',
                            _requestCommissionRate,
                            (value) => setState(() => _requestCommissionRate = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📊',
                            TransactionTypeHelper.getAppropriatePriceLabel(transactionType),
                            TransactionTypeHelper.getPriceQuestion(transactionType),
                            _requestRecommendedPrice,
                            (value) => setState(() => _requestRecommendedPrice = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📢',
                            '홍보 방법',
                            '어떻게 홍보하시나요?',
                            _requestPromotionMethod,
                            (value) => setState(() => _requestPromotionMethod = value),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📋',
                            '최근 유사 거래 사례',
                            '유사한 거래 사례가 있나요?',
                            _requestRecentCases,
                            (value) => setState(() => _requestRecentCases = value),
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                    crossFadeState: _isRequestInfoExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            const SizedBox(height: AppSpacing.lg),

            // ========== 3️⃣ 추가 요청사항 (선택) ==========
            _buildSectionTitle('궁금한 점이 있으신가요?', '선택사항', AirbnbColors.primary),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '현재 세입자가 있나요? *',
                      style: AppTypography.withColor(
                        AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        AirbnbColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: hasTenant,
                    onChanged: (value) {
                      setState(() {
                        hasTenant = value;
                      });
                    },
                    activeThumbColor: AirbnbColors.primary,
                  ),
                  Text(
                    hasTenant ? '있음' : '없음',
                    style: const TextStyle(
                      color: AirbnbColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _buildTextField(
                label: '희망 거래가',
                controller: _desiredPriceController,
                hint: '예: 11억 / 협의 가능',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildTextField(
                label: '기타 요청사항 (300자 이내)',
                controller: _specialNotesController,
                hint: '추가로 궁금하신 점이나 특별히 확인하고 싶은 사항을 자유롭게 적어주세요',
                maxLines: 8,
                maxLength: 300,
              ),
            ]),

            const SizedBox(height: AppSpacing.lg),
            const Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            const SizedBox(height: AppSpacing.lg),

            // 제출 버튼
            // 동의 체크
            _buildCard([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreeToConsent,
                    onChanged: (v) => setState(() => _agreeToConsent = v ?? false),
                    activeColor: AirbnbColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '개인정보 제3자 제공 동의 (필수)',
                          style: AppTypography.withColor(
                            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            AirbnbColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '선택한 공인중개사에게 문의 처리 목적의 최소한의 정보가 제공됩니다. '
                          '자세한 내용은 내 정보 > 정책 및 도움말에서 확인할 수 있습니다.',
                          style: AppTypography.withColor(
                            AppTypography.caption.copyWith(height: 1.5),
                            AirbnbColors.textSecondary,
                          ),
                        ),
                            const SizedBox(height: AppSpacing.xs + AppSpacing.xs / 2),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                        },
                        child: const Text('개인정보 처리방침 보기'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServicePage()));
                        },
                        child: const Text('이용약관 보기'),
                      ),
                    ],
                  ),
                ),

            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6, // 그림자 강화
                  shadowColor: AirbnbColors.primary.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.send, size: 24),
                label: const Text(
                  '문의하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // 웹 전용 푸터 여백 (영상 촬영용)
            if (kIsWeb) const SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 공통 빌더 메서드 (하위 클래스에서도 사용 가능하도록 공개)
  Widget _buildSectionTitle(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_outline, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AirbnbColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
                        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AirbnbColors.primary, width: 2.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                AirbnbColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(String emoji, String title, String description, bool value, ValueChanged<bool>? onChanged) {
    return InkWell(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: value
              ? AirbnbColors.primary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value
                ? AirbnbColors.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: value ? 3 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onChanged != null) ...[
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value ? AirbnbColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: value ? AirbnbColors.primary : Colors.grey.withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                  ),
                  child: value
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22, weight: 700)
                    : null,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: value ? const Color(0xFF1A1A1A) : AirbnbColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(
                      fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                      color: value ? const Color(0xFF2C3E50) : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 제출
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_agreeToConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('개인정보 제3자 제공 동의에 체크해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 견적문의 객체 생성
    // 게스트 모드에서 전달받은 이메일/전화번호 우선 사용
    final userEmail = widget.userEmail ?? await _getUserEmail();
    final userPhone = widget.userPhone ?? await _getUserPhone();
    // 게스트 모드에서 생성된 userId 사용 (widget.userId는 게스트 모드에서 생성된 effectiveUserId)
    final effectiveUserId = widget.userId.isNotEmpty ? widget.userId : widget.userName;
    final effectiveUserName = widget.userName;
                final quoteRequest = QuoteRequest(
      id: '',
                  userId: effectiveUserId,
                  userName: effectiveUserName,
      userEmail: userEmail,
      userPhone: userPhone,
      brokerName: widget.broker.name,
      brokerRegistrationNumber: widget.broker.registrationNumber,
      brokerRoadAddress: widget.broker.roadAddress,
      brokerJibunAddress: widget.broker.jibunAddress,
      message: '부동산 상담 요청서',
                  status: 'pending',
                  requestDate: DateTime.now(),
      consentAgreed: true,
      consentAgreedAt: DateTime.now(),
      // 1️⃣ 기본정보
      transactionType: transactionType,
      propertyType: propertyType,
      propertyAddress: propertyAddress,
      propertyArea: propertyArea != '정보 없음' ? propertyArea : null,
      // 3️⃣ 추가 정보
      hasTenant: hasTenant,
      desiredPrice: _desiredPriceController.text.trim().isNotEmpty ? _desiredPriceController.text.trim() : null,
      specialNotes: _specialNotesController.text.trim().isNotEmpty ? _specialNotesController.text.trim() : null,
      // 확인할 견적 정보 (선택되지 않은 항목은 null)
      commissionRate: _requestCommissionRate ? '' : null,
      recommendedPrice: _requestRecommendedPrice ? '' : null,
      promotionMethod: _requestPromotionMethod ? '' : null,
      recentCases: _requestRecentCases ? '' : null,
    );

    // Firebase 저장
                final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);

    if (requestId != null && mounted) {
      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.quoteRequestSubmitted,
        params: {
          'brokerName': widget.broker.name,
          'brokerRegNo': widget.broker.registrationNumber,
          'address': propertyAddress,
          'mode': 'single',
        },
        userId: effectiveUserId,
        userName: effectiveUserName,
        stage: FunnelStage.quoteRequest,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubmitSuccessPage(
            title: '문의가 전송되었습니다',
            description: '${widget.broker.name}에게 문의를 보냈습니다.\n답변이 도착하면 현황에서 확인할 수 있어요.',
            userName: effectiveUserName,
            userId: effectiveUserId.isNotEmpty && effectiveUserId != widget.userName ? effectiveUserId : null,
          ),
        ),
      );
    } else if (mounted) {
      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.quoteRequestSubmitFailed,
        params: {
          'brokerName': widget.broker.name,
          'brokerRegNo': widget.broker.registrationNumber,
          'address': propertyAddress,
          'mode': 'single',
        },
        userId: effectiveUserId,
        userName: effectiveUserName,
        stage: FunnelStage.quoteRequest,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문의 전송에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
