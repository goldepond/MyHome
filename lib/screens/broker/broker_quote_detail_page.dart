import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/api_request/apt_info_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/api_request/address_service.dart';
import 'package:property/widgets/broker_quote/api_reference_info_card.dart';
import 'package:property/widgets/broker_quote/property_info_card.dart';
import 'package:property/widgets/broker_quote/request_info_card.dart';
import 'package:property/widgets/broker_quote/selected_quote_card.dart';
import 'package:property/screens/broker/property_registration_form_page.dart';
import 'package:property/utils/transaction_type_helper.dart';

/// 공인중개사 견적 상세/답변 페이지
class BrokerQuoteDetailPage extends StatefulWidget {
  final QuoteRequest quote;
  final Map<String, dynamic> brokerData;

  const BrokerQuoteDetailPage({
    required this.quote,
    required this.brokerData,
    super.key,
  });

  @override
  State<BrokerQuoteDetailPage> createState() => _BrokerQuoteDetailPageState();
}

class _BrokerQuoteDetailPageState extends State<BrokerQuoteDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _recommendedPriceController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _brokerAnswerController = TextEditingController();

  bool _isSubmitting = false;
  bool _isRegistered = false; // 매물 등록 여부 로컬 상태
  final FirebaseService _firebaseService = FirebaseService();
  
  // API 정보
  Map<String, dynamic>? _vworldCoordinates;
  Map<String, dynamic>? _aptInfo;
  Map<String, String>? _fullAddrAPIData;
  bool _isLoadingApiInfo = false;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    
    // 매물 등록 여부 초기화
    _isRegistered = widget.quote.isPropertyRegistered == true;

    // 기존 답변 있으면 자동 채우기
    if (widget.quote.recommendedPrice != null) {
      _recommendedPriceController.text = widget.quote.recommendedPrice!;
    }
    if (widget.quote.commissionRate != null) {
      _commissionRateController.text = widget.quote.commissionRate!;
    }
    if (widget.quote.brokerAnswer != null) {
      _brokerAnswerController.text = widget.quote.brokerAnswer!;
    }
    
    // 주소가 있으면 API 정보 로드
    if (widget.quote.propertyAddress != null && widget.quote.propertyAddress!.isNotEmpty) {
      _loadApiInfo();
    }
  }
  
  /// 주소 검색 API 정보 로드
  Future<void> _loadApiInfo() async {
    if (widget.quote.propertyAddress == null || widget.quote.propertyAddress!.isEmpty) {
      return;
    }
    
    setState(() {
      _isLoadingApiInfo = true;
      _apiError = null;
    });
    
    try {
      final address = widget.quote.propertyAddress!;
      final addressService = AddressService();
      
      // 1. 주소 상세 정보 조회 (AddressService)
      try {
        final addrResult = await addressService.searchRoadAddress(address, page: 1);
        if (addrResult.fullData.isNotEmpty) {
          _fullAddrAPIData = addrResult.fullData.first;
        }
      } catch (e) {
        // 주소 상세 정보 조회 실패는 무시
      }
      
      // 2. VWorld 좌표 정보 조회
      try {
        final landResult = await VWorldService.getLandInfoFromAddress(address);
        if (landResult != null && landResult['coordinates'] != null) {
          _vworldCoordinates = landResult['coordinates'];
        }
      } catch (e) {
        // VWorld 좌표 조회 실패는 무시
      }
      
      // 3. 아파트 정보 조회 (단지코드 추출 시도)
      try {
        final extraction = await AptInfoService.extractKaptCodeFromAddressAsync(
          address,
          fullAddrAPIData: _fullAddrAPIData,
        );
        if (extraction.isSuccess) {
          final kaptCode = extraction.code!;
          final aptInfoResult = await AptInfoService.getAptBasisInfo(kaptCode);
          if (aptInfoResult != null) {
            _aptInfo = aptInfoResult;
          }
        }
      } catch (e) {
        // 아파트 정보 조회 실패는 무시
      }
      
      if (mounted) {
        setState(() {
          _isLoadingApiInfo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingApiInfo = false;
          _apiError = 'API 정보를 불러오는 중 오류가 발생했습니다.';
        });
      }
    }
  }

  @override
  void dispose() {
    _recommendedPriceController.dispose();
    _commissionRateController.dispose();
    _brokerAnswerController.dispose();
    super.dispose();
  }

  Future<void> _registerProperty() async {
    // 매물 등록 폼 페이지로 이동
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyRegistrationFormPage(
          quote: widget.quote,
          brokerData: widget.brokerData,
          aptInfo: _aptInfo,
          vworldCoordinates: _vworldCoordinates,
          fullAddrAPIData: _fullAddrAPIData,
        ),
      ),
    );

    // 등록 완료 시 상태 업데이트
    if (result == true && mounted) {
      setState(() {
        _isRegistered = true;
      });
    }
  }

  Future<void> _submitAnswer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 중개 수수료는 반드시 입력
    if (_commissionRateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('수수료를 알려주시면 좋을 것 같아요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 적정 거래가 또는 추가 메시지 중 하나는 입력
    final hasAnyInput = _recommendedPriceController.text.trim().isNotEmpty ||
        _brokerAnswerController.text.trim().isNotEmpty;

    if (!hasAnyInput) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('적정 거래가나 추가 메시지 중 하나는 작성해주시면 감사하겠습니다'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _firebaseService.updateQuoteRequestDetailedAnswer(
        requestId: widget.quote.id,
        recommendedPrice: _recommendedPriceController.text.trim().isNotEmpty
            ? _recommendedPriceController.text.trim()
            : null,
        commissionRate: _commissionRateController.text.trim().isNotEmpty
            ? _commissionRateController.text.trim()
            : null,
        brokerAnswer: _brokerAnswerController.text.trim().isNotEmpty
            ? _brokerAnswerController.text.trim()
            : null,
      );

      setState(() {
        _isSubmitting = false;
      });

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 답변이 성공적으로 전송되었습니다!'),
            backgroundColor: AppColors.kSuccess,
          ),
        );
        Navigator.pop(context, true); // 성공 반환
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('답변 전송에 문제가 있었어요. 잠시 후 다시 시도해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 레이아웃: PC 화면 고려
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1200.0 : screenWidth;
    final horizontalPadding = isWeb ? 24.0 : 16.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: AppColors.kBackground,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.kPrimary,
        elevation: 0.5,
        title: const HomeLogoButton(
          fontSize: 18,
          color: AppColors.kPrimary,
        ),
      ),
      body: Form(
        key: _formKey,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewInsets = MediaQuery.of(context).viewInsets;
                final actualHeight = constraints.maxHeight - viewInsets.bottom;
                
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: actualHeight - 48,
                    ),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // 1. 선택된 견적 카드 (조건부 표시)
              if (widget.quote.isSelectedByUser == true)
                SelectedQuoteCard(
                  quote: widget.quote,
                  isSubmitting: _isSubmitting,
                  isRegistered: _isRegistered,
                  onRegisterPressed: _registerProperty,
                ),

              // 2. 요청자 정보 카드
              RequestInfoCard(quote: widget.quote),

              const SizedBox(height: 24),

              // 3. 매물 정보 카드
              PropertyInfoCard(quote: widget.quote),

              const SizedBox(height: 24),

              // 4. API 참조 정보 섹션 (매물정보 바로 아래에 표시)
              if (widget.quote.propertyAddress != null && widget.quote.propertyAddress!.isNotEmpty)
                ApiReferenceInfoCard(
                  isLoading: _isLoadingApiInfo,
                  apiError: _apiError,
                  fullAddrAPIData: _fullAddrAPIData,
                  vworldCoordinates: _vworldCoordinates,
                  aptInfo: _aptInfo,
                ),

              const SizedBox(height: 24),

              // 5. 답변 입력 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.reply, color: AppColors.kPrimary, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          '상담 답변 작성',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '전하고 싶은 내용을 정리해 남겨주세요.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      label: TransactionTypeHelper.getAppropriatePriceLabel(widget.quote.transactionType ?? '매매'),
                      controller: _recommendedPriceController,
                      hint: '예: 11억 5천만원',
                      icon: Icons.attach_money,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '중개 수수료',
                      controller: _commissionRateController,
                      hint: '예: 0.5%',
                      icon: Icons.percent,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '추가로 전달하고 싶은 내용',
                      controller: _brokerAnswerController,
                      hint: '예) 진행 희망 시점, 연락 가능 시간, 추가로 남길 요청 사항을 적어주세요.',
                      icon: Icons.note,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 6. 하단 버튼 (진행 안함 / 답변 전송)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('이번 건은 보류할까요?'),
                                    content: const Text(
                                      '이 상담 요청은 이번에는 진행하지 않으시겠습니까?\n'
                                      '고객님 화면에서는 \'보류됨\'으로 표시됩니다.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('취소'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('보류하기'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  setState(() {
                                    _isSubmitting = true;
                                  });
                                  final success =
                                      await _firebaseService.updateQuoteRequestStatus(
                                    widget.quote.id,
                                    'cancelled',
                                  );
                                  if (!mounted) return;
                                  setState(() {
                                    _isSubmitting = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? '이번 건은 진행하지 않도록 표시했어요.'
                                            : '처리 중 문제가 발생했어요. 잠시 후 다시 시도해주세요.',
                                      ),
                                      backgroundColor:
                                          success ? AppColors.kInfo : Colors.red,
                                    ),
                                  );
                                  if (success) {
                                    Navigator.pop(context);
                                  }
                                }
                              },
                        icon: const Icon(
                          Icons.block,
                          size: 20,
                          color: Colors.red,
                        ),
                        label: const Text(
                          '보류하기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitAnswer,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send, size: 24),
                        label: Text(
                          _isSubmitting ? '전송 중...' : '답변 보내기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
                ],
              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.withValues(alpha: 0.05),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 14,
            ),
          ),
          maxLines: maxLines,
        ),
      ],
    );
  }
}
