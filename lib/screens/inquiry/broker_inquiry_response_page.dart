import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:property/api_request/firebase_service.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/api_request/apt_info_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/api_request/address_service.dart';
import 'package:flutter/services.dart';
import 'package:property/utils/transaction_type_helper.dart';

/// 공인중개사용 문의 답변 페이지
class BrokerInquiryResponsePage extends StatefulWidget {
  final String linkId;

  const BrokerInquiryResponsePage({
    required this.linkId,
    super.key,
  });

  @override
  State<BrokerInquiryResponsePage> createState() => _BrokerInquiryResponsePageState();
}

class _BrokerInquiryResponsePageState extends State<BrokerInquiryResponsePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _answerController = TextEditingController();
  final TextEditingController _recommendedPriceController = TextEditingController();
  final TextEditingController _commissionRateController = TextEditingController();
  final TextEditingController _expectedDurationController = TextEditingController();
  final TextEditingController _promotionMethodController = TextEditingController();
  final TextEditingController _recentCasesController = TextEditingController();
  
  Map<String, dynamic>? _inquiryData;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasExistingAnswer = false; // 기존 답변 존재 여부 (수정 가능하도록 변경)
  
  // API 정보
  Map<String, dynamic>? _vworldCoordinates;
  Map<String, dynamic>? _aptInfo;
  Map<String, String>? _fullAddrAPIData;
  String? _kaptCode;
  bool _isLoadingApiInfo = false;

  @override
  void initState() {
    super.initState();
    _loadInquiry();
  }
  
  /// 주소 검색 API 정보 로드 (캐시 우선)
  Future<void> _loadApiInfo(String? address) async {
    if (address == null || address.isEmpty) {
      return;
    }

    // 캐시 상태 확인
    final hadFullAddr = _fullAddrAPIData != null && _fullAddrAPIData!.isNotEmpty;
    final hadCoords = _vworldCoordinates != null && _vworldCoordinates!.isNotEmpty;
    final hadAptInfo = _aptInfo != null && _aptInfo!.isNotEmpty;
    final hadKaptCode = _kaptCode != null && _kaptCode!.isNotEmpty;
    final hadAll = hadFullAddr && hadCoords && hadAptInfo;

    setState(() {
      _isLoadingApiInfo = true;
    });
    
    try {
      if (!hadAll) {
        final addressService = AddressService();
        bool hasAnyData = false;
        List<String> errors = [];

        // 1. 주소 상세 정보 조회 (AddressService) - 없는 경우에만
        if (!hadFullAddr) {
          try {
            final addrResult = await addressService.searchRoadAddress(address, page: 1);
            if (addrResult.fullData.isNotEmpty) {
              _fullAddrAPIData = addrResult.fullData.first;
              hasAnyData = true;
            }
          } catch (e) {
            errors.add('주소 상세 정보 조회 실패: $e');
          }
        }
        
        // 2. VWorld 좌표 정보 조회 - 없는 경우에만
        if (!hadCoords) {
          try {
            final landResult = await VWorldService.getLandInfoFromAddress(address);
            if (landResult != null && landResult['coordinates'] != null) {
              _vworldCoordinates = landResult['coordinates'];
              hasAnyData = true;
            } else {
              errors.add('VWorld 좌표 정보 조회 결과 없음');
            }
          } catch (e) {
            errors.add('VWorld 좌표 조회 실패: $e');
          }
        }
        
        // 3. 아파트 정보 조회 (단지코드 추출 시도) - 없는 경우에만
        if (!hadAptInfo) {
          try {
            final extraction = await AptInfoService.extractKaptCodeFromAddressAsync(
              address,
              fullAddrAPIData: _fullAddrAPIData,
            );
            if (extraction.isSuccess) {
              final kaptCode = extraction.code!;
              _kaptCode = kaptCode;
              final aptInfoResult = await AptInfoService.getAptBasisInfo(kaptCode);
              if (aptInfoResult != null && aptInfoResult.isNotEmpty) {
                _aptInfo = aptInfoResult;
                hasAnyData = true;
              } else {
                errors.add('아파트 정보 조회 결과 없음');
              }
            } else {
              errors.add('단지코드 추출 실패: ${extraction.message}');
            }
          } catch (e) {
            errors.add('아파트 정보 조회 실패: $e');
          }
        }

        // 신규 확보 데이터가 있고, 기존에 없던 필드만 Firestore에 저장
        if (_inquiryData != null) {
          final reqId = _inquiryData!['id'];
          final shouldPersistFull = !hadFullAddr && _fullAddrAPIData != null && _fullAddrAPIData!.isNotEmpty;
          final shouldPersistCoords = !hadCoords && _vworldCoordinates != null && _vworldCoordinates!.isNotEmpty;
          final shouldPersistApt = !hadAptInfo && _aptInfo != null && _aptInfo!.isNotEmpty;
          final shouldPersistKapt = !hadKaptCode && _kaptCode != null && _kaptCode!.isNotEmpty;

          if ((shouldPersistFull || shouldPersistCoords || shouldPersistApt || shouldPersistKapt) && reqId != null) {
            await _firebaseService.updateQuoteRequestApiCache(
              requestId: reqId,
              fullAddrAPIData: shouldPersistFull ? _fullAddrAPIData : null,
              vworldCoordinates: shouldPersistCoords ? _vworldCoordinates : null,
              kaptCode: shouldPersistKapt ? _kaptCode : null,
              aptInfo: shouldPersistApt ? _aptInfo : null,
            );
          }
        }

        if (!hasAnyData && errors.isNotEmpty) {
          // 실패 정보는 화면에 표시하지 않고 내부적으로만 유지
        }
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
        });
      }
    }
  }

  Widget _buildLabeledValue(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.kPrimary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.kPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[800]),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

class _GuideBulletWidget extends StatelessWidget {
  final String text;

  const _GuideBulletWidget({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12, color: Color(0xFF374151))),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF374151), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _loadInquiry() async {
    setState(() => _isLoading = true);

    try {
      final data = await _firebaseService.getQuoteRequestByLinkId(widget.linkId);
      
      if (data == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      setState(() {
        _inquiryData = data;
        _isLoading = false;
        // 저장된 주소/좌표/단지 캐시를 반영
        final fullAddr = data['fullAddrAPIData'];
        if (fullAddr is Map) {
          _fullAddrAPIData = fullAddr.cast<String, String>();
        }
        final coords = data['vworldCoordinates'];
        if (coords is Map) {
          _vworldCoordinates = coords.cast<String, dynamic>();
        }
        final apt = data['aptInfo'];
        if (apt is Map) {
          _aptInfo = apt.cast<String, dynamic>();
        }
        final kapt = data['kaptCode'];
        if (kapt is String) {
          _kaptCode = kapt;
        }
        // 이미 답변이 있으면 표시하고 수정 가능하도록
        if (data['brokerAnswer'] != null && data['brokerAnswer'].toString().isNotEmpty) {
          _hasExistingAnswer = true;
          _answerController.text = data['brokerAnswer'];
        }
        // 구조화 필드 프리필
        _recommendedPriceController.text = data['recommendedPrice']?.toString() ?? '';
        _commissionRateController.text = data['commissionRate']?.toString() ?? '';
        _expectedDurationController.text = data['expectedDuration']?.toString() ?? '';
        _promotionMethodController.text = data['promotionMethod']?.toString() ?? '';
        _recentCasesController.text = data['recentCases']?.toString() ?? '';
      });
      
      // 주소가 있으면 API 정보 로드
      final propertyAddress = data['propertyAddress'];
      if (propertyAddress != null && propertyAddress.toString().isNotEmpty) {
        final address = propertyAddress.toString();
        debugPrint('문의 답변 페이지 - API 정보 로드 시작: $address');
        _loadApiInfo(address);
      } else {
        debugPrint('문의 답변 페이지 - 매물 주소가 없습니다.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('문의 정보를 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _submitAnswer() async {
    final hasAnyField = _answerController.text.trim().isNotEmpty ||
        _recommendedPriceController.text.trim().isNotEmpty ||
        _commissionRateController.text.trim().isNotEmpty ||
        _expectedDurationController.text.trim().isNotEmpty ||
        _promotionMethodController.text.trim().isNotEmpty ||
        _recentCasesController.text.trim().isNotEmpty;
    if (!hasAnyField) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 한 개 이상의 답변 항목을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await _firebaseService.updateQuoteRequestDetailedAnswer(
        requestId: _inquiryData!['id'],
        recommendedPrice: _recommendedPriceController.text.trim(),
        commissionRate: _commissionRateController.text.trim(),
        expectedDuration: _expectedDurationController.text.trim(),
        promotionMethod: _promotionMethodController.text.trim(),
        recentCases: _recentCasesController.text.trim(),
        brokerAnswer: _answerController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        
        if (success) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(_hasExistingAnswer ? '✅ 답변 수정 완료' : '✅ 답변 전송 완료'),
              content: Text(
                _hasExistingAnswer 
                  ? '답변이 성공적으로 수정되었습니다.\n'
                    '문의자에게 수정된 답변이 즉시 전달됩니다.'
                  : '답변이 성공적으로 전송되었습니다.\n'
                    '문의자에게 답변이 즉시 전달됩니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
          
          // 기존 답변 상태로 변경 및 데이터 다시 로드
          setState(() => _hasExistingAnswer = true);
          await _loadInquiry();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('답변 전송에 실패했습니다. 다시 시도해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = kIsWeb;
    final maxContentWidth = isWeb ? 900.0 : screenWidth;
    
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('문의 정보를 불러오는 중...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_inquiryData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('문의 정보'),
          backgroundColor: AppColors.kPrimary,
        ),
        body: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('문의를 찾을 수 없습니다.'),
                SizedBox(height: 8),
                Text(
                  '링크가 만료되었거나 잘못된 접근입니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final quoteRequest = QuoteRequest.fromMap(_inquiryData!['id'], _inquiryData!);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('문의 답변'),
          backgroundColor: AppColors.kPrimary,
          foregroundColor: Colors.white,
        ),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewInsets = MediaQuery.of(context).viewInsets;
                  final actualHeight = constraints.maxHeight - viewInsets.bottom;
                  
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.all(isWeb ? 40.0 : 20.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: actualHeight - 40,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
            // 안내 메시지
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.kPrimary.withValues(alpha: 0.1), AppColors.kSecondary.withValues(alpha: 0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.kPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: AppColors.kPrimary, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '문의 내용을 확인하고 답변을 작성해주세요.\n답변은 즉시 문의자에게 전달됩니다.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 문의 정보 (가독성 강화 카드)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.kPrimary.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_pin_circle, color: AppColors.kPrimary, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        '문의 정보',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.kPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.flash_on, size: 14, color: AppColors.kPrimary),
                            SizedBox(width: 6),
                            Text(
                              '중요 정보',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.kPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildLabeledValue('문의자', quoteRequest.userName, Icons.person_outline),
                  const SizedBox(height: 8),
                  _buildLabeledValue('이메일', quoteRequest.userEmail, Icons.mail_outline),
                  if (quoteRequest.propertyAddress != null) ...[
                    const SizedBox(height: 12),
                    _buildLabeledValue('매물 주소', quoteRequest.propertyAddress!, Icons.location_on_outlined),
                  ],
                  if (quoteRequest.propertyArea != null || quoteRequest.propertyType != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (quoteRequest.propertyArea != null)
                          _buildTagChip(Icons.square_foot, '${quoteRequest.propertyArea}㎡'),
                        if (quoteRequest.propertyType != null)
                          _buildTagChip(Icons.home_work_outlined, quoteRequest.propertyType!),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 특이사항 (입력된 경우에만 표시) - 답변 작성 바로 위에 배치하여 참고하기 쉽게
            if (quoteRequest.hasTenant != null || 
                quoteRequest.desiredPrice != null || 
                quoteRequest.targetPeriod != null || 
                (quoteRequest.specialNotes != null && quoteRequest.specialNotes!.isNotEmpty))
              ...[
                const SizedBox(height: 24),
                _buildSection(
                  title: '📝 특이사항 (답변 작성시 참고하세요)',
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (quoteRequest.hasTenant != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '세입자 여부',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      quoteRequest.hasTenant! ? '있음' : '없음',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (quoteRequest.desiredPrice != null && quoteRequest.desiredPrice!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '희망가',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      quoteRequest.desiredPrice!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (quoteRequest.targetPeriod != null && quoteRequest.targetPeriod!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '목표기간',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      quoteRequest.targetPeriod!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (quoteRequest.specialNotes != null && quoteRequest.specialNotes!.isNotEmpty) ...[
                            if (quoteRequest.hasTenant != null || 
                                quoteRequest.desiredPrice != null || 
                                quoteRequest.targetPeriod != null)
                              const Divider(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    '특이사항',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    quoteRequest.specialNotes!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2C3E50),
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            
            const SizedBox(height: 24),
            
            // 답변 작성 (수정 가능)
            _buildSection(
              title: _hasExistingAnswer ? '✏️ 답변 수정 (재전송 가능)' : '✏️ 답변 작성',
              children: [
                // 구조화 입력 필드
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildLabeledField(
                        TransactionTypeHelper.getAppropriatePriceLabel(quoteRequest.transactionType ?? '매매'),
                        _recommendedPriceController,
                        hint: '예: 10.8',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        suffix: '억',
                      ),
                      const SizedBox(height: 12),
                      _buildLabeledField(
                        '수수료는 얼마인가요?',
                        _commissionRateController,
                        hint: '예: 0.6',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        suffix: '%',
                      ),
                      const SizedBox(height: 12),
                      _buildLabeledField('거래 기간은 얼마나 걸릴까요?', _expectedDurationController, hint: '예: 2~3개월'),
                      const SizedBox(height: 12),
                      _buildLabeledField('어떻게 홍보하시나요?', _promotionMethodController, hint: '예: 빠른 오픈, 네이버/당근/현수막 병행', maxLines: 3),
                      const SizedBox(height: 12),
                      _buildLabeledField('비슷한 거래 사례가 있나요?', _recentCasesController, hint: '예: 인근 A아파트 84㎡, 10.7억(23.12)', maxLines: 3),
                    ],
                  ),
                ),
                if (quoteRequest.hasTenant != null || 
                    quoteRequest.desiredPrice != null || 
                    quoteRequest.targetPeriod != null || 
                    (quoteRequest.specialNotes != null && quoteRequest.specialNotes!.isNotEmpty))
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.kPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: AppColors.kPrimary, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '위 특이사항을 참고하여 답변을 작성해주세요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.kPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_hasExistingAnswer)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '기존 답변을 수정한 후 다시 전송할 수 있습니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.edit_note, size: 22, color: AppColors.kPrimary),
                          SizedBox(width: 8),
                          Text(
                            '답변 작성',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '고객님이 확인할 답변을 작성해주세요. (예: 적정 거래가 제안, 수수료, 예상 기간, 진행 방식 등)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _GuideBulletWidget(text: '제안 이유와 근거를 간단히 적어주세요.'),
                            _GuideBulletWidget(text: '진행 일정(예: 방문/계약 예상 시점)을 알려주세요.'),
                            _GuideBulletWidget(text: '연락 가능 시간이나 추가 문의 채널을 남겨주세요.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _answerController,
                        maxLines: 8,
                        enabled: true, // 항상 수정 가능
                        decoration: InputDecoration(
                          hintText: '예) 10.8억에 제안드립니다. 인근 84㎡ 최근 거래가 10.6~10.9억이며, 현 시세 대비 빠른 의사결정 시 2~3개월 내 계약 가능성이 높습니다. 수수료 0.6%, 추가로 오픈마켓/당근/현수막 병행 홍보 예정입니다.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 전송/재전송 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasExistingAnswer ? Colors.blue : AppColors.kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_hasExistingAnswer ? Icons.refresh : Icons.send, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _hasExistingAnswer ? '수정 후 재전송' : '전송하기',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.kPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLabeledField(String label, TextEditingController controller, {
    String? hint, 
    TextInputType? keyboardType, 
    String? suffix,
    int? maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines ?? 1,
          inputFormatters: keyboardType == const TextInputType.numberWithOptions(decimal: true)
              ? <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\%]')),
                ]
              : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixText: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledValue(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.kPrimary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.kPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTagChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[800]),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
  
}

