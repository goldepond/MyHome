import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:property/constants/app_constants.dart';

enum KaptCodeFailureReason {
  invalidInput,
  missingAddressData,
  missingComplexName,
  apiError,
  noMatch,
  regionMismatch,
}

class KaptCodeExtractionResult {
  final String? code;
  final KaptCodeFailureReason? failure;
  final String message;

  bool get isSuccess => code != null && code!.isNotEmpty;

  const KaptCodeExtractionResult._({
    this.code,
    this.failure,
    required this.message,
  });

  factory KaptCodeExtractionResult.success(String code) {
    return KaptCodeExtractionResult._(
      code: code,
      failure: null,
      message: '단지코드 추출 성공',
    );
  }

  factory KaptCodeExtractionResult.failure(KaptCodeFailureReason reason, String message) {
    return KaptCodeExtractionResult._(
      code: null,
      failure: reason,
      message: message,
    );
  }
}

class _CachedKaptCodeEntry {
  final KaptCodeExtractionResult result;
  final DateTime timestamp;

  const _CachedKaptCodeEntry({
    required this.result,
    required this.timestamp,
  });

  bool isExpired(Duration ttl) => DateTime.now().difference(timestamp) > ttl;
}

class AptInfoService {
  static const Duration _cacheTTL = Duration(minutes: 5);
  static const int _cacheLimit = 50;
  static final Map<String, _CachedKaptCodeEntry> _kaptCodeCache = {};
  static final Map<String, Future<KaptCodeExtractionResult>> _pendingRequests = {};

  /// 아파트 기본정보 조회
  static Future<Map<String, dynamic>?> getAptBasisInfo(String kaptCode) async {
    try {
      // ServiceKey 확인
      final serviceKey = ApiConstants.data_go_kr_serviceKey;
      print('=== 아파트 정보 조회 API 호출 ===');
      print('ServiceKey 존재 여부: ${serviceKey.isNotEmpty}');
      print('ServiceKey 길이: ${serviceKey.length}');
      if (serviceKey.isNotEmpty) {
        print('ServiceKey (처음 10자): ${serviceKey.substring(0, serviceKey.length > 10 ? 10 : serviceKey.length)}...');
      } else {
        print('⚠️ DATA_GO_KR_SERVICE_KEY가 설정되지 않았습니다. API 호출을 건너뜁니다.');
        print('💡 해결 방법: --dart-define=DATA_GO_KR_SERVICE_KEY=여기에_실제_API_키_입력');
        return null;
      }
      
      // ServiceKey URL 인코딩 문제 방지를 위해 queryParameters 사용
      // API 문서에 따르면 Encoding된 인증키를 사용해야 함
      // Uri.replace()가 자동으로 URL 인코딩해줌
      const baseUrl = ApiConstants.aptInfoAPIBaseUrl;
      final queryParams = {
        'ServiceKey': serviceKey, // Decoding된 키 (Uri가 자동 인코딩)
        'kaptCode': kaptCode,
      };
      print('요청 파라미터: ServiceKey=${serviceKey.isNotEmpty ? "***설정됨***" : "❌비어있음"}, kaptCode=$kaptCode');
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      print('생성된 URI: ${uri.toString()}');

      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );
      
      print('프록시 URI: ${proxyUri.toString()}');
      
      print('=== HTTP 요청 시작 ===');
      http.Response response;
      try {
        print('프록시 서버로 요청 전송 중...');
        response = await http.get(proxyUri).timeout(
          Duration(seconds: ApiConstants.requestTimeoutSeconds),
          onTimeout: () {
            print('⏱️ 요청 타임아웃 발생');
            throw TimeoutException('아파트 정보 조회 시간이 초과되었습니다.');
          },
        );
        print('=== HTTP 응답 수신 ===');
        print('상태 코드: ${response.statusCode}');
        print('응답 헤더: ${response.headers}');
        print('응답 본문 길이: ${response.body.length} bytes');
      } catch (e) {
        print('❌ HTTP 요청 오류 발생');
        print('오류 타입: ${e.runtimeType}');
        print('오류 메시지: $e');
        // HTTP 요청 자체가 실패한 경우
        if (e is TimeoutException) {
          print('타임아웃으로 인한 실패');
          return null;
        }
        // 기타 네트워크 오류
        print('네트워크 오류로 인한 실패');
        return null;
      }
      
      print('=== 응답 상태 확인 ===');
      // UTF-8 디코딩으로 응답 본문 가져오기
      String responseBody;
      try {
        responseBody = utf8.decode(response.bodyBytes);
      } catch (e) {
        responseBody = response.body;
      }

      if (response.statusCode == 200) {
        try {
          final data = json.decode(responseBody);
          
          // 응답 구조 확인
          if (data['response'] != null) {
            final responseData = data['response'];
            
            // 에러 체크
            if (responseData['header'] != null) {
              final header = responseData['header'];
              final resultCode = header['resultCode']?.toString() ?? '';
              
              // 에러 코드가 있는 경우
              if (resultCode != '00' && resultCode != '0') {
                return null;
              }
            }
            
            if (responseData['body'] != null) {
              final body = responseData['body'];
              
              // 응답 구조 확인: body['item'] 또는 body['items']['item']
              dynamic item;
              if (body['item'] != null) {
                // 직접 item이 있는 경우 (getAphusDtlInfoV4)
                item = body['item'];
                final parsed = _parseAptInfo(item);
                return parsed;
              } else if (body['items'] != null && body['items']['item'] != null) {
                // items 안에 item이 있는 경우 (다른 API)
                item = body['items']['item'];
                final parsed = _parseAptInfo(item);
                return parsed;
              } else {
                return null;
              }
            } else {
              return null;
            }
          } else {
            return null;
          }
        } catch (e) {
          return null;
        }
      } else {
        // 응답 본문이 JSON 형식인지 확인
        try {
          final errorData = json.decode(responseBody);
          
          if (errorData['response'] != null && errorData['response']['header'] != null) {
            // 에러 처리 로직 필요 시 사용
          }
        } catch (_) {
          // 에러 발생 시 무시
        }
        
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// 아파트 정보 파싱
  static Map<String, dynamic> _parseAptInfo(dynamic item) {
    final Map<String, dynamic> aptInfo = {};
    
    try {
      // 기본 정보
      aptInfo['kaptCode'] = item['kaptCode'] ?? ''; // 단지코드
      aptInfo['kaptName'] = item['kaptName'] ?? ''; // 단지명
      
      // 관리 정보
      aptInfo['codeMgr'] = item['codeMgr'] ?? ''; // 관리방식
      aptInfo['kaptMgrCnt'] = item['kaptMgrCnt'] ?? ''; // 관리사무소 수
      aptInfo['kaptCcompany'] = item['kaptCcompany'] ?? ''; // 관리업체
      
      // 보안 정보
      aptInfo['codeSec'] = item['codeSec'] ?? ''; // 보안관리방식
      aptInfo['kaptdScnt'] = item['kaptdScnt'] ?? ''; // 보안인력 수
      aptInfo['kaptdSecCom'] = item['kaptdSecCom'] ?? ''; // 보안업체
      
      // 청소 정보
      aptInfo['codeClean'] = item['codeClean'] ?? ''; // 청소관리방식
      aptInfo['kaptdClcnt'] = item['kaptdClcnt'] ?? ''; // 청소인력 수
      aptInfo['codeGarbage'] = item['codeGarbage'] ?? ''; // 쓰레기 수거방식
      
      // 소독 정보
      aptInfo['codeDisinf'] = item['codeDisinf'] ?? ''; // 소독관리방식
      aptInfo['kaptdDcnt'] = item['kaptdDcnt'] ?? ''; // 소독인력 수
      aptInfo['disposalType'] = item['disposalType'] ?? ''; // 소독방식
      
      // 건물 정보
      aptInfo['codeStr'] = item['codeStr'] ?? ''; // 건물구조
      aptInfo['kaptdEcapa'] = item['kaptdEcapa'] ?? ''; // 전기용량
      aptInfo['codeEcon'] = item['codeEcon'] ?? ''; // 전기계약방식
      aptInfo['codeEmgr'] = item['codeEmgr'] ?? ''; // 전기관리방식
      
      // 소방 정보
      aptInfo['codeFalarm'] = item['codeFalarm'] ?? ''; // 화재경보기 타입
      
      // 급수 정보
      aptInfo['codeWsupply'] = item['codeWsupply'] ?? ''; // 급수방식
      
      // 엘리베이터 정보
      aptInfo['codeElev'] = item['codeElev'] ?? ''; // 엘리베이터 관리방식
      aptInfo['kaptdEcnt'] = item['kaptdEcnt'] ?? ''; // 엘리베이터 수
      
      // 주차 정보
      aptInfo['kaptdPcnt'] = item['kaptdPcnt'] ?? ''; // 지상주차장 수
      aptInfo['kaptdPcntu'] = item['kaptdPcntu'] ?? ''; // 지하주차장 수
      
      // 통신 정보
      aptInfo['codeNet'] = item['codeNet'] ?? ''; // 인터넷 설치여부
      aptInfo['kaptdCccnt'] = item['kaptdCccnt'] ?? ''; // CCTV 수
      
      // 편의시설
      aptInfo['welfareFacility'] = item['welfareFacility'] ?? ''; // 복리시설
      
      // 교통 정보
      aptInfo['kaptdWtimebus'] = item['kaptdWtimebus'] ?? ''; // 버스 도보시간
      aptInfo['subwayLine'] = item['subwayLine'] ?? ''; // 지하철 노선
      aptInfo['subwayStation'] = item['subwayStation'] ?? ''; // 지하철역
      aptInfo['kaptdWtimesub'] = item['kaptdWtimesub'] ?? ''; // 지하철 도보시간
      
      // 주변시설
      aptInfo['convenientFacility'] = item['convenientFacility'] ?? ''; // 편의시설
      aptInfo['educationFacility'] = item['educationFacility'] ?? ''; // 교육시설
      
      // 전기차 충전기
      aptInfo['groundElChargerCnt'] = item['groundElChargerCnt'] ?? ''; // 지상 전기차 충전기 수
      aptInfo['undergroundElChargerCnt'] = item['undergroundElChargerCnt'] ?? ''; // 지하 전기차 충전기 수
      
      // 사용여부
      aptInfo['useYn'] = item['useYn'] ?? ''; // 사용여부
    } catch (_) {
      // 파싱 오류 시 빈 Map 반환
    }
    
    return aptInfo;
  }

  /// 주소에서 단지명 추출
  /// 
  /// 주소 형식 예시:
  /// - "서울특별시 중구 청구로 64 (신당동, 청구 e편한세상)" -> "청구 e편한세상"
  /// - "서울특별시 중구 수표로 67-2 (수표동)" -> null (단지명 없음)
  static String? extractComplexNameFromAddress(String address) {
    if (address.isEmpty) return null;

    // 괄호 안의 내용 추출
    final bracketMatch = RegExp(r'\(([^)]+)\)').firstMatch(address);
    if (bracketMatch == null || bracketMatch.groupCount == 0) {
      return null;
    }
    
    final bracketContent = bracketMatch.group(1) ?? '';
    
    // 단지명 패턴 (더 많은 패턴 포함)
    final complexPattern = RegExp(r'(아파트|주택|단지|뷰|힐|파크|타운|빌|e편한세상|편한세상|래미안|자이|아이파크|힐스테이트|디자인|센트럴|센트리|팰리스|팔래스|프리미엄|프리미어|하이츠|하임|시티|타워|맨션|빌리지|뷰티풀|라인|스타|스마트|헤리움|신금호)', caseSensitive: false);
    
    // 동 이름 패턴 (제외할 패턴)
    final dongPattern = RegExp(r'^[가-힣]+동\d*가?$|^[가-힣]+동$', caseSensitive: false);
    
    // 쉼표로 구분된 경우
    if (bracketContent.contains(',')) {
      final parts = bracketContent.split(',').map((e) => e.trim()).toList();
      
      // 각 부분을 확인하여 단지명 찾기
      for (int i = parts.length - 1; i >= 0; i--) {
        final part = parts[i];
        
        // 동 이름 패턴이 아닌 경우에만 단지명으로 판단
        if (!dongPattern.hasMatch(part)) {
          // 단지명 패턴이 있는지 확인
          if (complexPattern.hasMatch(part)) {
            return part;
          } else {
            // 패턴이 없어도 길이가 3자 이상이고 숫자+동 형식이 아니면 단지명 가능성
            if (part.length >= 3 && !RegExp(r'^\d+동$').hasMatch(part)) {
              return part;
            }
          }
        }
      }
    } else {
      // 동 이름이 아닌 경우
      if (!dongPattern.hasMatch(bracketContent)) {
        // 단지명 패턴 확인
        if (complexPattern.hasMatch(bracketContent)) {
          return bracketContent;
        } else {
          // 패턴이 없어도 길이가 3자 이상이면 단지명 가능성
          if (bracketContent.length >= 3) {
            return bracketContent;
          }
        }
      }
    }
    
    return null;
  }
  
  /// API 응답에서 itemList 추출 헬퍼 메서드 (중복 코드 제거)
  static List<dynamic> _extractItemList(dynamic items) {
    if (items is List) {
      return items.cast<dynamic>();
    } else if (items is Map) {
      final itemValue = items['item'];
      if (itemValue != null) {
        if (itemValue is List) {
          return itemValue.cast<dynamic>();
        } else {
          return [itemValue];
        }
      }
    }
    return [];
  }
  
  /// 도로명코드로 단지코드 검색
  /// 
  /// 공동주택 단지 목록 제공 서비스의 도로명 아파트 목록 API 사용
  /// roadCode: 시군구번호+도로명번호
  static Future<String?> searchKaptCodeByRoadCode(String roadCode) async {
    if (roadCode.isEmpty) return null;
    
    // ServiceKey 확인
    final serviceKey = ApiConstants.data_go_kr_serviceKey;
    if (serviceKey.isEmpty) {
      print('⚠️ DATA_GO_KR_SERVICE_KEY가 설정되지 않았습니다.');
      return null;
    }
    
    try {
      const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final queryParams = {
        'ServiceKey': serviceKey,
        'roadCode': roadCode,
        '_type': 'json',
        'numOfRows': '10',
        'pageNo': '1',
      };
      final uri = Uri.parse('$baseUrl/getRoadnameAptList3').replace(queryParameters: queryParams);
      
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );
      
      final response = await http.get(proxyUri);
      
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody);
        
        if (data['response']?['body']?['items'] != null) {
          final itemList = _extractItemList(data['response']!['body']!['items']);
          if (itemList.isNotEmpty) {
            return itemList[0]['kaptCode']?.toString() ?? '';
          }
        }
      }
    } catch (e) {
      // 단지코드 검색 실패 시 null 반환
    }
    
    return null;
  }
  
  /// 법정동코드로 단지코드 검색
  /// 
  /// 공동주택 단지 목록 제공 서비스의 법정동 아파트 목록 API 사용
  /// bjdCode: 시군구코드+법정동코드
  static Future<String?> searchKaptCodeByBjdCode(String bjdCode) async {
    if (bjdCode.isEmpty) {
      return null;
    }
    
    // ServiceKey 확인
    final serviceKey = ApiConstants.data_go_kr_serviceKey;
    if (serviceKey.isEmpty) {
      print('⚠️ DATA_GO_KR_SERVICE_KEY가 설정되지 않았습니다.');
      return null;
    }
    
    try {
      
      const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final queryParams = {
        'ServiceKey': serviceKey,
        'bjdCode': bjdCode,
        '_type': 'json',
        'numOfRows': '10',
        'pageNo': '1',
      };
      final uri = Uri.parse('$baseUrl/getLegaldongAptList3').replace(queryParameters: queryParams);
      
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );
      
      final response = await http.get(proxyUri);
      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        
        final data = json.decode(responseBody);
        
        if (data['response']?['body']?['items'] != null) {
          final itemList = _extractItemList(data['response']!['body']!['items']);
          if (itemList.isNotEmpty) {
            return itemList[0]['kaptCode']?.toString() ?? '';
          }
        }
      }
    } catch (_) {
      // 단지코드 검색 실패 시 null 반환
    }
    
    return null;
  }
  
  /// 단지코드 추출 (주소에서 추출하거나 기본값 사용)
  /// 
  /// 주의: 현재는 제한적인 매칭만 지원합니다.
  /// 공동주택인 경우 주소에서 건물명을 추출하여 단지코드를 찾습니다.
  /// 
  /// 이 함수는 동기 함수이므로 하드코딩된 매칭만 반환합니다.
  /// 실제 단지명 검색은 extractKaptCodeFromAddressAsync를 사용하세요.
  static String extractKaptCodeFromAddress(String address) {
    if (address.isEmpty) return '';
    
    // 하드코딩된 매칭 (빠른 응답을 위한 캐시)
    if (address.contains('우성아파트') || 
        address.contains('서현시범우성') ||
        (address.contains('분당구') && address.contains('서현'))) {
      return 'A46377309'; // 우성아파트 단지코드
    }
    
    // 매칭 실패 시 빈 문자열 반환
    return '';
  }
  
  /// 주소 검색 API 데이터에서 도로명코드/법정동코드 추출
  /// 
  /// 주소 검색 API 응답 데이터에서 도로명코드나 법정동코드를 추출합니다.
  /// fullAddrAPIData: 주소 검색 API에서 반환된 원본 데이터 (Map<String, String>)
  static Map<String, String?> extractCodesFromAddressData(Map<String, String>? fullAddrAPIData) {
    if (fullAddrAPIData == null || fullAddrAPIData.isEmpty) {
      return {'roadCode': null, 'bjdCode': null};
    }
    
    // 도로명코드 추출
    String? roadCode;
    final rnMgtSn = fullAddrAPIData['rnMgtSn'] ?? '';
    if (rnMgtSn.isNotEmpty) {
      roadCode = rnMgtSn.length >= 12 ? rnMgtSn.substring(0, 12) : rnMgtSn;
    }
    
    // 법정동코드 추출
    String? bjdCode;
    final admCd = fullAddrAPIData['admCd'] ?? '';
    if (admCd.isNotEmpty) {
      bjdCode = admCd.length >= 10 ? admCd.substring(0, 10) : admCd;
    }
    
    return {'roadCode': roadCode, 'bjdCode': bjdCode};
  }
  
  /// 주소에서 단지코드를 비동기로 추출 (도로명코드/법정동코드 우선, 단지명 검색 fallback)
  static Future<KaptCodeExtractionResult> extractKaptCodeFromAddressAsync(
    String address, {
    Map<String, String>? fullAddrAPIData,
  }) async {
    _pruneExpiredCache();

    final trimmedAddress = address.trim();
    if (trimmedAddress.isEmpty) {
      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.invalidInput,
        '주소가 비어 있어 단지코드를 조회할 수 없습니다.',
      );
    }

    final hardcodedCode = extractKaptCodeFromAddress(trimmedAddress);
    if (hardcodedCode.isNotEmpty) {
      return KaptCodeExtractionResult.success(hardcodedCode);
    }

    if (fullAddrAPIData == null || fullAddrAPIData.isEmpty) {
      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.missingAddressData,
        '주소 검색 결과가 없어 단지코드를 조회할 수 없습니다. 먼저 주소 검색 결과에서 항목을 선택해주세요.',
      );
    }

    final codes = extractCodesFromAddressData(fullAddrAPIData);
    final roadCode = codes['roadCode'];
    final bjdCode = codes['bjdCode'];

    String? complexName = fullAddrAPIData['bdNm']?.trim();
    if (complexName == null || complexName.isEmpty) {
      complexName = extractComplexNameFromAddress(trimmedAddress)?.trim();
    }
    if (complexName == null || complexName.isEmpty) {
      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.missingComplexName,
        '해당 주소에서는 단지코드를 찾을 수 없습니다.',
      );
    }

    final cacheKey = _buildCacheKey(
      trimmedAddress,
      complexName,
      roadCode,
      bjdCode,
    );

    final cachedEntry = _kaptCodeCache[cacheKey];
    if (cachedEntry != null) {
      if (!cachedEntry.isExpired(_cacheTTL)) {
        return cachedEntry.result;
      }
      _kaptCodeCache.remove(cacheKey);
    }

    final inFlight = _pendingRequests[cacheKey];
    if (inFlight != null) {
      return await inFlight;
    }

    final future = _extractKaptCodeInternal(
      trimmedAddress: trimmedAddress,
      complexName: complexName,
      roadCode: roadCode,
      bjdCode: bjdCode,
      fullAddrAPIData: fullAddrAPIData,
    );

    _pendingRequests[cacheKey] = future;

    try {
      final result = await future;
      if (result.isSuccess) {
        _kaptCodeCache[cacheKey] = _CachedKaptCodeEntry(
          result: result,
          timestamp: DateTime.now(),
        );
        _enforceCacheLimit();
      }
      return result;
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }

  static Future<KaptCodeExtractionResult> _extractKaptCodeInternal({
    required String trimmedAddress,
    required String complexName,
    String? roadCode,
    String? bjdCode,
    required Map<String, String> fullAddrAPIData,
  }) async {
    KaptCodeExtractionResult? failureCandidate;

    if (bjdCode != null && bjdCode.isNotEmpty) {
      final bjdResult = await _fetchKaptCodeByBjdCode(
        bjdCode: bjdCode,
        complexName: complexName,
        address: trimmedAddress,
        fullAddrAPIData: fullAddrAPIData,
      );
      if (bjdResult.isSuccess) {
        return bjdResult;
      }
      failureCandidate ??= bjdResult;
    }

    if (roadCode != null && roadCode.isNotEmpty) {
      final roadResult = await _fetchKaptCodeByRoadCode(
        roadCode: roadCode,
        complexName: complexName,
        address: trimmedAddress,
        fullAddrAPIData: fullAddrAPIData,
      );
      if (roadResult.isSuccess) {
        return roadResult;
      }
      failureCandidate ??= roadResult;
    }

    return failureCandidate ??
        KaptCodeExtractionResult.failure(
          KaptCodeFailureReason.noMatch,
          '단지코드를 찾지 못했습니다. 공동주택 주소인지, 건물명이 정확한지 확인해주세요.',
        );
  }

  static Future<KaptCodeExtractionResult> _fetchKaptCodeByRoadCode({
    required String roadCode,
    required String complexName,
    required String address,
    required Map<String, String> fullAddrAPIData,
  }) async {
    // ServiceKey 확인
    final serviceKey = ApiConstants.data_go_kr_serviceKey;
    if (serviceKey.isEmpty) {
      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.apiError,
        'DATA_GO_KR_SERVICE_KEY가 설정되지 않았습니다.',
      );
    }
    
    try {
      const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final queryParams = {
        'ServiceKey': serviceKey,
        'roadCode': roadCode,
        '_type': 'json',
        'numOfRows': '50',
        'pageNo': '1',
      };
      final uri = Uri.parse('$baseUrl/getRoadnameAptList3').replace(queryParameters: queryParams);
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );

      final response = await http.get(proxyUri);
      if (response.statusCode != 200) {
        return KaptCodeExtractionResult.failure(
          KaptCodeFailureReason.apiError,
          '도로명코드 기반 단지 조회에 실패했습니다. (HTTP ${response.statusCode})',
        );
      }

      final responseBody = utf8.decode(response.bodyBytes);
      final data = json.decode(responseBody);
      final itemList = _extractItemList(data['response']?['body']?['items']);

      if (itemList.isEmpty) {
        return KaptCodeExtractionResult.failure(
          KaptCodeFailureReason.noMatch,
          '도로명코드로 단지 정보를 찾지 못했습니다.',
        );
      }

      bool hasNameMatch = false;
      bool hasRegionMismatch = false;
      final matchedCode = _matchAndValidateByNameAndRegion(
        itemList: itemList,
        complexName: complexName,
        address: address,
        fullAddrAPIData: fullAddrAPIData,
        onCandidateEvaluated: (nameMatched, regionMatched) {
          if (nameMatched) {
            hasNameMatch = true;
            if (!regionMatched) {
              hasRegionMismatch = true;
            }
          }
        },
      );

      if (matchedCode != null) {
        return KaptCodeExtractionResult.success(matchedCode);
      }

      if (hasNameMatch && hasRegionMismatch) {
        return KaptCodeExtractionResult.failure(
          KaptCodeFailureReason.regionMismatch,
          '단지명은 일치하지만 주소(구/동 또는 코드)가 맞지 않습니다.',
        );
      }

      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.noMatch,
        '도로명코드로 단지 정보를 찾지 못했습니다.',
      );
    } catch (e) {
      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.apiError,
        '도로명코드 기반 단지 조회 중 오류가 발생했습니다.',
      );
    }
  }

  static Future<KaptCodeExtractionResult> _fetchKaptCodeByBjdCode({
    required String bjdCode,
    required String complexName,
    required String address,
    required Map<String, String> fullAddrAPIData,
  }) async {
    // ServiceKey 확인
    final serviceKey = ApiConstants.data_go_kr_serviceKey;
    if (serviceKey.isEmpty) {
      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.apiError,
        'DATA_GO_KR_SERVICE_KEY가 설정되지 않았습니다.',
      );
    }
    
    try {
      const baseUrl = 'https://apis.data.go.kr/1613000/AptListService3';
      final queryParams = {
        'ServiceKey': serviceKey,
        'bjdCode': bjdCode,
        '_type': 'json',
        'numOfRows': '50',
        'pageNo': '1',
      };
      final uri = Uri.parse('$baseUrl/getLegaldongAptList3').replace(queryParameters: queryParams);
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );

      final response = await http.get(proxyUri);
      if (response.statusCode != 200) {
        return KaptCodeExtractionResult.failure(
          KaptCodeFailureReason.apiError,
          '법정동코드 기반 단지 조회에 실패했습니다. (HTTP ${response.statusCode})',
        );
      }

      final responseBody = utf8.decode(response.bodyBytes);
      final data = json.decode(responseBody);
      final itemList = _extractItemList(data['response']?['body']?['items']);

      if (itemList.isEmpty) {
        return KaptCodeExtractionResult.failure(
          KaptCodeFailureReason.noMatch,
          '법정동코드로 단지 정보를 찾지 못했습니다.',
        );
      }

      bool hasNameMatch = false;
      bool hasRegionMismatch = false;
      final matchedCode = _matchAndValidateByNameAndRegion(
        itemList: itemList,
        complexName: complexName,
        address: address,
        fullAddrAPIData: fullAddrAPIData,
        onCandidateEvaluated: (nameMatched, regionMatched) {
          if (nameMatched) {
            hasNameMatch = true;
            if (!regionMatched) {
              hasRegionMismatch = true;
            }
          }
        },
      );

      if (matchedCode != null) {
        return KaptCodeExtractionResult.success(matchedCode);
      }

      if (hasNameMatch && hasRegionMismatch) {
        return KaptCodeExtractionResult.failure(
          KaptCodeFailureReason.regionMismatch,
          '단지명은 일치하지만 주소(구/동 또는 코드)가 맞지 않습니다.',
        );
      }

      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.noMatch,
        '법정동코드로 단지 정보를 찾지 못했습니다.',
      );
    } catch (e) {
      return KaptCodeExtractionResult.failure(
        KaptCodeFailureReason.apiError,
        '법정동코드 기반 단지 조회 중 오류가 발생했습니다.',
      );
    }
  }

  static String? _matchAndValidateByNameAndRegion({
    required List<dynamic> itemList,
    required String complexName,
    required String address,
    required Map<String, String> fullAddrAPIData,
    void Function(bool nameMatched, bool regionMatched)? onCandidateEvaluated,
  }) {
    final normalizedTarget = _normalizeName(complexName);
    if (normalizedTarget.length < 3) {
      return null;
    }

    for (final itemRaw in itemList) {
      final item = itemRaw as Map<String, dynamic>;
      final kaptCode = item['kaptCode']?.toString() ?? '';
      final kaptName = item['kaptName']?.toString() ?? '';
      if (kaptCode.isEmpty || kaptName.isEmpty) continue;

      final normalizedKaptName = _normalizeName(kaptName);
      final itemBjd = item['bjdCode'] ?? item['bjdcode'] ?? item['bjdCd'] ?? item['bjdcd'];
      final itemRoadCode = item['roadCode'] ?? item['roadCd'] ?? item['road_cd'] ?? item['doroCode'];

      final bool nameMatches = normalizedKaptName == normalizedTarget ||
          normalizedKaptName.contains(normalizedTarget) ||
          normalizedTarget.contains(normalizedKaptName);

      if (nameMatches) {
        final ok = _crossValidateRegion(item: item, address: address, fullAddrAPIData: fullAddrAPIData);
        onCandidateEvaluated?.call(true, ok);
        if (ok) {
          return kaptCode;
        }
        // 지역 매칭이 실패했더라도, API 응답에 법정동/도로명 코드가 비어있다면 이름 일치만으로도 허용
        final hasRegionData =
            (itemBjd != null && itemBjd.toString().isNotEmpty) ||
            (itemRoadCode != null && itemRoadCode.toString().isNotEmpty);
        if (!hasRegionData) {
          return kaptCode;
        }
      }
    }

    return null;
  }

  static bool _crossValidateRegion({
    required Map<String, dynamic> item,
    required String address,
    required Map<String, String> fullAddrAPIData,
  }) {
    final itemRoad = item['roadAddr']?.toString() ?? '';
    final itemJibun = item['jibunAddr']?.toString() ?? '';
    final combined = '$itemRoad $itemJibun';
    final hasAddressStrings = combined.trim().isNotEmpty;

    final expectedSgg = (fullAddrAPIData['sggNm']?.toString() ?? '').trim().isNotEmpty
        ? fullAddrAPIData['sggNm']!.trim()
        : (_extractSggFromAddress(address) ?? '');
    final expectedEmd = (fullAddrAPIData['emdNm']?.toString() ?? '').trim().isNotEmpty
        ? fullAddrAPIData['emdNm']!.trim()
        : (_extractEmdFromAddress(address) ?? '');

    final targetBjd = (fullAddrAPIData['admCd'] ?? '').trim();
    final normalizedTargetBjd = targetBjd.length >= 10 ? targetBjd.substring(0, 10) : targetBjd;
    if (normalizedTargetBjd.isNotEmpty) {
      final itemBjd = item['bjdCode']?.toString() ??
          item['bjdcode']?.toString() ??
          item['bjdCd']?.toString() ??
          item['bjdcd']?.toString() ??
          '';
      if (itemBjd.isNotEmpty) {
        if (itemBjd.startsWith(normalizedTargetBjd)) {
          return true;
        }
        return false;
      }
    }

    if (hasAddressStrings) {
    // 시군구/동 문자열 비교는 참고용으로만 사용 (불일치해도 바로 실패하지 않음)
    if (expectedSgg.isNotEmpty && !_containsNormalized(combined, expectedSgg)) {
    }
    if (expectedEmd.isNotEmpty && !_containsNormalized(combined, expectedEmd)) {
    }
    } else {
    }

    final targetRoadCode = (fullAddrAPIData['rnMgtSn'] ?? '').trim();
    final normalizedTargetRoad = targetRoadCode.length >= 12 ? targetRoadCode.substring(0, 12) : targetRoadCode;
    if (normalizedTargetRoad.isNotEmpty) {
      final itemRoadCode = item['roadCode']?.toString() ??
          item['roadCd']?.toString() ??
          item['road_cd']?.toString() ??
          item['doroCode']?.toString() ??
          '';
      if (itemRoadCode.isNotEmpty && !itemRoadCode.startsWith(normalizedTargetRoad)) {
        return false;
      }
    }

    return true;
  }

  static String _normalizeName(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  static bool _containsNormalized(String source, String token) {
    if (source.isEmpty || token.isEmpty) return false;
    final normalizedSource = source.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final normalizedToken = token.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return normalizedSource.contains(normalizedToken);
  }

  static String _buildCacheKey(
    String address,
    String complexName,
    String? roadCode,
    String? bjdCode,
  ) {
    final normalizedAddress = _normalizeCacheKey(address);
    final normalizedComplex = _normalizeName(complexName);
    final normalizedRoad = roadCode?.trim() ?? '';
    final normalizedBjd = bjdCode?.trim() ?? '';
    return '$normalizedAddress|$normalizedComplex|$normalizedRoad|$normalizedBjd';
  }

  static String _normalizeCacheKey(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  static void _pruneExpiredCache() {
    final keysToRemove = <String>[];
    _kaptCodeCache.forEach((key, entry) {
      if (entry.isExpired(_cacheTTL)) {
        keysToRemove.add(key);
      }
    });
    for (final key in keysToRemove) {
      _kaptCodeCache.remove(key);
    }
  }

  static void _enforceCacheLimit() {
    if (_kaptCodeCache.length <= _cacheLimit) {
      return;
    }
    final sortedEntries = _kaptCodeCache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
    final removeCount = _kaptCodeCache.length - _cacheLimit;
    for (var i = 0; i < removeCount; i++) {
      _kaptCodeCache.remove(sortedEntries[i].key);
    }
  }

  static String? _extractSggFromAddress(String address) {
    final sanitized = _stripParentheses(address);
    final match = RegExp(r'\s([가-힣]+(시|군|구))\s').firstMatch(' $sanitized ');
    return match != null ? match.group(1) : null;
  }

  static String? _extractEmdFromAddress(String address) {
    final sanitized = _stripParentheses(address);
    final match = RegExp(r'\s([가-힣0-9]+동)\s').firstMatch(' $sanitized ');
    return match != null ? match.group(1) : null;
  }

  static String _stripParentheses(String value) {
    return value.replaceAll(RegExp(r'\([^)]*\)'), '');
  }
}
