import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/screens/policy/privacy_policy_page.dart';
import 'package:property/screens/policy/terms_of_service_page.dart';
import 'package:property/screens/common/submit_success_page.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/utils/transaction_type_helper.dart';
import 'package:property/utils/validation_utils.dart';

/// 견적문의 폼 페이지 (부동산 상담 요청서)
class QuoteRequestFormPage extends StatefulWidget {
  final Broker broker;
  final String userName;
  final String userId;
  final String propertyAddress;
  final String? propertyArea;
  final String? transactionType; // 거래 유형 (매매/전세/월세)
  
  const QuoteRequestFormPage({
    required this.broker,
    required this.userName,
    required this.userId,
    required this.propertyAddress,
    this.propertyArea,
    this.transactionType,
    super.key,
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
  
  // 🔥 게스트 모드일 때 연락처 입력 필드
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    propertyAddress = widget.propertyAddress;
    propertyArea = widget.propertyArea ?? '정보 없음';
    transactionType = widget.transactionType ?? '매매'; // 전달받은 거래 유형 또는 기본값
  }

  /// 사용자 이메일 가져오기
  Future<String> _getUserEmail() async {
    // 1. Firebase Auth에서 현재 사용자 이메일 가져오기
    final currentUser = _firebaseService.currentUser;
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      return currentUser.email!;
    }

    // 2. userId가 있으면 Firestore에서 사용자 정보 조회
    if (widget.userId.isNotEmpty) {
      final userData = await _firebaseService.getUser(widget.userId);
      if (userData != null && userData['email'] != null) {
        final email = userData['email'] as String;
        if (email.isNotEmpty) {
          return email;
        }
      }
    }

    // 3. 기본값: userName 기반 이메일 (fallback)
    return '${widget.userName}@example.com';
  }
  
  @override
  void dispose() {
    _desiredPriceController.dispose();
    _targetPeriodController.dispose();
    _specialNotesController.dispose();
    // 🔥 게스트 모드 필드 dispose
    if (widget.userId.isEmpty) {
      _emailController.dispose();
      _phoneController.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = kIsWeb;
    final maxContentWidth = isWeb ? 800.0 : screenWidth;
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EAF0), // 배경을 더 진하게
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('부동산 상담 요청서'),
          backgroundColor: AppColors.kPrimary,
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
                  padding: EdgeInsets.all(isWeb ? 40.0 : 20.0),
                  children: [
            // 제목
            const Text(
              '🏠 부동산 상담 요청서',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '공인중개사에게 정확한 정보를 전달하여 최적의 제안을 받으세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // ========== 1️⃣ 매물 정보 (자동 입력) ==========
            _buildSectionTitle('매물 정보', '자동 입력됨', Colors.blue),
            const SizedBox(height: 12),
            _buildCard([
              _buildInfoRow('주소', propertyAddress),
              if (propertyArea != '정보 없음') ...[
                const SizedBox(height: 12),
                _buildInfoRow('면적', propertyArea),
              ],
            ]),
            
            const SizedBox(height: 32),
            
            // ========== 2️⃣ 매물 유형 (필수 입력) ==========
            _buildSectionTitle('매물 유형', '필수 입력', Colors.green),
            const SizedBox(height: 12),
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
                    borderSide: const BorderSide(color: AppColors.kPrimary, width: 2.5),
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
            
            const SizedBox(height: 24),
            Divider(color: Colors.grey[300], thickness: 1, height: 1),
            const SizedBox(height: 24),
            
            // ========== 2️⃣ 거래 유형 (필수 입력) ==========
            _buildSectionTitle('거래 유형', '필수 입력', Colors.green),
            const SizedBox(height: 12),
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
            
            const SizedBox(height: 24),
            Divider(color: Colors.grey[300], thickness: 1, height: 1),
            const SizedBox(height: 24),
            
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
                              color: AppColors.kPrimary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  '확인할 견적 정보',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.kPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '선택 입력',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _isRequestInfoExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.kPrimary,
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
                          const SizedBox(height: 12),
                          _buildRequestItem(
                            '📊', 
                            TransactionTypeHelper.getAppropriatePriceLabel(transactionType), 
                            TransactionTypeHelper.getPriceQuestion(transactionType),
                            _requestRecommendedPrice,
                            (value) => setState(() => _requestRecommendedPrice = value),
                          ),
                          const SizedBox(height: 12),
                          _buildRequestItem(
                            '📢', 
                            '홍보 방법', 
                            '어떻게 홍보하시나요?',
                            _requestPromotionMethod,
                            (value) => setState(() => _requestPromotionMethod = value),
                          ),
                          const SizedBox(height: 12),
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
            
            const SizedBox(height: 24),
            Divider(color: Colors.grey[300], thickness: 1, height: 1),
            const SizedBox(height: 24),
            
            // ========== 3️⃣ 추가 요청사항 (선택) ==========
            _buildSectionTitle('궁금한 점이 있으신가요?', '선택사항', AppColors.kPrimary),
            const SizedBox(height: 12),
            _buildCard([
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '현재 세입자가 있나요? *',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2C3E50),
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
                    activeThumbColor: AppColors.kPrimary,
                  ),
                  Text(
                    hasTenant ? '있음' : '없음',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: '희망 거래가',
                controller: _desiredPriceController,
                hint: '예: 11억 / 협의 가능',
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: '기타 요청사항 (300자 이내)',
                controller: _specialNotesController,
                hint: '추가로 궁금하신 점이나 특별히 확인하고 싶은 사항을 자유롭게 적어주세요',
                maxLines: 8,
                maxLength: 300,
              ),
            ]),
            
            const SizedBox(height: 24),
            Divider(color: Colors.grey[300], thickness: 1, height: 1),
            const SizedBox(height: 24),
            
            // 🔥 게스트 모드일 때만 연락처 입력 섹션 표시
            if (widget.userId.isEmpty) ...[
              _buildSectionTitle('연락처 정보', '상담 요청 및 보안 강화를 위해 필요합니다', Colors.orange),
              const SizedBox(height: 12),
              _buildCard([
                _buildTextField(
                  label: '이메일 *',
                  controller: _emailController,
                  hint: '예: user@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이메일을 입력해주세요';
                    }
                    if (!ValidationUtils.isValidEmail(value)) {
                      return '올바른 이메일 형식을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: '전화번호 *',
                  controller: _phoneController,
                  hint: '예: 01012345678',
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '전화번호를 입력해주세요';
                    }
                    final cleanPhone = value.replaceAll('-', '').replaceAll(' ', '').trim();
                    if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(cleanPhone)) {
                      return '올바른 전화번호 형식을 입력해주세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '공인중개사의 상담 응답을 받을 연락처를 적어주세요.\n상담 이후 응답은 내집관리에서 확인 가능합니다.',
                          style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Divider(color: Colors.grey[300], thickness: 1, height: 1),
              const SizedBox(height: 24),
            ],
            
            // 제출 버튼
            // 동의 체크
            _buildCard([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreeToConsent,
                    onChanged: (v) => setState(() => _agreeToConsent = v ?? false),
                    activeColor: AppColors.kPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          '개인정보 제3자 제공 동의 (필수)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '선택한 공인중개사에게 문의 처리 목적의 최소한의 정보가 제공됩니다. '
                          '자세한 내용은 내 정보 > 정책 및 도움말에서 확인할 수 있습니다.',
                          style: TextStyle(fontSize: 12, color: AppColors.kTextSecondary, height: 1.5),
                        ),
                            SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 16),
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
                  backgroundColor: AppColors.kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6, // 그림자 강화
                  shadowColor: AppColors.kPrimary.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.send, size: 24),
                label: const Text(
                  '견적 요청하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
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
  
  // 공통 빌더 메서드
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
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
        border: Border.all(color: Colors.grey[300]!, width: 1),
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
    String? Function(String?)? validator,
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
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
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
              borderSide: const BorderSide(color: AppColors.kPrimary, width: 2.5),
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
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value 
              ? AppColors.kPrimary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value 
                ? AppColors.kPrimary
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
                    color: value ? AppColors.kPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: value ? AppColors.kPrimary : Colors.grey.withValues(alpha: 0.5),
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
                      color: value ? const Color(0xFF1A1A1A) : AppColors.kPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
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
    
    // 🔥 게스트 모드일 때 이메일/전화번호 검증
    final isGuestMode = widget.userId.isEmpty;
    String? userEmail;
    String? userPhone;
    String effectiveUserId = widget.userId.isNotEmpty ? widget.userId : widget.userName;
    String effectiveUserName = widget.userName;
    
    if (isGuestMode) {
      // 이메일 검증
      userEmail = _emailController.text.trim();
      if (userEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이메일을 입력해주세요'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!ValidationUtils.isValidEmail(userEmail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('올바른 이메일 형식을 입력해주세요'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 전화번호 검증
      userPhone = _phoneController.text.replaceAll('-', '').replaceAll(' ', '').trim();
      if (userPhone.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전화번호를 입력해주세요'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(userPhone)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('올바른 전화번호 형식을 입력해주세요'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // 계정 자동 생성/로그인
      try {
        final id = userEmail.split('@')[0];
        final password = userPhone; // 전화번호를 비밀번호로 사용
        
        // 계정 존재 여부 확인 (로그인 시도)
        try {
          final userData = await _firebaseService.authenticateUser(userEmail, password);
          if (userData != null) {
            // 로그인 성공 = 계정이 이미 존재
            effectiveUserId = userData['uid'] as String;
            effectiveUserName = userData['name'] as String? ?? id;
            // Analytics: 기존 계정 로그인
            AnalyticsService.instance.logEvent(
              AnalyticsEventNames.implicitAccountLogin,
              params: {'email': userEmail, 'source': 'quote_request_form'},
              userId: effectiveUserId,
              userName: effectiveUserName,
            );
          }
        } catch (e) {
          // 로그인 실패 = 계정이 없음, 새로 생성
          final success = await _firebaseService.registerUser(
            id,
            password,
            id,
            email: userEmail,
            phone: userPhone,
            role: 'user',
          );
          
          if (success) {
            // 생성 후 자동 로그인
            final userData = await _firebaseService.authenticateUser(userEmail, password);
            if (userData != null) {
              effectiveUserId = userData['uid'] as String;
              effectiveUserName = userData['name'] as String? ?? id;
              // Analytics: 새 계정 생성 성공
              AnalyticsService.instance.logEvent(
                AnalyticsEventNames.implicitAccountCreated,
                params: {'email': userEmail, 'source': 'quote_request_form'},
                userId: effectiveUserId,
                userName: effectiveUserName,
              );
            }
          } else {
            // 🔥 계정 생성 실패 (이미 존재할 수 있음, 다시 로그인 시도)
            try {
              final userData = await _firebaseService.authenticateUser(userEmail, password);
              if (userData != null) {
                effectiveUserId = userData['uid'] as String;
                effectiveUserName = userData['name'] as String? ?? id;
                // Analytics: 계정 생성 실패 후 재로그인 성공
                AnalyticsService.instance.logEvent(
                  AnalyticsEventNames.implicitAccountLogin,
                  params: {
                    'email': userEmail,
                    'source': 'quote_request_form',
                    'retryAfterCreation': true,
                  },
                  userId: effectiveUserId,
                  userName: effectiveUserName,
                );
                // 재로그인 성공, 계속 진행
              } else {
                // 로그인도 실패한 경우
                // Analytics: 계정 생성 및 로그인 모두 실패
                AnalyticsService.instance.logEvent(
                  AnalyticsEventNames.implicitAccountCreationFailed,
                  params: {
                    'email': userEmail,
                    'source': 'quote_request_form',
                    'reason': 'both_failed',
                  },
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('계정 생성 및 로그인에 실패했습니다. 다시 시도해주세요.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            } catch (loginError) {
              // 로그인 시도도 실패
              // Analytics: 계정 생성 및 로그인 모두 실패
              AnalyticsService.instance.logEvent(
                AnalyticsEventNames.implicitAccountCreationFailed,
                params: {
                  'email': userEmail,
                  'source': 'quote_request_form',
                  'reason': 'both_failed',
                },
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('계정 생성 및 로그인에 실패했습니다. 다시 시도해주세요.'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // 정식 로그인 사용자
      userEmail = await _getUserEmail();
      final userData = await _firebaseService.getUser(widget.userId);
      userPhone = userData?['phone'] as String?;
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
    
    // userEmail이 null이면 오류
    if (userEmail == null || userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이메일 정보를 가져올 수 없습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 견적문의 객체 생성
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
      targetPeriod: null, // 목표기간은 전자계약 이후 단계에서 사용
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
            title: '제안 요청이 전송되었습니다',
            description: '${widget.broker.name}에게 요청을 보냈습니다.\n답변이 도착하면 현황에서 확인할 수 있어요.',
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
          content: Text('제안 요청 전송에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


