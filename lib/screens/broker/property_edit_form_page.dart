import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/storage_service.dart';
import 'package:property/api_request/apt_info_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/api_request/address_service.dart';

/// 매물 수정 폼 페이지
/// 공인중개사가 등록한 매물을 수정하는 페이지
class PropertyEditFormPage extends StatefulWidget {
  final Property property;
  final Map<String, dynamic> brokerData;

  const PropertyEditFormPage({
    required this.property,
    required this.brokerData,
    super.key,
  });

  @override
  State<PropertyEditFormPage> createState() => _PropertyEditFormPageState();
}

class _PropertyEditFormPageState extends State<PropertyEditFormPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  final StorageService _storageService = StorageService();

  // 거래 유형
  late String _transactionType;

  // 가격 관련
  final TextEditingController _salePriceController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();
  final TextEditingController _depositController = TextEditingController();

  // 아파트 단지 정보
  final TextEditingController _buildingNameController = TextEditingController();
  final TextEditingController _buildingTypeController = TextEditingController();
  final TextEditingController _totalFloorsController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _structureController = TextEditingController();
  final TextEditingController _buildingYearController = TextEditingController();

  // 추가 정보
  final TextEditingController _descriptionController = TextEditingController();

  // 사진 첨부
  List<XFile> _newImages = []; // 새로 추가한 사진
  List<String> _existingImageUrls = []; // 기존 사진 URL
  List<String> _deletedImageUrls = []; // 삭제한 사진 URL
  bool _isUploadingImages = false;

  // API 정보
  Map<String, dynamic>? _aptInfo;
  Map<String, dynamic>? _vworldCoordinates;
  Map<String, String>? _fullAddrAPIData;

  // 참조 정보 수정용 컨트롤러
  final TextEditingController _roadAddrController = TextEditingController();
  final TextEditingController _jibunAddrController = TextEditingController();
  final TextEditingController _bdNmController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadApiInfo();
  }

  /// 폼 초기화 - 기존 매물 정보로 채우기
  void _initializeForm() {
    // 거래 유형
    _transactionType = widget.property.transactionType;

    // 가격 정보
    if (_transactionType == '매매') {
      _salePriceController.text = _formatPrice(widget.property.price);
    } else if (_transactionType == '전세') {
      _depositController.text = _formatPrice(widget.property.price);
    } else if (_transactionType == '월세') {
      // 월세는 별도 처리 필요 (현재는 price에 합산되어 있을 수 있음)
      _depositController.text = '';
      _monthlyRentController.text = '';
    }

    // 면적 정보
    if (widget.property.area != null) {
      _areaController.text = widget.property.area!.toStringAsFixed(2);
    }

    // 아파트 단지 정보
    if (widget.property.buildingName != null) {
      _buildingNameController.text = widget.property.buildingName!;
    }
    if (widget.property.buildingType != null) {
      _buildingTypeController.text = widget.property.buildingType!;
    }
    if (widget.property.totalFloors != null) {
      _totalFloorsController.text = widget.property.totalFloors!.toString();
    }
    if (widget.property.floor != null) {
      _floorController.text = widget.property.floor!.toString();
    }
    if (widget.property.structure != null) {
      _structureController.text = widget.property.structure!;
    }
    if (widget.property.buildingYear != null) {
      _buildingYearController.text = widget.property.buildingYear!;
    }

    // 설명
    if (widget.property.description.isNotEmpty) {
      _descriptionController.text = widget.property.description;
    }

    // 기존 이미지 URL 로드
    if (widget.property.propertyImages != null && widget.property.propertyImages!.isNotEmpty) {
      try {
        final imageUrls = jsonDecode(widget.property.propertyImages!) as List;
        _existingImageUrls = imageUrls.map((e) => e.toString()).toList();
      } catch (e) {
        // JSON 파싱 실패 시 무시
      }
    }

    // API 정보
    if (widget.property.fullAddrAPIData.isNotEmpty) {
      _fullAddrAPIData = Map<String, String>.from(widget.property.fullAddrAPIData);
      // 참조 정보 필드 초기화
      _roadAddrController.text = _fullAddrAPIData!['roadAddr'] ?? '';
      _jibunAddrController.text = _fullAddrAPIData!['jibunAddr'] ?? '';
      _bdNmController.text = _fullAddrAPIData!['bdNm'] ?? '';
    }
  }

  /// 주소 검색 API 정보 로드
  Future<void> _loadApiInfo() async {
    if (widget.property.address.isEmpty) return;

    try {
      final address = widget.property.address;
      final addressService = AddressService();

      // 1. 주소 상세 정보 조회
      try {
        final addrResult = await addressService.searchRoadAddress(address, page: 1);
        if (addrResult.fullData.isNotEmpty) {
          _fullAddrAPIData = Map<String, String>.from(addrResult.fullData.first);
          // 참조 정보 필드 업데이트
          if (mounted) {
            _roadAddrController.text = _fullAddrAPIData!['roadAddr'] ?? '';
            _jibunAddrController.text = _fullAddrAPIData!['jibunAddr'] ?? '';
            _bdNmController.text = _fullAddrAPIData!['bdNm'] ?? '';
          }
        }
      } catch (e) {
        // 무시
      }

      // 2. VWorld 좌표 정보 조회
      try {
        final landResult = await VWorldService.getLandInfoFromAddress(address);
        if (landResult != null && landResult['coordinates'] != null) {
          _vworldCoordinates = Map<String, dynamic>.from(landResult['coordinates']);
          // 좌표 정보 필드 초기화
          if (mounted) {
            _longitudeController.text = _vworldCoordinates!['x']?.toString() ?? '';
            _latitudeController.text = _vworldCoordinates!['y']?.toString() ?? '';
          }
        }
      } catch (e) {
        // 무시
      }

      // 3. 아파트 정보 조회
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
        // 무시
      }

    } catch (e) {
      // API 정보 로드 실패는 무시
    }
  }

  /// 가격 포맷팅
  String _formatPrice(int price) {
    if (price >= 100000000) {
      return '${(price / 100000000).toStringAsFixed(1)}억원';
    } else if (price >= 10000) {
      return '${(price / 10000).toStringAsFixed(0)}만원';
    }
    return '$price원';
  }

  /// 가격 파싱
  int? _parsePrice(String priceStr) {
    if (priceStr.trim().isEmpty) return null;
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
    _roadAddrController.dispose();
    _jibunAddrController.dispose();
    _bdNmController.dispose();
    _longitudeController.dispose();
    _latitudeController.dispose();
    super.dispose();
  }

  /// 사진 선택
  Future<void> _pickImages() async {
    try {
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

      final XFile? image = await _storageService.pickImage(source: source);
      if (image != null && mounted) {
        setState(() {
          _newImages.add(image);
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

  /// 기존 사진 삭제
  void _removeExistingImage(int index) {
    setState(() {
      final url = _existingImageUrls[index];
      _existingImageUrls.removeAt(index);
      _deletedImageUrls.add(url);
    });
  }

  /// 새 사진 삭제
  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  /// 이미지 업로드
  Future<List<String>> _uploadNewImages() async {
    if (_newImages.isEmpty) return [];

    setState(() {
      _isUploadingImages = true;
    });

    try {
      final propertyId = widget.property.firestoreId ?? '';
      final basePath = 'properties/$propertyId/images';

      final urls = await _storageService.uploadImages(
        files: _newImages,
        basePath: basePath,
      );

      if (mounted) {
        setState(() {
          _isUploadingImages = false;
        });
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
          ),
        );
      }
      return [];
    }
  }

  /// 매물 수정
  Future<void> _updateProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 사진 필수 검증 (기존 사진 + 새 사진)
    if (_existingImageUrls.isEmpty && _newImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('매물 사진을 최소 1장 이상 첨부해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
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
      price = deposit + (monthly * 12);
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
      // 1. 새 이미지 업로드
      final newImageUrls = await _uploadNewImages();

      // 2. 최종 이미지 URL 목록 (기존 - 삭제 + 새로 추가)
      final allImageUrls = [
        ..._existingImageUrls,
        ...newImageUrls,
      ];
      final imageUrlsJson = jsonEncode(allImageUrls);

      // 3. 면적 파싱
      double? area;
      if (_areaController.text.isNotEmpty) {
        area = double.tryParse(_areaController.text.replaceAll(RegExp(r'[^0-9.]'), ''));
      }

      // 4. 참조 정보 업데이트
      Map<String, String> updatedFullAddrAPIData = {};
      if (_fullAddrAPIData != null) {
        updatedFullAddrAPIData = Map<String, String>.from(_fullAddrAPIData!);
      }
      if (_roadAddrController.text.isNotEmpty) {
        updatedFullAddrAPIData['roadAddr'] = _roadAddrController.text;
      }
      if (_jibunAddrController.text.isNotEmpty) {
        updatedFullAddrAPIData['jibunAddr'] = _jibunAddrController.text;
      }
      if (_bdNmController.text.isNotEmpty) {
        updatedFullAddrAPIData['bdNm'] = _bdNmController.text;
      }

      Map<String, dynamic>? updatedVworldCoordinates;
      if (_vworldCoordinates != null) {
        updatedVworldCoordinates = Map<String, dynamic>.from(_vworldCoordinates!);
        if (_longitudeController.text.isNotEmpty) {
          updatedVworldCoordinates['x'] = double.tryParse(_longitudeController.text) ?? _vworldCoordinates!['x'];
        }
        if (_latitudeController.text.isNotEmpty) {
          updatedVworldCoordinates['y'] = double.tryParse(_latitudeController.text) ?? _vworldCoordinates!['y'];
        }
      }

      // 5. Property 객체 생성
      final updatedProperty = widget.property.copyWith(
        transactionType: _transactionType,
        price: price!,
        area: area,
        description: _descriptionController.text,
        buildingName: _buildingNameController.text.isNotEmpty ? _buildingNameController.text : null,
        buildingType: _buildingTypeController.text.isNotEmpty ? _buildingTypeController.text : widget.property.buildingType,
        totalFloors: _totalFloorsController.text.isNotEmpty ? int.tryParse(_totalFloorsController.text) : null,
        floor: _floorController.text.isNotEmpty ? int.tryParse(_floorController.text) : null,
        structure: _structureController.text.isNotEmpty ? _structureController.text : null,
        buildingYear: _buildingYearController.text.isNotEmpty ? _buildingYearController.text : null,
        propertyImages: imageUrlsJson,
        fullAddrAPIData: updatedFullAddrAPIData,
        updatedAt: DateTime.now(),
      );

      // 6. 매물 수정
      final propertyId = widget.property.firestoreId ?? '';
      if (propertyId.isEmpty) {
        throw Exception('매물 ID가 없습니다.');
      }

      final success = await _firebaseService.updatePropertyByBroker(
        propertyId: propertyId,
        property: updatedProperty,
      );

      if (!mounted) return;

      if (success) {
        // 성공 시 이전 페이지로 돌아가기
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매물 정보가 수정되었습니다.'),
            backgroundColor: AppColors.kSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매물 수정에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('매물 수정 중 오류가 발생했습니다: $e'),
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.kBackground,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('매물 수정'),
          backgroundColor: AppColors.kPrimary,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
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
                            '매물 정보를 수정한 후 저장하시면 변경사항이 반영됩니다.',
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
                  const SizedBox(height: 24),

                  // 사진 첨부 섹션
                  _buildSectionTitle('매물 사진 *'),
                  const SizedBox(height: 8),
                  Text(
                    '매물 사진을 최소 1장 이상 첨부해주세요.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  _buildImagePickerSection(),
                  const SizedBox(height: 24),

                  // 아파트 단지 정보 섹션
                  _buildSectionTitle('아파트 단지 정보'),
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

                  // API 참조 정보 (수정 가능)
                  if (_aptInfo != null || _vworldCoordinates != null || _fullAddrAPIData != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('참조 정보 (수정 가능)'),
                        const SizedBox(height: 8),
                        Text(
                          '아래 정보는 API로 불러온 참조 정보입니다. 필요시 수정해주세요.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        _buildEditableReferenceInfo(),
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

                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _updateProperty,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        _isSubmitting ? '저장 중...' : '수정 완료',
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
    final totalImages = _existingImageUrls.length + _newImages.length;

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
                  : totalImages == 0
                      ? '사진 추가하기'
                      : '사진 추가하기 (${totalImages}장)',
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: totalImages == 0
                    ? Colors.red
                    : AppColors.kPrimary,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        if (totalImages == 0) ...[
          const SizedBox(height: 8),
          Text(
            '※ 매물 사진은 필수입니다.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 16),
        // 기존 사진 미리보기
        if (_existingImageUrls.isNotEmpty) ...[
          Text(
            '기존 사진',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _existingImageUrls.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _existingImageUrls[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeExistingImage(index),
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
          const SizedBox(height: 16),
        ],
        // 새로 추가한 사진 미리보기
        if (_newImages.isNotEmpty) ...[
          Text(
            '새로 추가한 사진',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _newImages.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            _newImages[index].path,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              );
                            },
                          )
                        : Image.file(
                            File(_newImages[index].path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeNewImage(index),
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
      ],
    );
  }

  /// 수정 가능한 참조 정보 섹션
  Widget _buildEditableReferenceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 주소 상세 정보
        if (_fullAddrAPIData != null && _fullAddrAPIData!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      '주소 상세 정보',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: '도로명주소',
                  controller: _roadAddrController,
                  hint: '도로명주소',
                  icon: Icons.signpost,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: '지번주소',
                  controller: _jibunAddrController,
                  hint: '지번주소',
                  icon: Icons.map,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: '건물명',
                  controller: _bdNmController,
                  hint: '건물명',
                  icon: Icons.business,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 좌표 정보
        if (_vworldCoordinates != null && _vworldCoordinates!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.my_location, size: 18, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      '좌표 정보',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: '경도 (X)',
                        controller: _longitudeController,
                        hint: '경도',
                        icon: Icons.explore,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        label: '위도 (Y)',
                        controller: _latitudeController,
                        hint: '위도',
                        icon: Icons.explore_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 아파트 단지 정보 안내
        if (_aptInfo != null && _aptInfo!.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.apartment, size: 18, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    Text(
                      '아파트 단지 정보',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '아파트 단지 정보는 위의 "아파트 단지 정보" 섹션에서 수정할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

