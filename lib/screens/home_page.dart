import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/api_request/firebase_service.dart'; // FirebaseService import
import 'package:property/api_request/vworld_service.dart'; // VWorld API 서비스 추가
import 'package:property/utils/address_utils.dart';
import 'package:property/utils/owner_parser.dart';
import 'package:property/models/property.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/utils/current_state_parser.dart';
import 'package:property/widgets/hero_banner.dart';
import 'broker_list_page.dart';
import 'package:property/widgets/loading_overlay.dart';
import 'package:property/api_request/apt_info_service.dart';
import 'package:property/widgets/retry_view.dart';
import 'package:property/utils/logger.dart';
import 'package:property/widgets/address_search/address_search_tabs.dart';

class HomePage extends StatefulWidget {
  final String userId;
  final String userName;
  const HomePage({super.key, required this.userId, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 상태 유지로 성능 향상

  // 상세주소 입력란 비활성화 플래그
  // true로 변경하면 상세주소 입력란과 단지정보 조회 기능이 활성화됩니다.
  static const bool _isDetailAddressEnabled = false;

  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _detailController = TextEditingController();

  Map<String,String> selectedFullAddrAPIData = {};
  String selectedRoadAddress = '';
  String selectedDetailAddress = '';
  String selectedFullAddress = '';

  bool isRegisterLoading = false;
  Map<String, dynamic>? registerResult;
  String? registerError;
  String? ownerMismatchError;
  bool isSaving = false;
  bool hasAttemptedSearch = false; // 조회 시도 여부

  // 부동산 목록
  List<Map<String, dynamic>> estates = [];


  // 주소 파싱 관련 변수
  Map<String, String> parsedAddress1st = {};
  Map<String, String> parsedDetail = {};
  
  // VWorld API 데이터 - ValueNotifier로 최적화
  final ValueNotifier<Map<String, dynamic>?> _vworldCoordinatesNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<bool> _isVWorldLoadingNotifier = ValueNotifier<bool>(false);
  String? vworldError;                     // VWorld API 에러 메시지
  
  // 단지코드 관련 정보 - ValueNotifier로 최적화
  final ValueNotifier<Map<String, dynamic>?> _aptInfoNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  final ValueNotifier<bool> _isLoadingAptInfoNotifier = ValueNotifier<bool>(false);
  String? kaptCode;                        // 단지코드
  String? kaptCodeStatusMessage;            // 단지코드 조회 상태 메시지
  String? _currentAptInfoRequestKey;
  
  // 선택된 반경 (미터 단위, GPS/주소 입력 탭에서 설정)
  double? selectedRadiusMeters;

  // Getter로 기존 코드 호환성 유지
  Map<String, dynamic>? get vworldCoordinates => _vworldCoordinatesNotifier.value;
  bool get isVWorldLoading => _isVWorldLoadingNotifier.value;
  Map<String, dynamic>? get aptInfo => _aptInfoNotifier.value;
  bool get isLoadingAptInfo => _isLoadingAptInfoNotifier.value;

  /// 부동산 상담을 위한 공인중개사 찾기 페이지로 이동
  Future<void> _goToBrokerSearch() async {
    if (selectedFullAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주소를 먼저 선택해주세요.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    if (vworldCoordinates == null) {
      await _loadVWorldData(
        selectedFullAddress,
        fullAddrAPIData:
            selectedFullAddrAPIData.isNotEmpty ? selectedFullAddrAPIData : null,
      );
    }

    if (vworldCoordinates == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vworldError ?? '위치 정보를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.'),
          backgroundColor: AirbnbColors.error,
        ),
      );
      return;
    }

    final lat = double.tryParse(vworldCoordinates!['y'].toString());
    final lon = double.tryParse(vworldCoordinates!['x'].toString());

    if (lat == null || lon == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('좌표 정보가 올바르지 않습니다.'),
          backgroundColor: AirbnbColors.error,
        ),
      );
      return;
    }

    if (!mounted) return;

    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.navigateBrokerSearch,
      params: {
        'address': selectedFullAddress,
        'latitude': lat,
        'longitude': lon,
      },
      userId: widget.userId.isNotEmpty ? widget.userId : null,
      userName: widget.userName.isNotEmpty ? widget.userName : null,
      stage: FunnelStage.brokerDiscovery,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrokerListPage(
          address: selectedFullAddress,
          latitude: lat,
          longitude: lon,
          radiusMeters: selectedRadiusMeters ?? 1000.0, // 선택된 반경 전달 (기본값 1km)
          userName: widget.userName,
          userId: widget.userId,
          propertyArea: null,
          // transactionType은 상담요청 단계에서 선택
        ),
      ),
    );
  }


  /// 등기부등본 데이터에서 소유자 이름을 추출하여 로그인 사용자와 비교한다.
  /// 일치 여부에 따라 ownerMismatchError를 갱신한다.
  void checkOwnerName(Map<String, dynamic> registerData) {
    try {
      final entry = registerData['data']?['resRegisterEntriesList']?[0];
      if (entry == null) return;

      final ownerNames = extractOwnerNames(entry);

      // 로그인한 사용자 이름과 비교 (하드코딩된 테스트 이름 사용)
      final userName = widget.userName;
      if (ownerNames.isNotEmpty && !ownerNames.contains(userName)) {
        setState(() {
          ownerMismatchError = '⚠️ 주의: 등기부등본의 소유자와 로그인한 사용자가 다릅니다.\n소유자: ${ownerNames.join(", ")}\n로그인 사용자: $userName';
        });
      } else if (ownerNames.isNotEmpty && ownerNames.contains(userName)) {
        setState(() {
          ownerMismatchError = '✅ 등기부등본의 소유자와 로그인한 사용자가 일치합니다.\n소유자: ${ownerNames.join(", ")}';
        });
      } else {
        setState(() {
          ownerMismatchError = '⚠️ 등기부등본에서 소유자 정보를 찾을 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        ownerMismatchError = '⚠️ 소유자 정보 확인 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 등기부등본 정보 DB 저장 함수
  Future<void> saveRegisterDataToDatabase() async {
    if (registerResult == null || selectedFullAddress.isEmpty) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // 등기부등본 원본 JSON
      final rawJson = json.encode(registerResult);
      // 핵심 정보 추출
      final currentState = parseCurrentState(rawJson);
      final summaryMap = {
        "header": {
          "publishNo": currentState.header.publishNo,
          "publishDate": currentState.header.publishDate,
          "docTitle": currentState.header.docTitle,
          "realtyDesc": currentState.header.realtyDesc,
          "officeName": currentState.header.officeName,
          "issueNo": currentState.header.issueNo,
          "uniqueNo": currentState.header.uniqueNo,
        },
        "ownership": {
          "purpose": currentState.ownership.purpose,
          "receipt": currentState.ownership.receipt,
          "cause": currentState.ownership.cause,
          "ownerRaw": currentState.ownership.ownerRaw,
        },
        "areas": {
          "land": {
            "purpose": currentState.land.landPurpose,
            "area": currentState.land.landSize,
          },
          "building": {
            "structure": currentState.building.structure,
            "floors": currentState.building.floors
                .map((f) => {"floor": f.floorLabel, "area": f.area}).toList(),
            "areaTotal": currentState.building.areaTotal,
          }
        },
        "liens": currentState.liens
            .map((l) => {
                  "purpose": l.purpose,
                  "receipt": l.receipt,
                  "mainText": l.mainText,
                })
            .toList(),
      };

      // 등기부등본 데이터에서 상세 정보 추출
      final header = currentState.header;
      final ownership = currentState.ownership;
      final land = currentState.land;
      final building = currentState.building;
      final liens = currentState.liens;
      
      // 원본 JSON 데이터에서 추가 정보 추출
      final originalData = registerResult!['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final entriesList = safeMapList(originalData['resRegisterEntriesList']);
      final firstEntry = entriesList.isNotEmpty ? entriesList[0] : <String, dynamic>{};
      // 예시: 중첩 리스트도 safeMapList로 변환
      for (final entry in entriesList) {
        final hisList = safeMapList(entry['resRegistrationHisList']);
        for (final his in hisList) {
          final contentsList = safeMapList(his['resContentsList']);
          for (final contents in contentsList) {
            // resDetailList 처리 (필요시 추가)
            safeMapList(contents['resDetailList']);
          }
        }
      }
      
      // 소유자 정보 추출
      final ownerNames = extractOwnerNames(firstEntry);
      
      // 층별 면적 정보 변환
      final floorAreas = building.floors.map((f) => {
        "floor": f.floorLabel,
        "area": f.area,
      }).toList();
      
      // 권리사항 리스트 변환
      final liensList = liens.map((l) => "${l.purpose}: ${l.mainText}").toList();
      
      // 주소에서 건물명 추출
      final buildingName = selectedFullAddress.contains('우성아파트') ? '우성아파트' :
                          selectedFullAddress.contains('아파트') ? '아파트' : '';
      
      // 층수 추출
      final floorMatch = RegExp(r'제(\d+)층').firstMatch(selectedFullAddress);
      final floor = floorMatch != null ? int.tryParse(floorMatch.group(1)!) : null;
      
      // 등기부등본 원본 데이터 구조화
      final result = registerResult?['result'] as Map<String, dynamic>?;
      final registerHeader = {
        'docTitle': originalData['resDocTitle']?.toString(),
        'realty': originalData['resRealty']?.toString(),
        'publishNo': originalData['resPublishNo']?.toString(),
        'publishDate': originalData['resPublishDate']?.toString(),
        'competentRegistryOffice': originalData['commCompetentRegistryOffice']?.toString(),
        'transactionId': result?['transactionId']?.toString(),
        'resultCode': result?['code']?.toString(),
        'resultMessage': result?['message']?.toString(),
      };
      
      // 소유권 정보 구조화
      final registerOwnership = {
        'currentOwners': ownerNames.map((name) => {
          'name': name,
          'ratio': '2분의 1', // 예시 데이터
          'address': selectedFullAddress,
        }).toList(),
        'ownershipHistory': [], // 실제 데이터에서는 등기부등본에서 추출
        'registerMainContractor': ownerNames.isNotEmpty ? ownerNames.first : null, // 등기부등본의 대표 소유자
        'registerContractor': '임차인', // 등기부등본의 계약자
      };
      
      // 권리사항 정보 구조화
      final registerLiens = {
        'currentLiens': liensList,
        'totalAmount': liens.fold<String>('', (sum, lien) {
          final amountMatch = RegExp(r'금([0-9,]+)원').firstMatch(lien.mainText);
          return amountMatch != null ? amountMatch.group(1)! : sum;
        }),
        'lienHistory': liens.map((l) => {
          'purpose': l.purpose,
          'receipt': l.receipt,
          'mainText': l.mainText,
        }).toList(),
      };
      
      // 건물 정보 구조화
      final registerBuilding = {
        'structure': building.structure,
        'totalFloors': 16, // 예시 데이터
        'floor': floor,
        'area': building.areaTotal,
        'floorAreas': floorAreas,
        'buildingNumber': '제211동',
        'exclusiveArea': '132.60㎡', // 15층+16층 합계
      };
      
      // 토지 정보 구조화
      final registerLand = {
        'purpose': land.landPurpose,
        'area': land.landSize,
        'landNumber': '1',
        'landRatio': '107932.4분의 77.844',
      };
      
      final userInfo = {
        'userId': widget.userName,
        'userName': widget.userName,
        'registrationDate': DateTime.now().toIso8601String(),
        'userType': 'registered',
      };
      
      final newProperty = Property(
        fullAddrAPIData: selectedFullAddrAPIData,
        address: selectedFullAddress,
        transactionType: '매매', // 기본값 (나중에 사용자가 선택한 값으로 업데이트 가능)
        price: 0, // 실제 입력값
        description: '',
        registerData: rawJson,
        registerSummary: json.encode(summaryMap),
        mainContractor: '', // 등기부등본 데이터는 수정하지 않음
        contractor: '', // 등기부등본 데이터는 수정하지 않음
        registeredBy: widget.userName, // 등록자 ID
        registeredByName: widget.userName, // 등록자 이름
        registeredByInfo: userInfo, // 등록자 상세 정보
        
        // 사용자 정보 (등기부등본과 완전히 분리)
        userMainContractor: widget.userName, // 사용자가 설정한 대표 계약자
        userContractor: widget.userName, // 사용자가 설정한 계약자
        userContactInfo: '연락처 정보', // 사용자 연락처
        userNotes: '사용자 메모', // 사용자 메모
        // 추가 부동산 정보
        buildingName: buildingName,
        buildingType: buildingName.contains('아파트') ? '아파트' : '기타',
        floor: floor,
        area: building.areaTotal.isNotEmpty ? double.tryParse(building.areaTotal.replaceAll('㎡', '').trim()) : null,
        structure: building.structure,
        landPurpose: land.landPurpose,
        landArea: land.landSize.isNotEmpty ? double.tryParse(land.landSize.replaceAll('㎡', '').trim()) : null,
        ownerName: ownerNames.isNotEmpty ? ownerNames.join(', ') : null,
        ownerInfo: ownership.ownerRaw,
        liens: liensList.isNotEmpty ? liensList : null,
        publishDate: header.publishDate,
        officeName: header.officeName,
        publishNo: header.publishNo,
        uniqueNo: header.uniqueNo,
        issueNo: header.issueNo,
        realtyDesc: header.realtyDesc,
        receiptDate: ownership.receipt,
        cause: ownership.cause,
        purpose: ownership.purpose,
        floorAreas: floorAreas.isNotEmpty ? floorAreas : null,
        // 시세 정보 (예시 데이터)
        estimatedValue: '2억2,500만원',
        marketValue: '2억2,500만원',
        aiConfidence: '92%',
        recentTransaction: '2억1,800만원',
        priceHistory: json.encode({
          'months': ['1월', '2월', '3월', '4월', '5월', '6월'],
          'prices': [21000, 21500, 21800, 22200, 22500, 22800]
        }),
        nearbyPrices: json.encode({
          'average': '2억2,000만원',
          'change': '+2.3%',
          'comparison': [
            {'type': '동일 단지', 'price': '2억2,300만원', 'difference': '+300만원'},
            {'type': '주변 아파트', 'price': '2억1,800만원', 'difference': '-200만원'},
            {'type': '지역 평균', 'price': '2억2,000만원', 'difference': '0만원'},
          ]
        }),
        status: '판매중',
        notes: '등기부등본 조회 완료 - 소유자 확인 필요',
        // 등기부등본 상세 정보
        docTitle: registerHeader['docTitle']?.toString(),
        competentRegistryOffice: registerHeader['competentRegistryOffice']?.toString(),
        transactionId: registerHeader['transactionId']?.toString(),
        resultCode: registerHeader['resultCode']?.toString(),
        resultMessage: registerHeader['resultMessage']?.toString(),
        ownershipHistory: safeMapList(registerOwnership['ownershipHistory']),
        currentOwners: safeMapList(registerOwnership['currentOwners']),
        ownershipRatio: '2분의 1',
        lienHistory: safeMapList(registerLiens['lienHistory']),
        currentLiens: safeMapList(registerLiens['currentLiens']),
        totalLienAmount: registerLiens['totalAmount']?.toString(),
        buildingNumber: registerBuilding['buildingNumber']?.toString(),
        exclusiveArea: registerBuilding['exclusiveArea']?.toString(),
        commonArea: null,
        parkingArea: null,
        buildingYear: '1991',
        buildingPermit: null,
        landNumber: registerLand['landNumber'],
        landRatio: registerLand['landRatio'],
        landUse: registerLand['purpose'],
        landCategory: '대',
        registerHeader: registerHeader,
        registerOwnership: registerOwnership,
        registerLiens: registerLiens,
        registerBuilding: registerBuilding,
        registerLand: registerLand,
        registerSummaryData: summaryMap,
      );
      
      final docRef = await _firebaseService.addProperty(newProperty);

      if (docRef != null) {
        if (!mounted) return;
        // 부동산 데이터 저장 완료
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('부동산 정보가 저장되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      // 저장 실패 시 로깅
      Logger.error(
        '부동산 정보 저장 실패',
        error: e,
        stackTrace: stackTrace,
        context: 'save_register_data',
      );
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  // (제거됨) 내 부동산에 추가 기능

  // VWorld API 데이터 로드 (백그라운드) - ValueNotifier로 최적화
  Future<void> _loadVWorldData(String address, {Map<String, String>? fullAddrAPIData}) async {
    _isVWorldLoadingNotifier.value = true;
    vworldError = null;
    _vworldCoordinatesNotifier.value = null;
    
    try {
      final result = await VWorldService.getLandInfoFromAddress(
        address,
        fullAddrData: fullAddrAPIData,
      );
      
      if (mounted) {
        if (result != null) {
          _vworldCoordinatesNotifier.value = result['coordinates'];
          _isVWorldLoadingNotifier.value = false;
        } else {
          _isVWorldLoadingNotifier.value = false;
          vworldError = '선택한 주소에서 정확한 좌표를 찾지 못했습니다. 주소를 다시 확인해주세요.';
        }
      }
    } catch (e) {
      if (mounted) {
        _isVWorldLoadingNotifier.value = false;
        vworldError = 'VWorld API 오류: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
      }
    }
  }

  /// 주소에서 단지코드 정보 자동 조회 - ValueNotifier로 최적화
  Future<void> _loadAptInfoFromAddress(String address, {Map<String, String>? fullAddrAPIData}) async {
    if (address.isEmpty) {
      return;
    }

    final requestKey = _buildAptInfoRequestKey(address, fullAddrAPIData);
    if (_currentAptInfoRequestKey != null &&
        _currentAptInfoRequestKey == requestKey &&
        _isLoadingAptInfoNotifier.value) {
      return;
    }
    _currentAptInfoRequestKey = requestKey;

    _isLoadingAptInfoNotifier.value = true;
    _aptInfoNotifier.value = null;
    kaptCode = null;
    kaptCodeStatusMessage = null;
    
    try {
      // 주소에서 단지코드를 비동기로 추출 시도 (도로명코드/법정동코드 우선, 단지명 검색 fallback)
      final extractionResult = await AptInfoService.extractKaptCodeFromAddressAsync(
        address,
        fullAddrAPIData: fullAddrAPIData,
      );
      if (!mounted) return;

      if (extractionResult.isSuccess) {
        final extractedKaptCode = extractionResult.code!;
        final aptInfoResult = await AptInfoService.getAptBasisInfo(extractedKaptCode);

        if (!mounted) return;

        if (aptInfoResult != null) {
          final extractedKaptCodeFromResult = aptInfoResult['kaptCode']?.toString();

          _aptInfoNotifier.value = aptInfoResult;
          kaptCode = extractedKaptCodeFromResult;
          kaptCodeStatusMessage = null;
        } else {
          _aptInfoNotifier.value = null;
          kaptCode = null;
          kaptCodeStatusMessage = '단지정보 API 응답이 비어 있습니다. 잠시 후 다시 시도해주세요.';
        }
      } else {
        _aptInfoNotifier.value = null;
        kaptCode = null;
        kaptCodeStatusMessage = extractionResult.message;
      }
    } catch (e) {
      if (mounted) {
        _aptInfoNotifier.value = null;
        kaptCode = null;
        kaptCodeStatusMessage = '단지 정보를 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.';
      }
    } finally {
      if (mounted) {
        _isLoadingAptInfoNotifier.value = false;
      }
      if (_currentAptInfoRequestKey == requestKey) {
        _currentAptInfoRequestKey = null;
      }
    }
  }

  String _buildAptInfoRequestKey(String address, Map<String, String>? fullAddrAPIData) {
    final normalizedAddress = address.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final roadCode = (fullAddrAPIData?['rnMgtSn'] ?? '').toString().trim();
    final bjdCode = (fullAddrAPIData?['admCd'] ?? '').toString().trim();
    final buildingName = (fullAddrAPIData?['bdNm'] ?? '').toString().trim().toLowerCase();
    return '$normalizedAddress|$buildingName|$roadCode|$bjdCode';
  }

  // 등기부등본 조회 함수 (RegisterService 사용)
  Future<void> searchRegister() async {
    // ========================================
    // 🔴 등기부등본 기능 비활성화 플래그
    // ========================================
    const bool isRegisterFeatureEnabled = false; // true로 변경하면 기능 활성화
    
    if (selectedFullAddress.isEmpty) {
      setState(() {
        registerError = '주소를 먼저 입력해주세요.';
      });
      return;
    }

    // 상세주소 체크 (선택적) - 기능 활성화 시 사용
    // final dong = parsedDetail['dong'] ?? '';
    // final ho = parsedDetail['ho'] ?? '';
    
    setState(() {
      isRegisterLoading = true;
      registerError = null;
      registerResult = null;
      ownerMismatchError = null;
      hasAttemptedSearch = true; // 조회 시도 표시
    });

    try {
      // VWorld API는 항상 호출 (로그인 여부 무관)
      _loadVWorldData(
        selectedFullAddress,
        fullAddrAPIData:
            selectedFullAddrAPIData.isNotEmpty ? selectedFullAddrAPIData : null,
      );
      
      // 단지 정보도 주소 선택 시 자동으로 로드
      // kaptCode 가 이미 이전 검색 쿼리로 값이 있는 경우 중복검색 방지
      if (selectedFullAddress.isNotEmpty && kaptCode == null) {
        _loadAptInfoFromAddress(
          selectedFullAddress,
          fullAddrAPIData: selectedFullAddrAPIData.isNotEmpty ? selectedFullAddrAPIData : null,
        );
      } else {
      }
      
      // ========================================
      // 🔴 등기부등본 기능 비활성화 처리
      // ========================================
      if (!isRegisterFeatureEnabled) {
        setState(() {
          isRegisterLoading = false;
          registerError = null;
          registerResult = null;
        });
        return;
      }
      
      // 기능 활성화 시에만 실행되는 코드 (현재는 데드 코드)
      // 로그인하지 않은 경우: 등기부등본 API 호출하지 않음
      // if (widget.userName.isEmpty) {
      //   setState(() {
      //     isRegisterLoading = false;
      //     registerError = null;
      //   });
      //   return;
      // }
      
      // 등기부등본 조회 코드 (기능 활성화 시 사용)
      // const bool useTestcase = true; // 테스트 모드 활성화 (false로 변경하면 실제 API 사용)
      // String? accessToken;
      // final dongValue = dong.replaceAll('동', '').replaceAll(' ', '');
      // final hoValue = ho.replaceAll('호', '').replaceAll(' ', '');
      // final result = await RegisterService.instance.getRealEstateRegister(
      //   accessToken: accessToken ?? '',
      //   phoneNo: TestConstants.tempPhoneNo,
      //   password: TestConstants.tempPassword,
      //   sido: parsedAddress1st['sido'] ?? '',
      //   sigungu: parsedAddress1st['sigungu'] ?? '',
      //   roadName: parsedAddress1st['roadName'] ?? '',
      //   buildingNumber: parsedAddress1st['buildingNumber'] ?? '',
      //   ePrepayNo: TestConstants.ePrepayNo,
      //   dong: dongValue,
      //   ho: hoValue,
      //   ePrepayPass: 'tack1171',
      //   useTestcase: useTestcase,
      // );
      // 
      // if (result != null) {
      //   setState(() {
      //     registerResult = result;
      //   });
      //   
      //   // 소유자 이름 비교 실행
      //   checkOwnerName(result);
      // } else {
      //   setState(() {
      //     registerError = '등기부등본 조회에 실패했습니다. 주소를 다시 확인해주세요.';
      //   });
      // }
    } finally {
      setState(() {
        isRegisterLoading = false;
      });
    }
  }



  @override
  void dispose() {
    _detailController.dispose();
    _vworldCoordinatesNotifier.dispose();
    _isVWorldLoadingNotifier.dispose();
    _aptInfoNotifier.dispose();
    _isLoadingAptInfoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수 호출
    final isLoggedIn = widget.userName.isNotEmpty;
    
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ValueListenableBuilder<bool>(
          valueListenable: _isVWorldLoadingNotifier,
          builder: (context, isVWorldLoading, _) {
            return LoadingOverlay(
              isLoading: isRegisterLoading || isSaving || isVWorldLoading,
              message: _getLoadingMessage(),
              child: Scaffold(
                backgroundColor: AirbnbColors.background,
                resizeToAvoidBottomInset: true,
                body: SafeArea(
                  child: _buildBody(isLoggedIn),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 로딩 메시지 가져오기 (메서드 분리로 최적화)
  String _getLoadingMessage() {
    if (isRegisterLoading) return '등기부등본 조회 중...';
    if (isSaving) return '저장 중...';
    return '위치 정보 조회 중...';
  }

  // Body 빌드 메서드 분리 (성능 최적화)
  Widget _buildBody(bool isLoggedIn) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HeroBanner(showSearchBar: false),
              const SizedBox(height: AppSpacing.lg),
              _buildAddressSearchSection(),
              const SizedBox(height: AppSpacing.xl),
              _buildContentSection(isLoggedIn),
            ],
          ),
        );
      },
    );
  }

  // 주소 검색 섹션 빌드 (메서드 분리)
  Widget _buildAddressSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: AddressSearchTabs(
                    onAddressSelected: (result) async {
                      final cleanAddress = result.address;

                      // Analytics 이벤트 로깅
                      AnalyticsService.instance.logEvent(
                        AnalyticsEventNames.addressSelected,
                        params: {
                          'address': cleanAddress,
                          'hasBuildingName': (result.fullAddrAPIData?['bdNm'] ?? '').trim().isNotEmpty,
                          'roadCode': result.fullAddrAPIData?['rnMgtSn'],
                          'bjdCode': result.fullAddrAPIData?['admCd'],
                          'searchType': result.latitude != null ? 'gps' : 'input',
                        },
                        userId: widget.userId.isNotEmpty ? widget.userId : null,
                        userName: widget.userName.isNotEmpty ? widget.userName : null,
                        stage: FunnelStage.addressSearch,
                      );

                      setState(() {
                        if (result.fullAddrAPIData != null) {
                          selectedFullAddrAPIData = result.fullAddrAPIData!;
                        }
                        selectedRoadAddress = cleanAddress;
                        selectedDetailAddress = '';
                        selectedFullAddress = cleanAddress;
                        selectedRadiusMeters = result.radiusMeters; // 선택된 반경 저장
                        if (_isDetailAddressEnabled) {
                          _detailController.clear();
                          parsedDetail = {};
                        }
                        parsedAddress1st = AddressUtils.parseAddress1st(cleanAddress);
                        // 상태 초기화 후, 상세주소 입력 시에만 단지 정보 조회
                        hasAttemptedSearch = true;
                        registerResult = null;
                        registerError = null;
                        ownerMismatchError = null;
                        kaptCodeStatusMessage = null;
                        // 단지 정보 초기화 (상세주소 입력 시에만 조회)
                        _aptInfoNotifier.value = null;
                        kaptCode = null;
                      });

                      // 좌표가 이미 있는 경우 (GPS 기반 검색)
                      if (result.latitude != null && result.longitude != null) {
                        _vworldCoordinatesNotifier.value = {
                          'x': result.longitude.toString(),
                          'y': result.latitude.toString(),
                        };
                        vworldError = null;
                        _isVWorldLoadingNotifier.value = false;
                      } else {
                        // 좌표가 없는 경우 (주소 입력 검색) - 좌표 조회
                        await _loadVWorldData(
                          cleanAddress,
                          fullAddrAPIData: result.fullAddrAPIData?.isNotEmpty == true
                              ? result.fullAddrAPIData
                              : null,
                        );
                      }
                        },
      ),
    );
  }

  // 콘텐츠 섹션 빌드 (메서드 분리)
  Widget _buildContentSection(bool isLoggedIn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
              if (selectedRoadAddress.isNotEmpty && !selectedRoadAddress.startsWith('API 오류') && !selectedRoadAddress.startsWith('검색 결과 없음')) ...[
                // 선택된 주소 표시 - 에어비앤비 스타일 강화
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),  // 24px, 16px (에어비엔비 스타일)
                    padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),  // 24px (더 여유로운 패딩)
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,  // primaryDark.withValues(alpha: 0.08) → surface (더 깔끔한 회색)
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AirbnbColors.primary.withValues(alpha: 0.2),  // primaryDark → primary, alpha: 0.3 → 0.2
                        width: 1.5,
                      ),
                      // 미세한 그림자 추가 (깊이감)
                      boxShadow: [
                        BoxShadow(
                          color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 체크 아이콘과 레이블
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,  // check_circle → check_circle_rounded
                              color: AirbnbColors.primary,  // primaryDark → primary (더 밝게)
                              size: 22,  // 20 → 22
                            ),
                            const SizedBox(width: AppSpacing.sm),  // md → sm (더 컴팩트하게)
                            Text(
                              '선택된 주소',
                              style: AppTypography.withColor(
                                AppTypography.bodySmall.copyWith(  // caption → bodySmall (더 읽기 쉽게)
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                                AirbnbColors.primary,  // primaryDark → primary
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),  // xs → sm (더 여유롭게)
                        // 선택된 주소 텍스트
                        Text(
                          selectedFullAddress,
                          textAlign: TextAlign.center,
                          style: AppTypography.withColor(
                            AppTypography.body.copyWith(
                              fontWeight: FontWeight.w700,  // bold → w700 (더 명확하게)
                              letterSpacing: -0.2,
                              height: 1.4,  // 줄 간격 추가
                            ),
                            AirbnbColors.textPrimary,  // primaryDark → textPrimary (더 자연스럽게)
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // 상세주소 입력 (선택사항) - 플래그로 제어
                if (_isDetailAddressEnabled) ...[
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 900), // 600 -> 900으로 변경
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs), // 24px, 4px
                      child: DetailAddressInput(
                        controller: _detailController,
                        onChanged: (val) {
                          setState(() {
                            selectedDetailAddress = val;
                            parsedDetail = AddressUtils.parseDetailAddress(val);
                            // 상세주소가 있으면 추가, 없으면 도로명주소만
                            if (val.trim().isNotEmpty) {
                              selectedFullAddress = '$selectedRoadAddress ${val.trim()}';
                              // 상세주소 입력 시 단지 정보 조회
                              _loadAptInfoFromAddress(selectedFullAddress, fullAddrAPIData: selectedFullAddrAPIData);
                            } else {
                              selectedFullAddress = selectedRoadAddress;
                              // 상세주소가 비어있으면 단지 정보 초기화
                              _aptInfoNotifier.value = null;
                              kaptCode = null;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: AppSpacing.md), // 16px
                  
                  // 공동주택 단지 정보 (주소 선택 후 자동으로 표시)
                  if (hasAttemptedSearch)
                    ValueListenableBuilder<bool>(
                      valueListenable: _isLoadingAptInfoNotifier,
                      builder: (context, isLoadingAptInfo, _) {
                        return ValueListenableBuilder<Map<String, dynamic>?>(
                          valueListenable: _aptInfoNotifier,
                          builder: (context, aptInfo, _) {
                            return _buildAptInfoSection(isLoadingAptInfo, aptInfo);
                          },
                        );
                      },
                    ),
                ],
              ],
              
              // 등기부등본 조회 오류 표시
              if (registerError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: RetryView(
                    message: registerError!,
                    onRetry: () {
                      setState(() {
                        registerError = null;
                      });
                      searchRegister();
                    },
                  ),
                ),
              
              // 소유자 불일치 경고
              if (ownerMismatchError != null)
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm), // 24px, 8px
                    padding: const EdgeInsets.all(AppSpacing.md), // 16px
                    decoration: BoxDecoration(
                      color: AirbnbColors.warning.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AirbnbColors.warning.withValues(alpha: 0.2), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AirbnbColors.warning.withValues(alpha:0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AirbnbColors.warning.withValues(alpha: 0.6),
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.md), // 16px
                        Expanded(
                          child: Text(
                            ownerMismatchError!,
                            style: AppTypography.withColor(
                              AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                              AirbnbColors.warning.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
              
              
              // 부동산 상담 찾기 버튼 (조회 후에 표시, 로그인 여부 무관)
              // 결과 카드가 있을 때는 하단(결과 카드 내부)에 표시하므로 여기서는 숨김
              if (hasAttemptedSearch &&
                  selectedFullAddress.isNotEmpty &&
                  !(isLoggedIn && registerResult != null))
                ValueListenableBuilder<bool>(
                  valueListenable: _isVWorldLoadingNotifier,
                  builder: (context, isVWorldLoading, _) {
                    return Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 900),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: Semantics(
                              label: isVWorldLoading ? '위치 확인 중' : '부동산 상담 찾기',
                              button: true,
                              enabled: selectedFullAddress.isNotEmpty && !isVWorldLoading,
                              child: ElevatedButton.icon(
                                onPressed: (selectedFullAddress.isEmpty || isVWorldLoading)
                                    ? null
                                    : () async => _goToBrokerSearch(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AirbnbColors.textPrimary,
                                  foregroundColor: AirbnbColors.background,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                  shadowColor: AirbnbColors.primary.withValues(alpha: 0.5),
                                  textStyle: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                                ),
                                icon: isVWorldLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                                        ),
                                      )
                                    : const Icon(Icons.business, size: 24),
                                label: Text(isVWorldLoading ? '위치 확인 중...' : '부동산 상담 찾기'),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              if (hasAttemptedSearch &&
                  selectedFullAddress.isNotEmpty &&
                  !(isLoggedIn && registerResult != null))
                const SizedBox(height: AppSpacing.xxl), // 48px (버튼 높이 56px 고려하여 조정)

              _buildRegisterResultCard(isLoggedIn),
              
              // 웹 전용 푸터 여백 (영상 촬영용)
              if (kIsWeb) const SizedBox(height: AppSpacing.xxxl * 9.375), // 특수 케이스 유지 (600px)
              ],
            );
  }
  
  // 정보 카드 위젯
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md), // 16px
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.withColor(
                    AppTypography.h4.copyWith(fontWeight: FontWeight.bold),
                    AirbnbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs), // 4px
                Text(
                  content,
                  style: AppTypography.withColor(
                    AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    AirbnbColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterResultCard(bool isLoggedIn) {
    if (!(isLoggedIn && registerResult != null)) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm), // 8px
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), // 16px
        child: Container(
          decoration: BoxDecoration(
            color: AirbnbColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AirbnbColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AirbnbColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg), // 24px
                decoration: const BoxDecoration(
                  color: AirbnbColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm), // 8px
                      decoration: BoxDecoration(
                        color: AirbnbColors.background.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description,
                        color: AirbnbColors.background,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md), // 16px
                    Expanded(
                      child: Text(
                        '등기부등본 조회 결과',
                        style: AppTypography.withColor(
                          AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                          AirbnbColors.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg), // 24px
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(
                      icon: Icons.location_on,
                      title: '부동산 주소',
                      content: selectedFullAddress,
                      iconColor: AirbnbColors.primary,
                    ),
                    const SizedBox(height: AppSpacing.md), // 16px
                    _buildInfoCard(
                      icon: Icons.person,
                      title: '계약자',
                      content: widget.userName,
                      iconColor: AirbnbColors.success,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), // 24px
                child: _buildRegisterSummaryFromSummaryJson(),
              ),
              const SizedBox(height: AppSpacing.lg), // 24px
              if (selectedFullAddress.isNotEmpty)
                ValueListenableBuilder<bool>(
                  valueListenable: _isVWorldLoadingNotifier,
                  builder: (context, isVWorldLoading, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: (selectedFullAddress.isEmpty || isVWorldLoading)
                              ? null
                              : () async => _goToBrokerSearch(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbColors.textPrimary,
                            foregroundColor: AirbnbColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            shadowColor: AirbnbColors.primary.withValues(alpha: 0.5),
                            textStyle: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                          icon: isVWorldLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                                  ),
                                )
                              : const Icon(Icons.business, size: 24),
                          label: Text(isVWorldLoading ? '위치 확인 중...' : '공인중개사 찾기'),
                        ),
                      ),
                    );
                  },
                ),
              if (selectedFullAddress.isNotEmpty)
                const SizedBox(height: AppSpacing.xxl), // 48px (56px → 48px로 조정)
            ],
          ),
        ),
      ),
    );
  }

  // 등기부등본 카드 위젯 (VWorld 스타일과 동일)
  Widget _buildRegisterCard({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.borderLight, width: 1),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 - 더 컴팩트하게
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // 16px, 8px
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: AppSpacing.sm), // 8px
                Text(
                  title,
                  style: AppTypography.withColor(
                    AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                    iconColor,
                  ),
                ),
              ],
            ),
          ),
          // 구분선
          const Divider(height: 1, color: AirbnbColors.borderLight),
          // 내용
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // 16px, 8px
            child: content,
          ),
        ],
      ),
    );
  }

  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.withColor(
                AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                AirbnbColors.textSecondary,
              ),
              softWrap: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md), // 16px
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                AirbnbColors.textPrimary,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
  
  // 단지 정보 섹션 빌드 (메서드 분리)
  Widget _buildAptInfoSection(bool isLoadingAptInfo, Map<String, dynamic>? aptInfo) {
    const double maxContentWidth = 900;
    
    // 로딩 중일 때
    if (isLoadingAptInfo) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          margin: const EdgeInsets.only(top: AppSpacing.lg),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AirbnbColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AirbnbColors.border),
              boxShadow: [
                BoxShadow(
                  color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '공동주택 단지 정보 조회 중...',
                  style: AppTypography.withColor(
                    AppTypography.body.copyWith(fontWeight: FontWeight.w500),
                    AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // 단지 정보 표시 조건: aptInfo와 kaptCode가 모두 있고, 상세주소가 입력된 경우
    if (aptInfo != null && kaptCode != null && selectedDetailAddress.trim().isNotEmpty) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildAptInfoCard(aptInfo),
        ),
      );
    }

    // 단지 정보가 없으면 조용히 종료 (공동주택이 아닐 수도 있으므로 경고 미노출)
    return const SizedBox.shrink();
  }

  /// 단지 정보 카드 위젯
  Widget _buildAptInfoCard([Map<String, dynamic>? aptInfoData]) {
    final aptInfoToUse = aptInfoData ?? aptInfo;
    if (aptInfoToUse == null) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기본 정보
        _buildRegisterCard(
          icon: Icons.info_outline,
          title: '기본 정보',
          iconColor: AirbnbColors.primary,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (aptInfoToUse['kaptCode'] != null && aptInfoToUse['kaptCode'].toString().isNotEmpty)
                _buildDetailRow('단지코드', aptInfoToUse['kaptCode'].toString()),
              if (aptInfoToUse['kaptName'] != null && aptInfoToUse['kaptName'].toString().isNotEmpty)
                _buildDetailRow('단지명', aptInfoToUse['kaptName'].toString()),
              if (aptInfoToUse['codeStr'] != null && aptInfoToUse['codeStr'].toString().isNotEmpty)
                _buildDetailRow('건물구조', aptInfoToUse['codeStr'].toString()),
            ],
          ),
        ),
        
        // 나머지 단지 정보 카드들 (기본정보와 일반관리 사이에 배치)
        _buildAptInfoCardBetweenBasicAndManagement(aptInfoToUse),
        
        // 일반 관리
        if ((aptInfoToUse['codeMgr'] != null && aptInfoToUse['codeMgr'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptMgrCnt'] != null && aptInfoToUse['kaptMgrCnt'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptCcompany'] != null && aptInfoToUse['kaptCcompany'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.manage_accounts,
            title: '일반 관리',
            iconColor: AirbnbColors.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['codeMgr'] != null && aptInfoToUse['codeMgr'].toString().isNotEmpty)
                  _buildDetailRow('관리방식', aptInfoToUse['codeMgr'].toString()),
                if (aptInfoToUse['kaptMgrCnt'] != null && aptInfoToUse['kaptMgrCnt'].toString().isNotEmpty)
                  _buildDetailRow('관리사무소 수', '${aptInfoToUse['kaptMgrCnt']}개'),
                if (aptInfoToUse['kaptCcompany'] != null && aptInfoToUse['kaptCcompany'].toString().isNotEmpty)
                  _buildDetailRow('관리업체', aptInfoToUse['kaptCcompany'].toString()),
              ],
            ),
          ),
      ],
    );
  }

  /// 기본정보와 일반관리 사이에 표시할 단지 정보 카드 (기본정보와 일반관리 제외)
  Widget _buildAptInfoCardBetweenBasicAndManagement([Map<String, dynamic>? aptInfoData]) {
    final aptInfoToUse = aptInfoData ?? aptInfo;
    if (aptInfoToUse == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 경비 관리
        if ((aptInfoToUse['codeSec'] != null && aptInfoToUse['codeSec'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdScnt'] != null && aptInfoToUse['kaptdScnt'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdSecCom'] != null && aptInfoToUse['kaptdSecCom'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.security,
            title: '경비 관리',
            iconColor: AirbnbColors.error,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['codeSec'] != null && aptInfoToUse['codeSec'].toString().isNotEmpty)
                  _buildDetailRow('경비관리방식', aptInfoToUse['codeSec'].toString()),
                if (aptInfoToUse['kaptdScnt'] != null && aptInfoToUse['kaptdScnt'].toString().isNotEmpty)
                  _buildDetailRow('경비인력 수', '${aptInfoToUse['kaptdScnt']}명'),
                if (aptInfoToUse['kaptdSecCom'] != null && aptInfoToUse['kaptdSecCom'].toString().isNotEmpty)
                  _buildDetailRow('경비업체', aptInfoToUse['kaptdSecCom'].toString()),
              ],
            ),
          ),
        
        // 청소 관리
        if ((aptInfoToUse['codeClean'] != null && aptInfoToUse['codeClean'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdClcnt'] != null && aptInfoToUse['kaptdClcnt'].toString().isNotEmpty) ||
            (aptInfoToUse['codeGarbage'] != null && aptInfoToUse['codeGarbage'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.cleaning_services,
            title: '청소 관리',
            iconColor: AirbnbColors.success,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['codeClean'] != null && aptInfoToUse['codeClean'].toString().isNotEmpty)
                  _buildDetailRow('청소관리방식', aptInfoToUse['codeClean'].toString()),
                if (aptInfoToUse['kaptdClcnt'] != null && aptInfoToUse['kaptdClcnt'].toString().isNotEmpty)
                  _buildDetailRow('청소인력 수', '${aptInfoToUse['kaptdClcnt']}명'),
                if (aptInfoToUse['codeGarbage'] != null && aptInfoToUse['codeGarbage'].toString().isNotEmpty)
                  _buildDetailRow('음식물처리방법', aptInfoToUse['codeGarbage'].toString()),
              ],
            ),
          ),
        
        // 소독 관리
        if ((aptInfoToUse['codeDisinf'] != null && aptInfoToUse['codeDisinf'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdDcnt'] != null && aptInfoToUse['kaptdDcnt'].toString().isNotEmpty) ||
            (aptInfoToUse['disposalType'] != null && aptInfoToUse['disposalType'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.medical_services,
            title: '소독 관리',
            iconColor: AirbnbColors.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['codeDisinf'] != null && aptInfoToUse['codeDisinf'].toString().isNotEmpty)
                  _buildDetailRow('소독관리방식', aptInfoToUse['codeDisinf'].toString()),
                if (aptInfoToUse['kaptdDcnt'] != null && aptInfoToUse['kaptdDcnt'].toString().isNotEmpty)
                  _buildDetailRow('소독인력 수', '${aptInfoToUse['kaptdDcnt']}명'),
                if (aptInfoToUse['disposalType'] != null && aptInfoToUse['disposalType'].toString().isNotEmpty)
                  _buildDetailRow('소독방법', aptInfoToUse['disposalType'].toString()),
              ],
            ),
          ),
        
        // 건물/시설 정보
        if ((aptInfoToUse['codeEcon'] != null && aptInfoToUse['codeEcon'].toString().isNotEmpty) ||
            (aptInfoToUse['codeEmgr'] != null && aptInfoToUse['codeEmgr'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdEcapa'] != null && aptInfoToUse['kaptdEcapa'].toString().isNotEmpty) ||
            (aptInfoToUse['codeFalarm'] != null && aptInfoToUse['codeFalarm'].toString().isNotEmpty) ||
            (aptInfoToUse['codeWsupply'] != null && aptInfoToUse['codeWsupply'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.home,
            title: '건물/시설',
            iconColor: AirbnbColors.warning,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['kaptdEcapa'] != null && aptInfoToUse['kaptdEcapa'].toString().isNotEmpty)
                  _buildDetailRow('수전용량', aptInfoToUse['kaptdEcapa'].toString()),
                if (aptInfoToUse['codeEcon'] != null && aptInfoToUse['codeEcon'].toString().isNotEmpty)
                  _buildDetailRow('세대전기계약방식', aptInfoToUse['codeEcon'].toString()),
                if (aptInfoToUse['codeEmgr'] != null && aptInfoToUse['codeEmgr'].toString().isNotEmpty)
                  _buildDetailRow('전기안전관리자법정선임여부', aptInfoToUse['codeEmgr'].toString()),
                if (aptInfoToUse['codeFalarm'] != null && aptInfoToUse['codeFalarm'].toString().isNotEmpty)
                  _buildDetailRow('화재수신반방식', aptInfoToUse['codeFalarm'].toString()),
                if (aptInfoToUse['codeWsupply'] != null && aptInfoToUse['codeWsupply'].toString().isNotEmpty)
                  _buildDetailRow('급수방식', aptInfoToUse['codeWsupply'].toString()),
              ],
            ),
          ),
        
        // 승강기/주차 정보
        if ((aptInfoToUse['codeElev'] != null && aptInfoToUse['codeElev'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdEcnt'] != null && aptInfoToUse['kaptdEcnt'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdPcnt'] != null && aptInfoToUse['kaptdPcnt'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdPcntu'] != null && aptInfoToUse['kaptdPcntu'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.elevator,
            title: '승강기/주차',
            iconColor: AirbnbColors.teal,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['codeElev'] != null && aptInfoToUse['codeElev'].toString().isNotEmpty)
                  _buildDetailRow('승강기관리형태', aptInfoToUse['codeElev'].toString()),
                if (aptInfoToUse['kaptdEcnt'] != null && aptInfoToUse['kaptdEcnt'].toString().isNotEmpty)
                  _buildDetailRow('승강기대수', '${aptInfoToUse['kaptdEcnt']}대'),
                if (aptInfoToUse['kaptdPcnt'] != null && aptInfoToUse['kaptdPcnt'].toString().isNotEmpty)
                  _buildDetailRow('주차대수(지상)', '${aptInfoToUse['kaptdPcnt']}대'),
                if (aptInfoToUse['kaptdPcntu'] != null && aptInfoToUse['kaptdPcntu'].toString().isNotEmpty)
                  _buildDetailRow('주차대수(지하)', '${aptInfoToUse['kaptdPcntu']}대'),
              ],
            ),
          ),
        
        // 통신/보안시설
        if ((aptInfoToUse['codeNet'] != null && aptInfoToUse['codeNet'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdCccnt'] != null && aptInfoToUse['kaptdCccnt'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.camera_alt,
            title: '통신/보안시설',
            iconColor: AirbnbColors.blue,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['codeNet'] != null && aptInfoToUse['codeNet'].toString().isNotEmpty)
                  _buildDetailRow('주차관제/홈네트워크', aptInfoToUse['codeNet'].toString()),
                if (aptInfoToUse['kaptdCccnt'] != null && aptInfoToUse['kaptdCccnt'].toString().isNotEmpty)
                  _buildDetailRow('CCTV대수', '${aptInfoToUse['kaptdCccnt']}대'),
              ],
            ),
          ),
        
        // 편의/복리시설
        if ((aptInfoToUse['welfareFacility'] != null && aptInfoToUse['welfareFacility'].toString().isNotEmpty) ||
            (aptInfoToUse['convenientFacility'] != null && aptInfoToUse['convenientFacility'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.local_convenience_store,
            title: '편의/복리시설',
            iconColor: AirbnbColors.pink,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['welfareFacility'] != null && aptInfoToUse['welfareFacility'].toString().isNotEmpty)
                  _buildDetailRow('부대/복리시설', aptInfoToUse['welfareFacility'].toString()),
                if (aptInfoToUse['convenientFacility'] != null && aptInfoToUse['convenientFacility'].toString().isNotEmpty)
                  _buildDetailRow('편의시설', aptInfoToUse['convenientFacility'].toString()),
              ],
            ),
          ),
        
        // 교통 정보
        if ((aptInfoToUse['kaptdWtimebus'] != null && aptInfoToUse['kaptdWtimebus'].toString().isNotEmpty) ||
            (aptInfoToUse['subwayLine'] != null && aptInfoToUse['subwayLine'].toString().isNotEmpty) ||
            (aptInfoToUse['subwayStation'] != null && aptInfoToUse['subwayStation'].toString().isNotEmpty) ||
            (aptInfoToUse['kaptdWtimesub'] != null && aptInfoToUse['kaptdWtimesub'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.train,
            title: '교통 정보',
            iconColor: Colors.blueGrey,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['kaptdWtimebus'] != null && aptInfoToUse['kaptdWtimebus'].toString().isNotEmpty)
                  _buildDetailRow('버스정류장 거리', aptInfoToUse['kaptdWtimebus'].toString()),
                if (aptInfoToUse['subwayLine'] != null && aptInfoToUse['subwayLine'].toString().isNotEmpty)
                  _buildDetailRow('지하철호선', aptInfoToUse['subwayLine'].toString()),
                if (aptInfoToUse['subwayStation'] != null && aptInfoToUse['subwayStation'].toString().isNotEmpty)
                  _buildDetailRow('지하철역명', aptInfoToUse['subwayStation'].toString()),
                if (aptInfoToUse['kaptdWtimesub'] != null && aptInfoToUse['kaptdWtimesub'].toString().isNotEmpty)
                  _buildDetailRow('지하철역 거리', aptInfoToUse['kaptdWtimesub'].toString()),
              ],
            ),
          ),
        
        // 교육시설
        if (aptInfoToUse['educationFacility'] != null && aptInfoToUse['educationFacility'].toString().isNotEmpty)
          _buildRegisterCard(
            icon: Icons.school,
            title: '교육시설',
            iconColor: AirbnbColors.orange,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('교육시설', aptInfoToUse['educationFacility'].toString()),
              ],
            ),
          ),
        
        // 전기차 충전기
        if ((aptInfoToUse['groundElChargerCnt'] != null && aptInfoToUse['groundElChargerCnt'].toString().isNotEmpty) ||
            (aptInfoToUse['undergroundElChargerCnt'] != null && aptInfoToUse['undergroundElChargerCnt'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.ev_station,
            title: '전기차 충전기',
            iconColor: Colors.lightGreen,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfoToUse['groundElChargerCnt'] != null && aptInfoToUse['groundElChargerCnt'].toString().isNotEmpty)
                  _buildDetailRow('지상 전기차 충전기', '${aptInfoToUse['groundElChargerCnt']}대'),
                if (aptInfoToUse['undergroundElChargerCnt'] != null && aptInfoToUse['undergroundElChargerCnt'].toString().isNotEmpty)
                  _buildDetailRow('지하 전기차 충전기', '${aptInfoToUse['undergroundElChargerCnt']}대'),
              ],
            ),
          ),
      ],
    );
  }

  // 아래에 핵심 JSON만 예쁘게 출력하는 위젯 추가
  Widget _buildRegisterSummaryFromSummaryJson() {
    try {
      final rawJson = json.encode(registerResult);
      final currentState = parseCurrentState(rawJson);
      // 헤더 정보
      final header = currentState.header;
      // 소유자 정보
      final ownership = currentState.ownership;
      // 토지/건물 정보
      final land = currentState.land;
      final building = currentState.building;
      // 권리(저당 등)
      final liens = currentState.liens;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더(문서 정보)
          _buildRegisterCard(
            icon: Icons.description,
            title: '등기사항전부증명서',
            iconColor: AirbnbColors.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('주소', header.realtyDesc),
                _buildDetailRow('발급일', header.publishDate),
                _buildDetailRow('발급기관', header.officeName),
                if (header.publishNo.isNotEmpty)
                  _buildDetailRow('발급번호', header.publishNo),
              ],
            ),
          ),
          // 소유자 정보
          _buildRegisterCard(
            icon: Icons.people,
            title: '소유자 정보',
            iconColor: AirbnbColors.success,
            content: Text(
              ownership.ownerRaw.isNotEmpty ? ownership.ownerRaw : '-',
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600, height: 1.5),
                AirbnbColors.textPrimary,
              ),
            ),
          ),
          // 토지/건물 정보
          _buildRegisterCard(
            icon: Icons.home,
            title: '토지/건물 정보',
            iconColor: AirbnbColors.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('토지 지목', land.landPurpose),
                _buildDetailRow('토지 면적', land.landSize),
                _buildDetailRow('건물 구조', building.structure),
                _buildDetailRow('건물 전체면적', building.areaTotal),
                if (building.floors.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md), // 16px
                  Text(
                    '층별 면적',
                    style: AppTypography.withColor(
                      AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      AirbnbColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm), // 8px
                  ...building.floors.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  f.floorLabel,
                                  style: AppTypography.withColor(
                                    AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                                    AirbnbColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  f.area,
                                  style: AppTypography.withColor(
                                    AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                                    AirbnbColors.textPrimary,
                                  ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
          // 권리(저당 등)
          if (liens.isNotEmpty)
            _buildRegisterCard(
              icon: Icons.gavel,
              title: '권리사항',
              iconColor: AirbnbColors.warning,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: liens.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm), // 8px
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('목적', l.purpose),
                      _buildDetailRow('내용', l.mainText),
                      _buildDetailRow('접수일', l.receipt),
                      if (liens.indexOf(l) != liens.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Divider(color: AirbnbColors.border),
                        ),
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
      );
    } catch (e) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md), // 16px
        decoration: BoxDecoration(
          color: AirbnbColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('핵심 정보 표시 중 오류: $e', style: const TextStyle(color: AirbnbColors.error)),
      );
    }
  }

}


/// 상세 주소 입력 위젯 - 에어비앤비 스타일 강화
class DetailAddressInput extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;
  const DetailAddressInput({required this.controller, required this.onChanged, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,  // primary.withValues(alpha: 0.05) → surface (더 깔끔한 회색)
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AirbnbColors.borderLight,  // primary.withValues(alpha: 0.3) → borderLight (더 자연스럽게)
          width: 1,
        ),
        // 미세한 그림자 추가 (깊이감)
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.body.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
        ),
        decoration: InputDecoration(
          labelText: '상세주소 (단지정가 확인용)',
          labelStyle: AppTypography.withColor(
            AppTypography.bodySmall.copyWith(  // body → bodySmall (더 적절한 크기)
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
            AirbnbColors.primary,
          ),
          hintText: '예: 211동 1506호',
          hintStyle: AppTypography.withColor(
            AppTypography.body,
            AirbnbColors.textSecondary,
          ),
          helperText: '💡 단지정가를 확인하려면 동/호수를 입력해주세요',
          helperStyle: AppTypography.withColor(
            AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w400,  // w500 → w400 (더 부드럽게)
              letterSpacing: -0.05,
            ),
            AirbnbColors.textSecondary,
          ),
          filled: true,
          fillColor: AirbnbColors.background,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide(
              color: AirbnbColors.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,  // lg → md (더 컴팩트하게)
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            child: const Icon(
              Icons.home_work_outlined,  // home_work → home_work_outlined (통일성 강화)
              color: AirbnbColors.primary,
              size: 24,  // 26 → 24 (더 적절한 크기)
            ),
          ),
        ),
      ),
    );
  }
}

/// VWorld 데이터 표시 위젯
class VWorldDataWidget extends StatelessWidget {
  final Map<String, dynamic>? coordinates;
  final String? error;
  final bool isLoading;
  
  const VWorldDataWidget({
    this.coordinates,
    this.error,
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 로딩 중이거나, 데이터가 있거나, 에러가 있으면 표시
    if (!isLoading && coordinates == null && error == null) {
      return const SizedBox.shrink();
    }

    return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목
                Row(
                  children: [
                    Icon(
                      isLoading ? Icons.hourglass_empty : (error != null ? Icons.warning_rounded : Icons.location_on),
                      color: isLoading ? AirbnbColors.textSecondary : (error != null ? AirbnbColors.warning : AirbnbColors.primary),
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm), // 8px
                    Text(
                      isLoading ? '위치 정보 조회 중...' : (error != null ? '위치 정보 조회 실패' : '위치 정보'),
                      style: AppTypography.withColor(
                        AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                        isLoading ? AirbnbColors.textSecondary : (error != null ? AirbnbColors.warning : AirbnbColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md), // 16px
                
                // 로딩 중
                if (isLoading) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ],
                
                // 에러 메시지
                if (error != null && !isLoading) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md), // 16px
                    decoration: BoxDecoration(
                      color: AirbnbColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AirbnbColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AirbnbColors.warning, size: 24),
                        const SizedBox(width: AppSpacing.md), // 16px
                        Expanded(
                          child: Text(
                            error!,
                            style: AppTypography.withColor(
                              AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                              AirbnbColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 정보 카드들
                if (!isLoading && coordinates != null) ...[
                  // 좌표 정보
                  _buildInfoCard(
                    icon: Icons.pin_drop,
                    title: '좌표 정보',
                    content: '경도: ${coordinates!['x']}\n위도: ${coordinates!['y']}\n정확도: Level ${coordinates!['level'] ?? '-'}',
                    iconColor: AirbnbColors.primary,
                  ),
                ],
              ],
            );
  }

  // 등기부등본 스타일의 정보 카드
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.borderLight, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
                const SizedBox(width: AppSpacing.md), // 16px
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.withColor(
                          AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                          AirbnbColors.textPrimary,
                        ),
                ),
                const SizedBox(height: AppSpacing.sm), // 8px
                Text(
                  content,
                  style: AppTypography.withColor(
                    AppTypography.caption.copyWith(height: 1.5),
                    AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

