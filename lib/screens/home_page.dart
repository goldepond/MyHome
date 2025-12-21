import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:convert';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/address_service.dart';
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

class HomePage extends StatefulWidget {
  final String userId;
  final String userName;
  const HomePage({super.key, required this.userId, required this.userName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();

  final TextEditingController _controller = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  String queryAddress = '';
  bool isSearchingRoadAddr = false;

  List<Map<String,String>> fullAddrAPIDataList = [];
  List<String> roadAddressList = [];

  Map<String,String> selectedFullAddrAPIData = {};
  String selectedRoadAddress = '';
  String selectedDetailAddress = '';
  String selectedFullAddress = '';

  bool isRegisterLoading = false;
  String? addressSearchMessage;
  bool addressSearchMessageIsWarning = false;
  
  // 주소 검색 디바운싱 관련
  Timer? _addressSearchDebounceTimer;
  String? _lastSearchKeyword;
  Map<String, dynamic>? registerResult;
  String? registerError;
  String? ownerMismatchError;
  bool isSaving = false;
  bool hasAttemptedSearch = false; // 조회 시도 여부

  // 부동산 목록
  List<Map<String, dynamic>> estates = [];

  // 페이지네이션 관련 변수
  int currentPage = 1;
  int totalCount = 0;

  // 주소 파싱 관련 변수
  Map<String, String> parsedAddress1st = {};
  Map<String, String> parsedDetail = {};
  
  // VWorld API 데이터
  Map<String, dynamic>? vworldCoordinates; // 좌표 정보
  String? vworldError;                     // VWorld API 에러 메시지
  bool isVWorldLoading = false;            // VWorld API 로딩 상태
  
  // 단지코드 관련 정보
  Map<String, dynamic>? aptInfo;           // 아파트 단지 정보
  String? kaptCode;                        // 단지코드
  bool isLoadingAptInfo = false;            // 단지코드 조회 중
  String? kaptCodeStatusMessage;            // 단지코드 조회 상태 메시지
  String? _currentAptInfoRequestKey;

  @override
  void initState() {
    super.initState();
  }

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

  // VWorld API 데이터 로드 (백그라운드)
  Future<void> _loadVWorldData(String address, {Map<String, String>? fullAddrAPIData}) async {
    setState(() {
      isVWorldLoading = true;
      vworldError = null;
      vworldCoordinates = null;
    });
    
    try {
      final result = await VWorldService.getLandInfoFromAddress(
        address,
        fullAddrData: fullAddrAPIData,
      );
      
      if (mounted) {
        if (result != null) {
          setState(() {
            vworldCoordinates = result['coordinates'];
            isVWorldLoading = false;
          });
        } else {
          setState(() {
            isVWorldLoading = false;
            vworldError = '선택한 주소에서 정확한 좌표를 찾지 못했습니다. 주소를 다시 확인해주세요.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isVWorldLoading = false;
          vworldError = 'VWorld API 오류: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}';
        });
      }
    }
  }

  // 도로명 주소 검색 함수 (AddressService 사용)
  Future<void> searchRoadAddress(String keyword, {int page = 1, bool skipDebounce = false}) async {
    // 디바운싱 (페이지네이션은 제외)
    if (!skipDebounce && page == 1) {
      // 중복 요청 방지
      if (_lastSearchKeyword == keyword.trim() && isSearchingRoadAddr) {
        return;
      }
      
      // 이전 타이머 취소
      _addressSearchDebounceTimer?.cancel();
      
      // 디바운싱 적용
      _lastSearchKeyword = keyword.trim();
      _addressSearchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _performAddressSearch(keyword, page: page);
      });
      return;
    }
    
    // 페이지네이션이나 즉시 검색이 필요한 경우 바로 실행
    await _performAddressSearch(keyword, page: page);
  }
  
  // 실제 주소 검색 수행
  Future<void> _performAddressSearch(String keyword, {int page = 1}) async {
    setState(() {
      isSearchingRoadAddr = true;
      selectedRoadAddress = '';
      roadAddressList = [];
      if (page == 1) currentPage = 1;
    });

    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.addressSearchStarted,
      params: {
        'keyword': keyword,
        'page': page,
      },
      userId: widget.userId.isNotEmpty ? widget.userId : null,
      userName: widget.userName.isNotEmpty ? widget.userName : null,
      stage: FunnelStage.addressSearch,
    );

    try {
      final AddressSearchResult result = await AddressService().searchRoadAddress(keyword, page: page);

      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.addressSearchCompleted,
        params: {
          'keyword': keyword,
          'page': page,
          'resultsCount': result.addresses.length,
          'totalCount': result.totalCount,
          'error': result.errorMessage,
        },
        userId: widget.userId.isNotEmpty ? widget.userId : null,
        userName: widget.userName.isNotEmpty ? widget.userName : null,
        stage: FunnelStage.addressSearch,
      );

      setState(() {
        fullAddrAPIDataList = result.fullData;
        roadAddressList = result.addresses;
        totalCount = result.totalCount;
        currentPage = page;

        selectedFullAddrAPIData = {};
        selectedRoadAddress = '';
        selectedDetailAddress = '';
        selectedFullAddress = '';

        kaptCode = null;
        aptInfo = null;
        kaptCodeStatusMessage = null;

        hasAttemptedSearch = false;
        registerResult = null;
        registerError = null;
        ownerMismatchError = null;
        vworldCoordinates = null;
        vworldError = null;
        isVWorldLoading = false;

        if (result.errorMessage != null) {
          addressSearchMessage = result.errorMessage;
          addressSearchMessageIsWarning = true;
        } else if (roadAddressList.isNotEmpty) {
          addressSearchMessage = '검색 결과에서 주소를 선택해주세요.';
          addressSearchMessageIsWarning = false;
        } else {
          addressSearchMessage = '검색 결과가 없습니다.';
          addressSearchMessageIsWarning = true;
        }
      });
    } finally {
      setState(() {
        isSearchingRoadAddr = false;
      });
    }
  }
  
  /// 주소에서 단지코드 정보 자동 조회
  Future<void> _loadAptInfoFromAddress(String address, {Map<String, String>? fullAddrAPIData}) async {
    if (address.isEmpty) {
      return;
    }

    final requestKey = _buildAptInfoRequestKey(address, fullAddrAPIData);
    if (_currentAptInfoRequestKey != null &&
        _currentAptInfoRequestKey == requestKey &&
        isLoadingAptInfo) {
      return;
    }
    _currentAptInfoRequestKey = requestKey;

    setState(() {
      isLoadingAptInfo = true;
      aptInfo = null;
      kaptCode = null;
      kaptCodeStatusMessage = null;
    });
    
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

          setState(() {
            aptInfo = aptInfoResult;
            kaptCode = extractedKaptCodeFromResult;
            kaptCodeStatusMessage = null;
          });
        } else {
          setState(() {
            aptInfo = null;
            kaptCode = null;
            kaptCodeStatusMessage = '단지정보 API 응답이 비어 있습니다. 잠시 후 다시 시도해주세요.';
          });
        }
      } else {
        setState(() {
          aptInfo = null;
          kaptCode = null;
          kaptCodeStatusMessage = extractionResult.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aptInfo = null;
          kaptCode = null;
          kaptCodeStatusMessage = '단지 정보를 불러오는 중 오류가 발생했습니다. 다시 시도해주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAptInfo = false;
        });
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
    } catch (e) {
    } finally {
      setState(() {
        isRegisterLoading = false;
      });
    }
  }



  @override
  void dispose() {
    _controller.dispose();
    _detailController.dispose();
    _addressSearchDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = widget.userName.isNotEmpty;
    
    return WillPopScope(
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
        child: LoadingOverlay(
      isLoading: isRegisterLoading || isSaving || isVWorldLoading,
      message: isRegisterLoading
          ? '등기부등본 조회 중...'
          : isSaving
              ? '저장 중...'
              : '위치 정보 조회 중...',
      child: Scaffold(
        backgroundColor: AirbnbColors.background,
          resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // 상단 타이틀 섹션 (검색창 통합)
              HeroBanner(
                searchController: _controller,
                onSearchChanged: (val) {
                  setState(() => queryAddress = val);
                  // 자동 검색 (디바운싱은 searchRoadAddress 함수 내부에서 처리됨)
                  if (val.trim().isNotEmpty) {
                    searchRoadAddress(val.trim(), page: 1);
                  }
                },
                onSearchSubmitted: () {
                  if (_controller.text.trim().isNotEmpty) {
                    searchRoadAddress(_controller.text.trim(), page: 1);
                  }
                },
              ),
              SizedBox(height: AppSpacing.xl), // 32px - 주요 섹션 전환 (에어비엔비 스타일)
              if (isSearchingRoadAddr)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(AirbnbColors.primary),
                  ),
                ),
              if (roadAddressList.isNotEmpty)
                RoadAddressList(
                  fullAddrAPIDatas: fullAddrAPIDataList,
                  addresses: roadAddressList,
                  selectedAddress: selectedRoadAddress, // why?
                  onSelect: (fullData, displayAddr) async {
                    final roadAddr = (fullData['roadAddr'] ?? '').trim();
                    final jibunAddr = (fullData['jibunAddr'] ?? '').trim();
                    final cleanAddress = roadAddr.isNotEmpty ? roadAddr : jibunAddr;

                    AnalyticsService.instance.logEvent(
                      AnalyticsEventNames.addressSelected,
                      params: {
                        'address': cleanAddress,
                        'hasBuildingName': (fullData['bdNm'] ?? '').trim().isNotEmpty,
                        'roadCode': fullData['rnMgtSn'],
                        'bjdCode': fullData['admCd'],
                      },
                      userId: widget.userId.isNotEmpty ? widget.userId : null,
                      userName: widget.userName.isNotEmpty ? widget.userName : null,
                      stage: FunnelStage.addressSearch,
                    );

                    setState(() {
                      selectedFullAddrAPIData = fullData;
                      selectedRoadAddress = displayAddr;
                      selectedDetailAddress = '';
                      selectedFullAddress = cleanAddress;
                      _detailController.clear();
                      parsedAddress1st = AddressUtils.parseAddress1st(cleanAddress);
                      parsedDetail = {};
                      // 상태 초기화 후, 상세주소 입력 시에만 단지 정보 조회
                      hasAttemptedSearch = true;
                      registerResult = null;
                      registerError = null;
                      ownerMismatchError = null;
                      vworldCoordinates = null;
                      vworldError = null;
                      isVWorldLoading = false;
                      addressSearchMessage = null;
                      addressSearchMessageIsWarning = false;
                      kaptCodeStatusMessage = null;
                      // 단지 정보 초기화 (상세주소 입력 시에만 조회)
                      aptInfo = null;
                      kaptCode = null;
                      
                    });
                    
                    // 주소 선택 시 좌표만 조회 (단지 정보는 상세주소 입력 시 조회)
                    _loadVWorldData(
                      cleanAddress,
                      fullAddrAPIData: fullData.isNotEmpty ? fullData : null,
                    );
                  },
                ),
              if (totalCount > ApiConstants.pageSize)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (currentPage > 1)
                      Flexible(
                        child: AccessibleWidget.textButton(
                          label: '이전',
                          semanticLabel: '이전 페이지로 이동',
                          onPressed: () {
                            searchRoadAddress(
                              queryAddress.isNotEmpty ? queryAddress : _controller.text,
                              page: currentPage - 1,
                              skipDebounce: true,
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), // 16px
                      child: Text(
                        '페이지 $currentPage / ${((totalCount - 1) ~/ ApiConstants.pageSize) + 1}',
                        style: const TextStyle(
                          color: AirbnbColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (currentPage * ApiConstants.pageSize < totalCount)
                      Flexible(
                        child: AccessibleWidget.textButton(
                          label: '다음',
                          semanticLabel: '다음 페이지로 이동',
                          onPressed: () {
                            searchRoadAddress(
                              queryAddress.isNotEmpty ? queryAddress : _controller.text,
                              page: currentPage + 1,
                              skipDebounce: true,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              if (selectedRoadAddress.isNotEmpty && !selectedRoadAddress.startsWith('API 오류') && !selectedRoadAddress.startsWith('검색 결과 없음')) ...[
                // 선택된 주소 표시 - 에어비앤비 스타일 강화
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    margin: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),  // 24px, 16px (에어비엔비 스타일)
                    padding: EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),  // 24px (더 여유로운 패딩)
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
                            Icon(
                              Icons.check_circle_rounded,  // check_circle → check_circle_rounded
                              color: AirbnbColors.primary,  // primaryDark → primary (더 밝게)
                              size: 22,  // 20 → 22
                            ),
                            SizedBox(width: AppSpacing.sm),  // md → sm (더 컴팩트하게)
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
                        SizedBox(height: AppSpacing.sm),  // xs → sm (더 여유롭게)
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
                
                // 상세주소 입력 (선택사항)
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
                            aptInfo = null;
                            kaptCode = null;
                          }
                        });
                      },
                    ),
                  ),
                ),
                
                SizedBox(height: AppSpacing.md), // 16px
                
                // 공동주택 단지 정보 (주소 선택 후 자동으로 표시)
                if (hasAttemptedSearch)
                  Builder(
                    builder: (context) {
                      // 최대 너비 설정 (모바일: 전체 너비, 큰 화면: 900px)
                      const double maxContentWidth = 900;
                      
                      // 로딩 중일 때
                      if (isLoadingAptInfo) {
                        return Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: maxContentWidth),
                            margin: const EdgeInsets.only(top: AppSpacing.lg), // 24px
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), // 24px
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.lg), // 24px
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
                                  SizedBox(width: AppSpacing.md), // 16px
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
                            child: _buildAptInfoCard(),
                          ),
                        );
                      }

                      // 단지 정보가 없으면 조용히 종료 (공동주택이 아닐 수도 있으므로 경고 미노출)
                      return const SizedBox.shrink();
                    },
                  ),
              ],
              
              // 등기부등본 조회 오류 표시
              if (registerError != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                        SizedBox(width: AppSpacing.md), // 16px
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
                Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900), // 600 -> 900으로 변경
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md), // 24px, 16px
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
                              backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
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
                ),

              if (hasAttemptedSearch &&
                  selectedFullAddress.isNotEmpty &&
                  !(isLoggedIn && registerResult != null))
                SizedBox(height: AppSpacing.xxl), // 48px (버튼 높이 56px 고려하여 조정)

              _buildRegisterResultCard(isLoggedIn),
              
              // 웹 전용 푸터 여백 (영상 촬영용)
              if (kIsWeb) SizedBox(height: AppSpacing.xxxl * 9.375), // 특수 케이스 유지 (600px)
            ],
            ),
          ),
            ),
          ),
        ),
      ),
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
                SizedBox(height: AppSpacing.xs), // 4px
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
                    SizedBox(width: AppSpacing.md), // 16px
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
                    SizedBox(height: AppSpacing.md), // 16px
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
              SizedBox(height: AppSpacing.lg), // 24px
              if (selectedFullAddress.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (selectedFullAddress.isEmpty || isVWorldLoading)
                          ? null
                          : () async => _goToBrokerSearch(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
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
                ),
              if (selectedFullAddress.isNotEmpty)
                SizedBox(height: AppSpacing.xxl), // 48px (56px → 48px로 조정)
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
                SizedBox(width: AppSpacing.sm), // 8px
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
          Divider(height: 1, color: AirbnbColors.borderLight),
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
          SizedBox(width: AppSpacing.md), // 16px
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
  
  /// 단지 정보 카드 위젯
  Widget _buildAptInfoCard() {
    if (aptInfo == null) {
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
              if (aptInfo!['kaptCode'] != null && aptInfo!['kaptCode'].toString().isNotEmpty)
                _buildDetailRow('단지코드', aptInfo!['kaptCode'].toString()),
              if (aptInfo!['kaptName'] != null && aptInfo!['kaptName'].toString().isNotEmpty)
                _buildDetailRow('단지명', aptInfo!['kaptName'].toString()),
              if (aptInfo!['codeStr'] != null && aptInfo!['codeStr'].toString().isNotEmpty)
                _buildDetailRow('건물구조', aptInfo!['codeStr'].toString()),
            ],
          ),
        ),
        
        // 나머지 단지 정보 카드들 (기본정보와 일반관리 사이에 배치)
        _buildAptInfoCardBetweenBasicAndManagement(),
        
        // 일반 관리
        if ((aptInfo!['codeMgr'] != null && aptInfo!['codeMgr'].toString().isNotEmpty) ||
            (aptInfo!['kaptMgrCnt'] != null && aptInfo!['kaptMgrCnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptCcompany'] != null && aptInfo!['kaptCcompany'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.manage_accounts,
            title: '일반 관리',
            iconColor: AirbnbColors.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeMgr'] != null && aptInfo!['codeMgr'].toString().isNotEmpty)
                  _buildDetailRow('관리방식', aptInfo!['codeMgr'].toString()),
                if (aptInfo!['kaptMgrCnt'] != null && aptInfo!['kaptMgrCnt'].toString().isNotEmpty)
                  _buildDetailRow('관리사무소 수', '${aptInfo!['kaptMgrCnt']}개'),
                if (aptInfo!['kaptCcompany'] != null && aptInfo!['kaptCcompany'].toString().isNotEmpty)
                  _buildDetailRow('관리업체', aptInfo!['kaptCcompany'].toString()),
              ],
            ),
          ),
      ],
    );
  }

  /// 기본정보와 일반관리 사이에 표시할 단지 정보 카드 (기본정보와 일반관리 제외)
  Widget _buildAptInfoCardBetweenBasicAndManagement() {
    if (aptInfo == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 경비 관리
        if ((aptInfo!['codeSec'] != null && aptInfo!['codeSec'].toString().isNotEmpty) ||
            (aptInfo!['kaptdScnt'] != null && aptInfo!['kaptdScnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptdSecCom'] != null && aptInfo!['kaptdSecCom'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.security,
            title: '경비 관리',
            iconColor: AirbnbColors.error,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeSec'] != null && aptInfo!['codeSec'].toString().isNotEmpty)
                  _buildDetailRow('경비관리방식', aptInfo!['codeSec'].toString()),
                if (aptInfo!['kaptdScnt'] != null && aptInfo!['kaptdScnt'].toString().isNotEmpty)
                  _buildDetailRow('경비인력 수', '${aptInfo!['kaptdScnt']}명'),
                if (aptInfo!['kaptdSecCom'] != null && aptInfo!['kaptdSecCom'].toString().isNotEmpty)
                  _buildDetailRow('경비업체', aptInfo!['kaptdSecCom'].toString()),
              ],
            ),
          ),
        
        // 청소 관리
        if ((aptInfo!['codeClean'] != null && aptInfo!['codeClean'].toString().isNotEmpty) ||
            (aptInfo!['kaptdClcnt'] != null && aptInfo!['kaptdClcnt'].toString().isNotEmpty) ||
            (aptInfo!['codeGarbage'] != null && aptInfo!['codeGarbage'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.cleaning_services,
            title: '청소 관리',
            iconColor: AirbnbColors.success,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeClean'] != null && aptInfo!['codeClean'].toString().isNotEmpty)
                  _buildDetailRow('청소관리방식', aptInfo!['codeClean'].toString()),
                if (aptInfo!['kaptdClcnt'] != null && aptInfo!['kaptdClcnt'].toString().isNotEmpty)
                  _buildDetailRow('청소인력 수', '${aptInfo!['kaptdClcnt']}명'),
                if (aptInfo!['codeGarbage'] != null && aptInfo!['codeGarbage'].toString().isNotEmpty)
                  _buildDetailRow('음식물처리방법', aptInfo!['codeGarbage'].toString()),
              ],
            ),
          ),
        
        // 소독 관리
        if ((aptInfo!['codeDisinf'] != null && aptInfo!['codeDisinf'].toString().isNotEmpty) ||
            (aptInfo!['kaptdDcnt'] != null && aptInfo!['kaptdDcnt'].toString().isNotEmpty) ||
            (aptInfo!['disposalType'] != null && aptInfo!['disposalType'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.medical_services,
            title: '소독 관리',
            iconColor: AirbnbColors.primary,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeDisinf'] != null && aptInfo!['codeDisinf'].toString().isNotEmpty)
                  _buildDetailRow('소독관리방식', aptInfo!['codeDisinf'].toString()),
                if (aptInfo!['kaptdDcnt'] != null && aptInfo!['kaptdDcnt'].toString().isNotEmpty)
                  _buildDetailRow('소독인력 수', '${aptInfo!['kaptdDcnt']}명'),
                if (aptInfo!['disposalType'] != null && aptInfo!['disposalType'].toString().isNotEmpty)
                  _buildDetailRow('소독방법', aptInfo!['disposalType'].toString()),
              ],
            ),
          ),
        
        // 건물/시설 정보
        if ((aptInfo!['codeEcon'] != null && aptInfo!['codeEcon'].toString().isNotEmpty) ||
            (aptInfo!['codeEmgr'] != null && aptInfo!['codeEmgr'].toString().isNotEmpty) ||
            (aptInfo!['kaptdEcapa'] != null && aptInfo!['kaptdEcapa'].toString().isNotEmpty) ||
            (aptInfo!['codeFalarm'] != null && aptInfo!['codeFalarm'].toString().isNotEmpty) ||
            (aptInfo!['codeWsupply'] != null && aptInfo!['codeWsupply'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.home,
            title: '건물/시설',
            iconColor: AirbnbColors.warning,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['kaptdEcapa'] != null && aptInfo!['kaptdEcapa'].toString().isNotEmpty)
                  _buildDetailRow('수전용량', aptInfo!['kaptdEcapa'].toString()),
                if (aptInfo!['codeEcon'] != null && aptInfo!['codeEcon'].toString().isNotEmpty)
                  _buildDetailRow('세대전기계약방식', aptInfo!['codeEcon'].toString()),
                if (aptInfo!['codeEmgr'] != null && aptInfo!['codeEmgr'].toString().isNotEmpty)
                  _buildDetailRow('전기안전관리자법정선임여부', aptInfo!['codeEmgr'].toString()),
                if (aptInfo!['codeFalarm'] != null && aptInfo!['codeFalarm'].toString().isNotEmpty)
                  _buildDetailRow('화재수신반방식', aptInfo!['codeFalarm'].toString()),
                if (aptInfo!['codeWsupply'] != null && aptInfo!['codeWsupply'].toString().isNotEmpty)
                  _buildDetailRow('급수방식', aptInfo!['codeWsupply'].toString()),
              ],
            ),
          ),
        
        // 승강기/주차 정보
        if ((aptInfo!['codeElev'] != null && aptInfo!['codeElev'].toString().isNotEmpty) ||
            (aptInfo!['kaptdEcnt'] != null && aptInfo!['kaptdEcnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptdPcnt'] != null && aptInfo!['kaptdPcnt'].toString().isNotEmpty) ||
            (aptInfo!['kaptdPcntu'] != null && aptInfo!['kaptdPcntu'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.elevator,
            title: '승강기/주차',
            iconColor: AirbnbColors.teal,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeElev'] != null && aptInfo!['codeElev'].toString().isNotEmpty)
                  _buildDetailRow('승강기관리형태', aptInfo!['codeElev'].toString()),
                if (aptInfo!['kaptdEcnt'] != null && aptInfo!['kaptdEcnt'].toString().isNotEmpty)
                  _buildDetailRow('승강기대수', '${aptInfo!['kaptdEcnt']}대'),
                if (aptInfo!['kaptdPcnt'] != null && aptInfo!['kaptdPcnt'].toString().isNotEmpty)
                  _buildDetailRow('주차대수(지상)', '${aptInfo!['kaptdPcnt']}대'),
                if (aptInfo!['kaptdPcntu'] != null && aptInfo!['kaptdPcntu'].toString().isNotEmpty)
                  _buildDetailRow('주차대수(지하)', '${aptInfo!['kaptdPcntu']}대'),
              ],
            ),
          ),
        
        // 통신/보안시설
        if ((aptInfo!['codeNet'] != null && aptInfo!['codeNet'].toString().isNotEmpty) ||
            (aptInfo!['kaptdCccnt'] != null && aptInfo!['kaptdCccnt'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.camera_alt,
            title: '통신/보안시설',
            iconColor: AirbnbColors.blue,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['codeNet'] != null && aptInfo!['codeNet'].toString().isNotEmpty)
                  _buildDetailRow('주차관제/홈네트워크', aptInfo!['codeNet'].toString()),
                if (aptInfo!['kaptdCccnt'] != null && aptInfo!['kaptdCccnt'].toString().isNotEmpty)
                  _buildDetailRow('CCTV대수', '${aptInfo!['kaptdCccnt']}대'),
              ],
            ),
          ),
        
        // 편의/복리시설
        if ((aptInfo!['welfareFacility'] != null && aptInfo!['welfareFacility'].toString().isNotEmpty) ||
            (aptInfo!['convenientFacility'] != null && aptInfo!['convenientFacility'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.local_convenience_store,
            title: '편의/복리시설',
            iconColor: AirbnbColors.pink,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['welfareFacility'] != null && aptInfo!['welfareFacility'].toString().isNotEmpty)
                  _buildDetailRow('부대/복리시설', aptInfo!['welfareFacility'].toString()),
                if (aptInfo!['convenientFacility'] != null && aptInfo!['convenientFacility'].toString().isNotEmpty)
                  _buildDetailRow('편의시설', aptInfo!['convenientFacility'].toString()),
              ],
            ),
          ),
        
        // 교통 정보
        if ((aptInfo!['kaptdWtimebus'] != null && aptInfo!['kaptdWtimebus'].toString().isNotEmpty) ||
            (aptInfo!['subwayLine'] != null && aptInfo!['subwayLine'].toString().isNotEmpty) ||
            (aptInfo!['subwayStation'] != null && aptInfo!['subwayStation'].toString().isNotEmpty) ||
            (aptInfo!['kaptdWtimesub'] != null && aptInfo!['kaptdWtimesub'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.train,
            title: '교통 정보',
            iconColor: Colors.blueGrey,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['kaptdWtimebus'] != null && aptInfo!['kaptdWtimebus'].toString().isNotEmpty)
                  _buildDetailRow('버스정류장 거리', aptInfo!['kaptdWtimebus'].toString()),
                if (aptInfo!['subwayLine'] != null && aptInfo!['subwayLine'].toString().isNotEmpty)
                  _buildDetailRow('지하철호선', aptInfo!['subwayLine'].toString()),
                if (aptInfo!['subwayStation'] != null && aptInfo!['subwayStation'].toString().isNotEmpty)
                  _buildDetailRow('지하철역명', aptInfo!['subwayStation'].toString()),
                if (aptInfo!['kaptdWtimesub'] != null && aptInfo!['kaptdWtimesub'].toString().isNotEmpty)
                  _buildDetailRow('지하철역 거리', aptInfo!['kaptdWtimesub'].toString()),
              ],
            ),
          ),
        
        // 교육시설
        if (aptInfo!['educationFacility'] != null && aptInfo!['educationFacility'].toString().isNotEmpty)
          _buildRegisterCard(
            icon: Icons.school,
            title: '교육시설',
            iconColor: AirbnbColors.orange,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('교육시설', aptInfo!['educationFacility'].toString()),
              ],
            ),
          ),
        
        // 전기차 충전기
        if ((aptInfo!['groundElChargerCnt'] != null && aptInfo!['groundElChargerCnt'].toString().isNotEmpty) ||
            (aptInfo!['undergroundElChargerCnt'] != null && aptInfo!['undergroundElChargerCnt'].toString().isNotEmpty))
          _buildRegisterCard(
            icon: Icons.ev_station,
            title: '전기차 충전기',
            iconColor: Colors.lightGreen,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aptInfo!['groundElChargerCnt'] != null && aptInfo!['groundElChargerCnt'].toString().isNotEmpty)
                  _buildDetailRow('지상 전기차 충전기', '${aptInfo!['groundElChargerCnt']}대'),
                if (aptInfo!['undergroundElChargerCnt'] != null && aptInfo!['undergroundElChargerCnt'].toString().isNotEmpty)
                  _buildDetailRow('지하 전기차 충전기', '${aptInfo!['undergroundElChargerCnt']}대'),
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
                  SizedBox(height: AppSpacing.md), // 16px
                  Text(
                    '층별 면적',
                    style: AppTypography.withColor(
                      AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      AirbnbColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm), // 8px
                  ...building.floors.map((f) => Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                  )).toList(),
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
                        Padding(
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

/// 도로명 주소 검색 결과 리스트 위젯
class RoadAddressList extends StatelessWidget {
  final List<Map<String, String>> fullAddrAPIDatas;
  final List<String> addresses;
  final String selectedAddress;
  final void Function(Map<String, String>, String) onSelect;

  const RoadAddressList(
      {required this.fullAddrAPIDatas, required this.addresses, required this.selectedAddress, required this.onSelect, super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery
        .of(context)
        .size
        .width < 600;
    final horizontalMargin = isMobile ? 16.0 : 40.0;
    final itemPadding = isMobile ? 14.0 : 12.0;
    final fontSize = isMobile ? 17.0 : 15.0;
    // 18pt 이상인 경우 배경 사용, 미만인 경우 테두리/아이콘 강조
    final isLargeText = fontSize >= 18.0;

    List<Widget> listItems = [];
    for (int i = 0; i < addresses.length; i++) {
      final addr = addresses[i];
      final fullData = fullAddrAPIDatas[i];
      final isSelected = selectedAddress.trim() == addr.trim();
      
      // 선택된 항목의 스타일 결정: 큰 텍스트는 배경, 작은 텍스트는 테두리/아이콘 강조
      final selectedBackgroundColor = isSelected && isLargeText 
          ? AirbnbColors.primaryDark  // 18pt 이상: 더 진한 보라색 배경
          : (isSelected && !isLargeText 
              ? AirbnbColors.primaryDark.withValues(alpha: 0.08)  // 18pt 미만: 연한 배경
              : AirbnbColors.background);
      final selectedBorderColor = isSelected 
          ? AirbnbColors.primaryDark  // 선택된 항목: 더 진한 보라색 테두리
          : AirbnbColors.border;
      final selectedBorderWidth = isSelected ? (isLargeText ? 1.0 : 2.0) : 1.0;  // 작은 텍스트는 테두리 두껍게
      final selectedTextColor = isSelected && isLargeText
          ? AirbnbColors.background  // 큰 텍스트: 흰색
          : (isSelected && !isLargeText
              ? AirbnbColors.primaryDark  // 작은 텍스트: 보라색
              : AirbnbColors.textPrimary);
      
      listItems.add(
        Material(
          color: Colors.transparent,
          child: Semantics(
            label: '주소 선택: $addr',
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(fullData, addr),
              child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs), // 4px
              padding: EdgeInsets.symmetric(
                  vertical: itemPadding, horizontal: AppSpacing.lg), // 24px (18px → 24px)
              decoration: BoxDecoration(
                color: selectedBackgroundColor,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(
                  color: selectedBorderColor,
                  width: selectedBorderWidth,
                ),
                // 선택된 항목에 더 부드러운 그림자 적용 (에어비앤비 스타일)
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: AirbnbColors.primaryDark.withValues(alpha: 0.2),  // 0.3 → 0.2 (더 부드럽게)
                    blurRadius: 12,  // 8 → 12 (더 부드러운 그림자)
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ]
                    : [
                  // 선택되지 않은 항목에도 미세한 그림자 추가 (깊이감)
                  BoxShadow(
                    color: AirbnbColors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  // 선택된 항목 체크 아이콘 - 더 명확한 시각적 피드백
                  if (isSelected) Icon(
                      Icons.check_circle_rounded,  // rounded 스타일로 통일성 강화
                      color: isLargeText 
                          ? AirbnbColors.background  // 보라색 배경 위: 흰색
                          : AirbnbColors.primaryDark,  // 연한 배경 위: 보라색
                      size: 22),  // 20 → 22로 약간 크게
                  if (isSelected) SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          addr.split('\n').first,
                          style: TextStyle(
                            color: selectedTextColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: fontSize,
                          ),
                        ),
                        if (addr.contains('\n'))
                          Padding(
                            padding: EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              addr.split('\n').skip(1).join('\n'),
                              style: TextStyle(
                                // 보라색 배경 위에서는 완전한 흰색으로 가독성 극대화
                                color: isSelected && isLargeText
                                    ? AirbnbColors.background  // 완전한 흰색 (alpha 제거)
                                    : (isSelected && !isLargeText
                                        ? AirbnbColors.primaryDark.withValues(alpha: 0.8)  // 약간 더 진하게
                                        : AirbnbColors.textSecondary),
                                fontWeight: FontWeight.w500,
                                fontSize: fontSize - 2,
                                height: 1.3,  // 1.25 → 1.3으로 가독성 개선
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900),
        margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: AppSpacing.md), // 16px
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 검색 결과 헤더 - 에어비앤비 스타일 강화
          Container(
            decoration: BoxDecoration(
              color: AirbnbColors.surface,  // background → surface로 변경 (더 부드러운 회색)
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AirbnbColors.borderLight,  // 더 연한 테두리
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // 아이콘 영역 - 더 명확한 시각적 구분
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary.withValues(alpha: 0.1),  // 0.08 → 0.1로 약간 진하게
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,  // outlined 스타일로 통일성 강화
                    color: AirbnbColors.primary,
                    size: 22,  // 20 → 22로 약간 크게
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,  // lg → md로 조정 (더 컴팩트하게)
                    ),
                    child: Text(
                      '검색 결과 ${addresses.length}건',
                      style: AppTypography.withColor(
                        AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,  // w700 → w600 (더 부드럽게)
                          letterSpacing: -0.15,  // -0.2 → -0.15
                        ),
                        AirbnbColors.textPrimary,  // primary → textPrimary (더 자연스럽게)
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
                    SizedBox(height: AppSpacing.md), // 16px
          ...listItems,
        ],
      ),
      ),
    );
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
          border: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(10)),
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
            child: Icon(
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
                    SizedBox(width: AppSpacing.sm), // 8px
                    Text(
                      isLoading ? '위치 정보 조회 중...' : (error != null ? '위치 정보 조회 실패' : '위치 정보'),
                      style: AppTypography.withColor(
                        AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                        isLoading ? AirbnbColors.textSecondary : (error != null ? AirbnbColors.warning : AirbnbColors.primary),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md), // 16px
                
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
                        SizedBox(width: AppSpacing.md), // 16px
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
                SizedBox(width: AppSpacing.md), // 16px
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
                SizedBox(height: AppSpacing.sm), // 8px
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

