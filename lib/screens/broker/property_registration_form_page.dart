import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/storage_service.dart';
import 'package:property/utils/quote_utils.dart';
import 'package:property/widgets/broker_quote/api_reference_info_card.dart';

/// 매물 등록 폼 페이지
/// 공인중개사가 견적 요청을 바탕으로 매물을 등록하기 전에 정보를 입력하는 페이지
class PropertyRegistrationFormPage extends StatefulWidget {
  final QuoteRequest quote;
  final Map<String, dynamic> brokerData;
  final Map<String, dynamic>? aptInfo; // 아파트 단지 정보
  final Map<String, dynamic>? vworldCoordinates; // 좌표 정보
  final Map<String, String>? fullAddrAPIData; // 주소 상세 정보

  const PropertyRegistrationFormPage({
    required this.quote,
    required this.brokerData,
    this.aptInfo,
    this.vworldCoordinates,
    this.fullAddrAPIData,
    super.key,
  });

  @override
  State<PropertyRegistrationFormPage> createState() => _PropertyRegistrationFormPageState();
}

class _PropertyRegistrationFormPageState extends State<PropertyRegistrationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  final StorageService _storageService = StorageService();

  // 거래 유형
  String _transactionType = '매매'; // 매매, 전세, 월세

  // 가격 관련
  final TextEditingController _salePriceController = TextEditingController(); // 매매가
  final TextEditingController _monthlyRentController = TextEditingController(); // 월세
  final TextEditingController _depositController = TextEditingController(); // 전세 보증금
  bool _isNegotiable = false; // 협의 가능 여부

  // 아파트 단지 정보 (수정 가능)
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _buildingTypeController = TextEditingController();
  final TextEditingController _totalFloorsController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _structureController = TextEditingController();
  final TextEditingController _buildingYearController = TextEditingController();

  // 추가 정보
  final TextEditingController _descriptionController = TextEditingController();

  // 사진 첨부 (선택)
  List<XFile> _selectedImages = [];
  List<String> _uploadedImageUrls = []; // 업로드된 이미지 URL
  bool _isUploadingImages = false;

  bool _isSubmitting = false;
  bool _isSavingDraft = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    // 임시 저장 데이터 불러오기 (비동기)
    _loadDraft();
  }

  /// 임시 저장 데이터 불러오기
  Future<void> _loadDraft() async {
    try {
      final draft = await _firebaseService.getPropertyRegistrationDraft(widget.quote.id);
      if (draft != null && mounted) {
        setState(() {
          // 거래 유형
          if (draft['transactionType'] != null) {
            _transactionType = draft['transactionType'] as String;
          }

          // 가격 정보
          if (draft['salePrice'] != null) {
            _salePriceController.text = draft['salePrice'] as String;
          }
          if (draft['monthlyRent'] != null) {
            _monthlyRentController.text = draft['monthlyRent'] as String;
          }
          if (draft['deposit'] != null) {
            _depositController.text = draft['deposit'] as String;
          }
          if (draft['isNegotiable'] != null) {
            _isNegotiable = draft['isNegotiable'] as bool;
          }

          // 아파트 정보
          if (draft['buildingName'] != null) {
            _buildingNameController.text = draft['buildingName'] as String;
          }
          if (draft['buildingType'] != null) {
            _buildingTypeController.text = draft['buildingType'] as String;
          }
          if (draft['totalFloors'] != null) {
            _totalFloorsController.text = draft['totalFloors'] as String;
          }
          if (draft['floor'] != null) {
            _floorController.text = draft['floor'] as String;
          }
          if (draft['area'] != null) {
            _areaController.text = draft['area'] as String;
          }
          if (draft['structure'] != null) {
            _structureController.text = draft['structure'] as String;
          }
          if (draft['buildingYear'] != null) {
            _buildingYearController.text = draft['buildingYear'] as String;
          }

          // 설명
          if (draft['description'] != null) {
            _descriptionController.text = draft['description'] as String;
          }
        });
      }
    } catch (e) {
      // 임시 저장 데이터 불러오기 실패는 무시
    }
  }

  /// 폼 초기화 - 견적 요청 정보와 아파트 단지 정보를 기본값으로 설정
  void _initializeForm() {
    // 거래 유형 기본값 (매매)
    _transactionType = '매매';

    // 가격 정보 초기화
    if (widget.quote.recommendedPrice != null && widget.quote.recommendedPrice!.isNotEmpty) {
      final price = QuoteUtils.extractPrice(widget.quote.recommendedPrice);
      if (price != null) {
        _salePriceController.text = _formatPrice(price);
      } else {
        _salePriceController.text = widget.quote.recommendedPrice!;
      }
    }

    // 면적 정보
    if (widget.quote.propertyArea != null) {
      final area = QuoteUtils.extractArea(widget.quote.propertyArea!);
      if (area != null) {
        _areaController.text = area.toStringAsFixed(2);
      } else {
        _areaController.text = widget.quote.propertyArea!;
      }
    }

    // 아파트 단지 정보 초기화
    if (widget.aptInfo != null) {
      _buildingNameController.text = widget.aptInfo!['kaptName'] ?? '';
      _buildingTypeController.text = widget.quote.propertyType ?? '아파트';
      _totalFloorsController.text = widget.aptInfo!['kaptdCntTot']?.toString() ?? '';
      _structureController.text = widget.aptInfo!['kaptdWtimeType'] ?? '';
      _buildingYearController.text = widget.aptInfo!['codeSaleNm'] ?? '';
    } else {
      // 아파트 정보가 없으면 견적 요청 정보만 사용
      _buildingTypeController.text = widget.quote.propertyType ?? '아파트';
    }

    // 설명 초기화
    if (widget.quote.brokerAnswer != null && widget.quote.brokerAnswer!.isNotEmpty) {
      _descriptionController.text = widget.quote.brokerAnswer!;
    }
  }

  /// 가격 포맷팅 (원 단위)
  String _formatPrice(int price) {
    if (price >= 100000000) {
      return '${(price / 100000000).toStringAsFixed(1)}억원';
    } else if (price >= 10000) {
      return '${(price / 10000).toStringAsFixed(0)}만원';
    }
    return '$price원';
  }

  /// 가격 파싱 (문자열에서 숫자 추출)
  int? _parsePrice(String priceStr) {
    if (priceStr.trim().isEmpty) return null;
    
    // 숫자만 추출
    final numbers = priceStr.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.isEmpty) return null;
    
    return int.tryParse(numbers);
  }

  @override
  void dispose() {
    _salePriceController.dispose();
    _monthlyRentController.dispose();
    _depositController.dispose();
    _buildingNameController.dispose();
    _buildingTypeController.dispose();
    _totalFloorsController.dispose();
    _floorController.dispose();
    _areaController.dispose();
    _structureController.dispose();
    _buildingYearController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// 사진 선택
  Future<void> _pickImages() async {
    try {
      // 이미지 소스 선택 다이얼로그
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('사진 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('갤러리에서 선택'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라로 촬영'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      // 이미지 선택
      final XFile? image = await _storageService.pickImage(source: source);
      if (image != null && mounted) {
        setState(() {
          _selectedImages.add(image);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('사진 선택 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 사진 삭제
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      // 업로드된 URL도 함께 삭제
      if (index < _uploadedImageUrls.length) {
        _uploadedImageUrls.removeAt(index);
      }
    });
  }

  /// 이미지 업로드 (Firebase Storage)
  /// [propertyId] 매물 ID (등록 전이면 null, 등록 후에는 실제 ID)
  Future<List<String>> _uploadImages({String? propertyId}) async {
    if (_selectedImages.isEmpty) {
      return [];
    }

    setState(() {
      _isUploadingImages = true;
    });

    try {
      // property ID가 있으면 사용, 없으면 임시 ID 사용
      final id = propertyId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final basePath = 'properties/$id/images';

      // 이미지 업로드
      final urls = await _storageService.uploadImages(
        files: _selectedImages,
        basePath: basePath,
      );

      if (mounted) {
        setState(() {
          _uploadedImageUrls = urls;
          _isUploadingImages = false;
        });
      }

      // 업로드 결과 확인
      if (urls.length != _selectedImages.length) {
        // 일부 이미지만 업로드된 경우
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('일부 이미지 업로드에 실패했습니다. (${urls.length}/${_selectedImages.length}개 성공)'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else if (urls.isNotEmpty) {
        // 모든 이미지 업로드 성공
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 업로드가 완료되었습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }

      return urls;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImages = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지 업로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return [];
    }
  }

  /// 임시 저장
  Future<void> _saveDraft() async {
    setState(() {
      _isSavingDraft = true;
    });

    try {
      // 임시 저장 데이터 구성
      final draftData = {
        'transactionType': _transactionType,
        'salePrice': _salePriceController.text,
        'monthlyRent': _monthlyRentController.text,
        'deposit': _depositController.text,
        'isNegotiable': _isNegotiable,
        'buildingName': _buildingNameController.text,
        'buildingType': _buildingTypeController.text,
        'totalFloors': _totalFloorsController.text,
        'floor': _floorController.text,
        'area': _areaController.text,
        'structure': _structureController.text,
        'buildingYear': _buildingYearController.text,
        'description': _descriptionController.text,
        'savedAt': DateTime.now().toIso8601String(),
      };

      // Firestore에 임시 저장 (견적 요청 문서에 저장)
      await _firebaseService.savePropertyRegistrationDraft(
        quoteRequestId: widget.quote.id,
        draftData: draftData,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('임시 저장되었습니다.'),
          backgroundColor: AppColors.kSuccess,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('임시 저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
        });
      }
    }
  }

  /// 매물 등록
  Future<void> _registerProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 가격 검증
    int? price;
    if (_transactionType == '매매') {
      price = _parsePrice(_salePriceController.text);
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매매가를 입력해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_transactionType == '월세') {
      final deposit = _parsePrice(_depositController.text) ?? 0;
      final monthly = _parsePrice(_monthlyRentController.text) ?? 0;
      if (monthly == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('월세 금액을 입력해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // 월세는 보증금 + 월세를 합산한 가격으로 저장 (또는 별도 필드 사용)
      price = deposit + (monthly * 12); // 1년치로 환산
    } else if (_transactionType == '전세') {
      price = _parsePrice(_depositController.text);
      if (price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전세 보증금을 입력해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. 이미지 업로드 (선택사항 - 실패해도 계속 진행)
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        try {
          imageUrls = await _uploadImages();
          // 업로드 실패해도 경고만 표시하고 계속 진행 (사진은 선택사항)
          if (imageUrls.isEmpty && _selectedImages.isNotEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이미지 업로드에 실패했습니다. 사진 없이 등록됩니다.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
            imageUrls = [];
          }
        } catch (e) {
          // 업로드 중 예외 발생해도 경고만 표시하고 계속 진행
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('이미지 업로드 중 오류가 발생했습니다. 사진 없이 등록됩니다.\n$e'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          imageUrls = [];
        }
      }

      // 2. 면적 파싱
      double? area;
      if (_areaController.text.isNotEmpty) {
        area = double.tryParse(_areaController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      }

      // 3. 이미지 URL을 JSON 문자열로 변환
      final imageUrlsJson = jsonEncode(imageUrls);

      // 4. brokerInfo 형식으로 변환 (brokers 컬렉션 필드명 → brokerInfo 필드명)
      final brokerInfo = <String, dynamic>{
        'uid': widget.brokerData['uid'],
        'brokerId': widget.brokerData['brokerId'] ?? widget.brokerData['uid'],
        'brokerName': widget.brokerData['ownerName'] ?? 
                     widget.brokerData['businessName'] ?? 
                     widget.brokerData['brokerName'] ?? 
                     widget.brokerData['name'] ?? 
                     '',
        'broker_phone': widget.brokerData['phoneNumber'] ?? 
                       widget.brokerData['phone'] ?? 
                       widget.brokerData['broker_phone'] ?? 
                       '',
        'broker_office_name': widget.brokerData['businessName'] ?? 
                             widget.brokerData['broker_office_name'] ?? 
                             widget.brokerData['name'] ?? 
                             '',
        'broker_license_number': widget.brokerData['brokerRegistrationNumber'] ?? 
                                widget.brokerData['registrationNumber'] ?? 
                                widget.brokerData['broker_license_number'] ?? 
                                '',
        'broker_office_address': widget.brokerData['roadAddress'] ?? 
                               widget.brokerData['address'] ?? 
                               widget.brokerData['broker_office_address'] ?? 
                               '',
        'broker_introduction': widget.brokerData['introduction'] ?? 
                             widget.brokerData['broker_introduction'] ?? 
                             '',
      };

      // 5. Property 객체 생성
      final property = Property(
        address: widget.quote.propertyAddress ?? '',
        transactionType: _transactionType,
        price: price!,
        area: area,
        description: _descriptionController.text,
        contractStatus: '대기', // 매물 등록 시 기본 상태는 '대기'
        status: 'marketing', // 광고 중 상태
        mainContractor: widget.quote.userName,
        contractor: '',
        registeredBy: widget.brokerData['uid'],
        registeredByName: brokerInfo['brokerName'] as String? ?? '',
        registeredByInfo: widget.brokerData,
        brokerInfo: brokerInfo,
        brokerId: brokerInfo['brokerId'] as String? ?? widget.brokerData['uid'],
        buildingName: _buildingNameController.text.isNotEmpty ? _buildingNameController.text : null,
        buildingType: _buildingTypeController.text.isNotEmpty ? _buildingTypeController.text : widget.quote.propertyType,
        totalFloors: _totalFloorsController.text.isNotEmpty ? int.tryParse(_totalFloorsController.text) : null,
        floor: _floorController.text.isNotEmpty ? int.tryParse(_floorController.text) : null,
        structure: _structureController.text.isNotEmpty ? _structureController.text : null,
        buildingYear: _buildingYearController.text.isNotEmpty ? _buildingYearController.text : null,
        propertyImages: imageUrlsJson, // 이미지 URL 저장
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fullAddrAPIData: widget.fullAddrAPIData ?? {},
      );

      // 5. 매물 등록
      final success = await _firebaseService.registerPropertyFromQuote(
        property: property,
        quoteRequestId: widget.quote.id,
      );

      if (!mounted) return;

      if (success) {
        // 성공 시 이전 페이지로 돌아가기
        Navigator.pop(context, true); // true를 반환하여 등록 완료를 알림
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매물 등록에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('매물 등록 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 반응형 레이아웃
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1200.0 : screenWidth;
    final horizontalPadding = isWeb ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('매물 등록'),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
        actions: [
          // 임시 저장 버튼
          TextButton.icon(
            onPressed: _isSavingDraft ? null : _saveDraft,
            icon: _isSavingDraft
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, color: Colors.white, size: 20),
            label: Text(
              _isSavingDraft ? '저장 중...' : '임시 저장',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (FocusScope.of(context).hasFocus) {
            FocusScope.of(context).unfocus();
            await Future.delayed(const Duration(milliseconds: 100));
            return false;
          }
          return true;
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
        key: _formKey,
            child: SafeArea(
        child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 안내 문구
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.kPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppColors.kPrimary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '매물 정보를 입력한 후 등록하시면 내집구매 목록에 노출됩니다.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.kPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 거래 유형 선택
                  _buildSectionTitle('거래 유형'),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '매매', label: Text('매매')),
                      ButtonSegment(value: '전세', label: Text('전세')),
                      ButtonSegment(value: '월세', label: Text('월세')),
                    ],
                    selected: {_transactionType},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _transactionType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // 가격 입력 섹션
                  _buildSectionTitle('가격 정보'),
                  const SizedBox(height: 12),
                  if (_transactionType == '매매') ...[
                    _buildTextField(
                      label: '매매가',
                      controller: _salePriceController,
                      hint: '예: 11억 5천만원',
                      icon: Icons.attach_money,
                      isRequired: true,
                    ),
                  ] else if (_transactionType == '전세') ...[
                    _buildTextField(
                      label: '전세 보증금',
                      controller: _depositController,
                      hint: '예: 5억원',
                      icon: Icons.attach_money,
                      isRequired: true,
                    ),
                  ] else if (_transactionType == '월세') ...[
                    _buildTextField(
                      label: '보증금',
                      controller: _depositController,
                      hint: '예: 1억원',
                      icon: Icons.attach_money,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      label: '월세',
                      controller: _monthlyRentController,
                      hint: '예: 100만원',
                      icon: Icons.attach_money,
                      isRequired: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('협의 가능'),
                    value: _isNegotiable,
                    onChanged: (value) {
                      setState(() {
                        _isNegotiable = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // 사진 첨부 섹션 (선택)
                  _buildSectionTitle('매물 사진 (선택)'),
                  const SizedBox(height: 8),
                  Text(
                    '매물 사진을 첨부해주세요. (선택사항)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  _buildImagePickerSection(),
                  const SizedBox(height: 24),

                  // 아파트 단지 정보 섹션
                  _buildSectionTitle('아파트 단지 정보'),
                  const SizedBox(height: 8),
                  Text(
                    '아래 정보는 견적 요청에서 가져온 기본 정보입니다. 필요시 수정해주세요.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: '단지명',
                    controller: _buildingNameController,
                    hint: '예: 분당 래미안',
                    icon: Icons.apartment,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: '건물 유형',
                          controller: _buildingTypeController,
                          hint: '예: 아파트',
                          icon: Icons.business,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: '전체 층수',
                          controller: _totalFloorsController,
                          hint: '예: 20',
                          icon: Icons.layers,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: '해당 층',
                          controller: _floorController,
                          hint: '예: 10',
                          icon: Icons.stairs,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: '면적 (㎡)',
                          controller: _areaController,
                          hint: '예: 84.5',
                          icon: Icons.square_foot,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          isRequired: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: '구조',
                          controller: _structureController,
                          hint: '예: 철근콘크리트',
                          icon: Icons.construction,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: '건축년도',
                          controller: _buildingYearController,
                          hint: '예: 2015',
                          icon: Icons.calendar_today,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // API 참조 정보 (읽기 전용)
                  if (widget.aptInfo != null || widget.vworldCoordinates != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('참조 정보'),
                        const SizedBox(height: 8),
                        Text(
                          '아래 정보는 자동으로 조회된 참조 정보입니다.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        ApiReferenceInfoCard(
                          isLoading: false,
                          apiError: null,
                          fullAddrAPIData: widget.fullAddrAPIData,
                          vworldCoordinates: widget.vworldCoordinates,
                          aptInfo: widget.aptInfo,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),

                  // 추가 설명
                  _buildSectionTitle('추가 설명'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: '매물 설명',
                    controller: _descriptionController,
                    hint: '매물에 대한 추가 설명을 입력해주세요.',
                    icon: Icons.description,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 32),

                  // 등록 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _registerProperty,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(
                        _isSubmitting ? '등록 중...' : '매물 등록하기',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
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
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label을(를) 입력해주세요.';
              }
              return null;
            }
          : null,
    );
  }

  /// 사진 첨부 섹션 UI
  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사진 선택 버튼
        SizedBox(
          width: double.infinity,
          height: 120,
          child: OutlinedButton.icon(
            onPressed: _isUploadingImages ? null : _pickImages,
            icon: _isUploadingImages
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate),
            label: Text(
              _isUploadingImages
                  ? '업로드 중...'
                  : _selectedImages.isEmpty
                      ? '사진 추가하기'
                      : '사진 추가하기 (${_selectedImages.length}장)',
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppColors.kPrimary,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 선택된 사진 미리보기
        if (_selectedImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  // 이미지 미리보기
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            _selectedImages[index].path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              );
                            },
                          )
                        : Image.file(
                            File(_selectedImages[index].path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                  ),
                  // 삭제 버튼
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

