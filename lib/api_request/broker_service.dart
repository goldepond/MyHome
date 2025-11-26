import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

class BrokerSearchResult {
  final List<Broker> brokers;
  final int radiusMetersUsed;
  final bool wasExpanded;

  const BrokerSearchResult({
    required this.brokers,
    required this.radiusMetersUsed,
    required this.wasExpanded,
  });
}

/// VWorld 부동산중개업WFS조회 API 서비스
class BrokerService {
  /// 주변 공인중개사 검색
  /// 
  /// [latitude] 위도
  /// [longitude] 경도
  /// [radiusMeters] 검색 반경 (미터), 기본값 1000m (1km)
  static Future<BrokerSearchResult> searchNearbyBrokers({
    required double latitude,
    required double longitude,
    int radiusMeters = 1000,
    bool shouldAutoRetry = true,
  }) async {
    debugPrint('=== 공인중개사 검색 API 호출 ===');
    debugPrint('위도: $latitude, 경도: $longitude, 반경: ${radiusMeters}m, 자동 재시도: $shouldAutoRetry');
    
    try {
      int radiusUsed = radiusMeters;
      bool wasExpanded = false;

      // 1단계: VWorld API에서 기본 중개사 정보 조회
      debugPrint('1단계: VWorld API에서 기본 중개사 정보 조회 시작');
      List<Broker> brokers = await _searchFromVWorld(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      debugPrint('1단계 결과: ${brokers.length}개 공인중개사 발견');

      // 2단계: 결과가 없으면 반경을 넓혀가며 재시도
      if (shouldAutoRetry && brokers.isEmpty && radiusMeters < 10000) {
        debugPrint('2단계: 결과가 없어 반경을 넓혀가며 재시도 시작');
        final retryResult = await _retryWithExpandedRadius(
          latitude: latitude,
          longitude: longitude,
          initialRadius: radiusMeters,
        );
        brokers = retryResult.brokers;
        radiusUsed = retryResult.radiusMetersUsed;
        wasExpanded = retryResult.wasExpanded;
        debugPrint('2단계 결과: ${brokers.length}개 공인중개사 발견 (반경 확장: ${wasExpanded ? "예" : "아니오"})');
      }

      // 3단계: 서울 지역인 경우 서울시 API 데이터로 보강
      if (brokers.isNotEmpty) {
        // 3-1. 먼저 글로벌공인중개사무소 정보로 보강
        brokers = await _enhanceWithSeoulGlobalBrokerData(brokers);
        
        // 3-2. 매칭 실패한 것들은 부동산 중개업소 정보로 보강
        brokers = await _enhanceWithSeoulBrokerData(brokers);
      }

      debugPrint('=== 공인중개사 검색 완료 ===');
      debugPrint('최종 결과: ${brokers.length}개, 사용된 반경: ${radiusUsed}m');
      
      return BrokerSearchResult(
        brokers: brokers,
        radiusMetersUsed: radiusUsed,
        wasExpanded: wasExpanded || radiusUsed != radiusMeters,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ 공인중개사 검색 중 예외 발생');
      debugPrint('오류 타입: ${e.runtimeType}');
      debugPrint('오류 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');
      
      return BrokerSearchResult(
        brokers: const [],
        radiusMetersUsed: radiusMeters,
        wasExpanded: false,
      );
    }
  }

  /// VWorld API에서 중개사 정보 조회
  static Future<List<Broker>> _searchFromVWorld({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    debugPrint('=== 공인중개사 검색 시작 ===');
    debugPrint('위도: $latitude, 경도: $longitude, 반경: ${radiusMeters}m');
    
    // BBOX 생성 (EPSG:4326 기준)
    final bbox = _generateEpsg4326Bbox(latitude, longitude, radiusMeters);
    debugPrint('생성된 BBOX: $bbox');
    
    final uri = Uri.parse(VWorldApiConstants.brokerQueryBaseUrl).replace(queryParameters: {
      'key': VWorldApiConstants.apiKey,
      'typename': VWorldApiConstants.brokerQueryTypeName,
      'bbox': bbox,
      'resultType': 'results',
      'srsName': VWorldApiConstants.srsName,
      'output': 'application/json',
      'maxFeatures': VWorldApiConstants.brokerMaxFeatures.toString(),
      //'domain' : VWorldApiConstants.domainCORSParam,
    });

    debugPrint('=== 요청 URL 생성 ===');
    debugPrint('기본 URL: ${VWorldApiConstants.brokerQueryBaseUrl}');
    debugPrint('요청 파라미터:');
    debugPrint('  - key: ${VWorldApiConstants.apiKey.isNotEmpty ? "${VWorldApiConstants.apiKey.substring(0, VWorldApiConstants.apiKey.length > 10 ? 10 : VWorldApiConstants.apiKey.length)}..." : "(비어있음)"}');
    debugPrint('  - typename: ${VWorldApiConstants.brokerQueryTypeName}');
    debugPrint('  - bbox: $bbox');
    debugPrint('  - resultType: results');
    debugPrint('  - srsName: ${VWorldApiConstants.srsName}');
    debugPrint('  - output: application/json');
    debugPrint('  - maxFeatures: ${VWorldApiConstants.brokerMaxFeatures}');
    debugPrint('최종 URI: ${uri.toString().replaceAll(VWorldApiConstants.apiKey, '***API_KEY***')}');

    final proxyUri = Uri.parse(
      '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
    );
    
    debugPrint('프록시 URI: ${proxyUri.toString().replaceAll(VWorldApiConstants.apiKey, '***API_KEY***')}');
    debugPrint('=== HTTP 요청 시작 ===');
    
    http.Response response;
    try {
      debugPrint('프록시 서버로 요청 전송 중...');
      response = await http.get(proxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          debugPrint('⏱️ 요청 타임아웃 발생');
          throw Exception('API 타임아웃');
        },
      );
      
      debugPrint('=== HTTP 응답 수신 ===');
      debugPrint('상태 코드: ${response.statusCode}');
      debugPrint('응답 헤더: ${response.headers}');
      debugPrint('응답 본문 길이: ${response.body.length} bytes');
    } catch (e) {
      debugPrint('❌ HTTP 요청 오류 발생');
      debugPrint('오류 타입: ${e.runtimeType}');
      debugPrint('오류 메시지: $e');
      return [];
    }
    
    if (response.statusCode == 200) {
      debugPrint('✅ HTTP 200 응답 수신');
      try {
        final jsonText = utf8.decode(response.bodyBytes);
        debugPrint('응답 본문 (처음 500자): ${jsonText.length > 500 ? jsonText.substring(0, 500) : jsonText}');
        
        final brokers = _parseJSON(jsonText, latitude, longitude);
        debugPrint('=== 공인중개사 검색 결과 ===');
        debugPrint('파싱된 공인중개사 수: ${brokers.length}');
        
        return brokers;
      } catch (e, stackTrace) {
        debugPrint('❌ JSON 파싱 오류 발생');
        debugPrint('오류 타입: ${e.runtimeType}');
        debugPrint('오류 메시지: $e');
        debugPrint('스택 트레이스: $stackTrace');
        return [];
      }
    } else {
      debugPrint('❌ HTTP 상태 코드 오류: ${response.statusCode}');
      debugPrint('응답 본문: ${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');
      return [];
    }
  }

  /// 반경을 넓혀가며 재시도 (최대 10km까지)
  static Future<BrokerSearchResult> _retryWithExpandedRadius({
    required double latitude,
    required double longitude,
    required int initialRadius,
  }) async {
    const int maxRadius = 10000;
    const int retrySteps = 3;
    final int increment = (maxRadius - initialRadius) ~/ retrySteps;

    for (int attempt = 0; attempt < retrySteps; attempt++) {
      final int searchRadius = attempt < retrySteps - 1
          ? initialRadius + (attempt + 1) * increment
          : maxRadius;
      
      final brokers = await _searchFromVWorld(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: searchRadius,
      );
      
      if (brokers.isNotEmpty) {
        return BrokerSearchResult(
          brokers: brokers,
          radiusMetersUsed: searchRadius,
          wasExpanded: true,
        );
      }
    }
    
    return BrokerSearchResult(
      brokers: const [],
      radiusMetersUsed: maxRadius,
      wasExpanded: true,
    );
  }

  /// 서울시 글로벌공인중개사무소 정보 조회 및 기존 Broker 목록과 매칭하여 보강
  static Future<List<Broker>> _enhanceWithSeoulGlobalBrokerData(List<Broker> brokers) async {
    if (brokers.isEmpty) return brokers;
    
    try {
      debugPrint('=== 서울시 글로벌공인중개사무소 정보 보강 시작 ===');
      debugPrint('검증 대상 Broker 수: ${brokers.length}개');
      
      // 서울 지역인지 확인 (sggCode로 판단하거나, 주소에 "서울" 포함 여부로 판단)
      final seoulBrokers = brokers.where((b) {
        final address = b.roadAddress.isNotEmpty ? b.roadAddress : b.jibunAddress;
        return address.contains('서울') || b.sggCode?.startsWith('11') == true;
      }).toList();
      
      debugPrint('서울 지역 Broker 수: ${seoulBrokers.length}개');
      
      if (seoulBrokers.isEmpty) {
        debugPrint('서울 지역 Broker가 없어 서울시 글로벌공인중개사무소 조회를 건너뜁니다.');
        return brokers;
      }
      
      // 서울시 글로벌공인중개사무소 데이터 조회
      final globalBrokerData = await _fetchSeoulGlobalBrokerData();
      
      if (globalBrokerData.isEmpty) {
        debugPrint('⚠️ 서울시 글로벌공인중개사무소 데이터가 없습니다.');
        return brokers;
      }
      
      int matchedCount = 0;
      final enhancedBrokers = brokers.map((broker) {
        final matchedGlobalBroker = _findMatchingGlobalBroker(broker, globalBrokerData);
        
        if (matchedGlobalBroker == null) {
          return broker; // 매칭되지 않으면 그대로 반환
        }
        
        matchedCount++;
        
        // 정보 보강 (기존 값이 없을 때만 채워넣기)
        return Broker(
          name: broker.name,
          roadAddress: broker.roadAddress,
          jibunAddress: broker.jibunAddress,
          registrationNumber: broker.registrationNumber,
          etcAddress: broker.etcAddress,
          employeeCount: broker.employeeCount,
          registrationDate: broker.registrationDate,
          latitude: broker.latitude,
          longitude: broker.longitude,
          distance: broker.distance,
          systemRegNo: broker.systemRegNo,
          ownerName: broker.ownerName ?? matchedGlobalBroker['RDEALER_NM']?.toString(),
          businessName: broker.businessName ?? matchedGlobalBroker['CMP_NM']?.toString(),
          phoneNumber: broker.phoneNumber ?? matchedGlobalBroker['TELNO']?.toString(),
          businessStatus: broker.businessStatus,
          seoulAddress: broker.seoulAddress,
          district: broker.district,
          legalDong: broker.legalDong,
          sggCode: broker.sggCode,
          stdgCode: broker.stdgCode,
          lotnoSe: broker.lotnoSe,
          mno: broker.mno,
          sno: broker.sno,
          roadCode: broker.roadCode,
          bldg: broker.bldg,
          bmno: broker.bmno,
          bsno: broker.bsno,
          penaltyStartDate: broker.penaltyStartDate,
          penaltyEndDate: broker.penaltyEndDate,
          inqCount: broker.inqCount,
          introduction: broker.introduction,
          // 글로벌공인중개사무소 정보 추가
          globalBrokerLanguage: matchedGlobalBroker['USE_LANG']?.toString(),
          globalBrokerAppnYear: matchedGlobalBroker['APPN_YEAR']?.toString(),
          globalBrokerAppnNo: matchedGlobalBroker['APPN_NO']?.toString(),
          globalBrokerAppnDe: matchedGlobalBroker['APPN_DE']?.toString(),
        );
      }).toList();
      
      if (matchedCount > 0) {
        debugPrint('✅ 서울시 글로벌공인중개사무소 매칭: $matchedCount건');
      } else {
        debugPrint('서울시 글로벌공인중개사무소 매칭된 항목 없음');
      }
      return enhancedBrokers;
      
    } catch (e, stackTrace) {
      debugPrint('❌ 서울시 글로벌공인중개사무소 API 오류: $e');
      return brokers; // 오류 발생 시 원본 반환
    }
  }
  
  /// 서울시 글로벌공인중개사무소 API에서 데이터 조회
  static Future<List<Map<String, dynamic>>> _fetchSeoulGlobalBrokerData() async {
    try {
      final apiKey = ApiConstants.seoulOpenApiKey;
      if (apiKey.isEmpty) {
        debugPrint('서울시 Open API 키가 설정되지 않았습니다.');
        return [];
      }
      
      debugPrint('=== 서울시 글로벌공인중개사무소 API 조회 시작 ===');
      
      // 먼저 전체 데이터 개수 조회
      final countUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/brkPgGlobal/1/1/';
      
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(countUrl)}',
      );
      
      final countResponse = await http.get(proxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      
      if (countResponse.statusCode != 200) {
        debugPrint('❌ 서울시 글로벌공인중개사무소 API 개수 조회 실패: ${countResponse.statusCode}');
        return [];
      }
      
      final countJson = json.decode(utf8.decode(countResponse.bodyBytes));
      final totalCount = int.tryParse(countJson['brkPgGlobal']?['list_total_count']?.toString() ?? '0') ?? 0;
      
      debugPrint('✅ 서울시 글로벌공인중개사무소 전체 개수: $totalCount건');
      
      if (totalCount == 0) {
        debugPrint('⚠️ 서울시 글로벌공인중개사무소 데이터가 0건입니다.');
        return [];
      }
      
      // 한 번에 최대 1000건까지만 조회 가능
      final maxIndex = totalCount > 1000 ? 1000 : totalCount;
      final dataUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/brkPgGlobal/1/$maxIndex/';
      
      final dataProxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(dataUrl)}',
      );
      
      debugPrint('서울시 글로벌공인중개사무소 데이터 조회 중... (1~$maxIndex)');
      
      final dataResponse = await http.get(dataProxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      
      if (dataResponse.statusCode != 200) {
        debugPrint('❌ 서울시 글로벌공인중개사무소 API 데이터 조회 실패: ${dataResponse.statusCode}');
        return [];
      }
      
      final dataJson = json.decode(utf8.decode(dataResponse.bodyBytes));
      final result = dataJson['brkPgGlobal'];
      
      if (result == null) {
        debugPrint('⚠️ 서울시 글로벌공인중개사무소 API 응답 형식 오류: brkPgGlobal 키 없음');
        return [];
      }
      
      // RESULT 확인
      final resultCode = result['RESULT']?['CODE']?.toString() ?? '';
      if (resultCode != 'INFO-000') {
        debugPrint('⚠️ 서울시 글로벌공인중개사무소 API 오류 코드: $resultCode');
        return [];
      }
      
      // row 데이터 추출
      final rows = result['row'];
      if (rows == null) {
        debugPrint('⚠️ 서울시 글로벌공인중개사무소 API 응답에 row 데이터가 없습니다.');
        return [];
      }
      
      List<Map<String, dynamic>> brokerList = [];
      if (rows is List) {
        brokerList = rows.cast<Map<String, dynamic>>().toList();
      } else if (rows is Map) {
        brokerList = [Map<String, dynamic>.from(rows)];
      }
      
      debugPrint('✅ 서울시 글로벌공인중개사무소 ${brokerList.length}건 조회 완료');
      
      return brokerList;
      
    } catch (e, stackTrace) {
      debugPrint('❌ 서울시 글로벌공인중개사무소 API 호출 오류');
      debugPrint('오류 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return [];
    }
  }
  
  /// 서울시 부동산 중개업소 정보 API에서 데이터 조회 (병렬 처리 + 조기 종료)
  static Future<List<Map<String, dynamic>>> _fetchSeoulBrokerData({
    Set<String>? requiredRegistrationNumbers, // 필요한 등록번호 목록 (조기 종료용)
  }) async {
    try {
      final apiKey = ApiConstants.seoulOpenApiKey;
      if (apiKey.isEmpty) {
        debugPrint('서울시 Open API 키가 설정되지 않았습니다.');
        return [];
      }
      
      // 먼저 전체 데이터 개수 조회
      final countUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/landBizInfo/1/1/';
      
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(countUrl)}',
      );
      
      debugPrint('=== 서울시 부동산 중개업소 정보 API 개수 조회 시작 ===');
      debugPrint('직접 API URL: $countUrl');
      debugPrint('프록시 URL: $proxyUri');
      debugPrint('인증키: $apiKey');
      debugPrint('베이스 URL: ${ApiConstants.seoulGlobalBrokerBaseUrl}');
      
      final countResponse = await http.get(proxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      
      debugPrint('--- 개수 조회 응답 정보 ---');
      debugPrint('상태 코드: ${countResponse.statusCode}');
      debugPrint('응답 헤더: ${countResponse.headers}');
      debugPrint('응답 본문 길이: ${countResponse.body.length} bytes');
      debugPrint('응답 본문 타입: ${countResponse.headers['content-type']}');
      
      if (countResponse.statusCode != 200) {
        debugPrint('=== 개수 조회 실패 상세 정보 ===');
        debugPrint('상태 코드: ${countResponse.statusCode}');
        debugPrint('응답 본문 길이: ${countResponse.body.length} bytes');
        
        if (countResponse.statusCode == 500) {
          debugPrint('⚠️ 서울시 부동산 중개업소 정보 API (개수 조회) 500 에러');
          debugPrint('응답 본문 전체:');
          if (countResponse.body.isNotEmpty) {
            final bodyPreview = countResponse.body.length > 1000 
                ? '${countResponse.body.substring(0, 1000)}... (전체 ${countResponse.body.length}자)' 
                : countResponse.body;
            debugPrint(bodyPreview);
            
            // JSON 파싱 시도
            try {
              final errorJson = json.decode(utf8.decode(countResponse.bodyBytes));
              debugPrint('응답 JSON 파싱 성공:');
              debugPrint(errorJson.toString());
            } catch (e) {
              debugPrint('응답 JSON 파싱 실패: $e');
            }
          } else {
            debugPrint('응답 본문이 비어있습니다.');
          }
          debugPrint('응답 헤더 전체:');
          countResponse.headers.forEach((key, value) {
            debugPrint('  $key: $value');
          });
        } else {
          debugPrint('❌ 서울시 부동산 중개업소 정보 API (개수 조회) 실패: ${countResponse.statusCode}');
          debugPrint('응답 본문: ${countResponse.body.length > 500 ? countResponse.body.substring(0, 500) : countResponse.body}');
        }
        return [];
      }
      
      debugPrint('응답 본문 미리보기 (처음 500자):');
      if (countResponse.body.isNotEmpty) {
        debugPrint(countResponse.body.length > 500 
            ? countResponse.body.substring(0, 500) 
            : countResponse.body);
      }
      
      final countJson = json.decode(utf8.decode(countResponse.bodyBytes));
      debugPrint('파싱된 JSON 키: ${countJson.keys.toList()}');
      
      final totalCount = int.tryParse(countJson['landBizInfo']?['list_total_count']?.toString() ?? '0') ?? 0;
      
      debugPrint('✅ 서울시 부동산 중개업소 정보 전체 개수: $totalCount건');
      
      if (totalCount == 0) {
        debugPrint('⚠️ 데이터가 0건입니다.');
        return [];
      }
      
      // 한 번에 최대 1000건까지만 조회 가능
      // 병렬 처리로 성능 향상 (200건씩, 동시 10개 요청)
      List<Map<String, dynamic>> allBrokerList = [];
      const int pageSize = 200; // 200건씩 조회
      const int concurrentRequests = 10; // 동시에 10개 요청 (병렬 처리)
      final maxRequests = (totalCount / pageSize).ceil();
      
      // 필요한 등록번호가 있으면 조기 종료를 위한 Set 생성
      final requiredRegNos = requiredRegistrationNumbers?.toSet();
      final matchedRegNos = <String>{};
      
      debugPrint('=== 서울시 부동산 중개업소 정보 데이터 조회 시작 ===');
      if (requiredRegNos != null) {
        debugPrint('필요한 등록번호: ${requiredRegNos.length}개 (조기 종료 활성화)');
      }
      debugPrint('총 페이징: $maxRequests회 ($pageSize건씩, 동시 $concurrentRequests개 병렬 처리)');
      
      // 병렬 처리로 여러 페이지 동시 요청
      for (int startPage = 0; startPage < maxRequests; startPage += concurrentRequests) {
        final endPage = (startPage + concurrentRequests) < maxRequests 
            ? startPage + concurrentRequests 
            : maxRequests;
        
        // 현재 배치의 병렬 요청 생성
        final futures = <Future<List<Map<String, dynamic>>>>[];
        
        for (int page = startPage; page < endPage; page++) {
          final startIndex = page * pageSize + 1;
          final endIndex = (startIndex + pageSize - 1) > totalCount 
              ? totalCount 
              : (startIndex + pageSize - 1);
          
          futures.add(_fetchSeoulBrokerPage(apiKey, startIndex, endIndex));
        }
        
        // 병렬 요청 실행
        final results = await Future.wait(futures);
        
        // 결과 병합 및 조기 종료 체크
        bool shouldEarlyExit = false;
        
        for (final pageBrokerList in results) {
          allBrokerList.addAll(pageBrokerList);
          
          // 필요한 등록번호가 있고, 아직 찾지 못한 것이 있으면 체크
          if (requiredRegNos != null && matchedRegNos.length < requiredRegNos.length) {
            for (final broker in pageBrokerList) {
              final regNo = broker['REST_BRKR_INFO']?.toString().trim();
              if (regNo != null && regNo.isNotEmpty && requiredRegNos.contains(regNo)) {
                matchedRegNos.add(regNo);
              }
            }
            
            // 모든 필요한 등록번호를 찾았으면 조기 종료
            if (matchedRegNos.length == requiredRegNos.length) {
              debugPrint('✅ 필요한 등록번호 모두 매칭 완료 (${matchedRegNos.length}개), 조기 종료');
              shouldEarlyExit = true;
              break;
            }
          }
        }
        
        // 조기 종료
        if (shouldEarlyExit) {
          break;
        }
        
        // 진행 상황 로그
        if ((startPage + concurrentRequests) % 50 == 0 || endPage >= maxRequests) {
          debugPrint('✅ ${endPage}/$maxRequests 완료 (누적: ${allBrokerList.length}/${totalCount}건)');
          if (requiredRegNos != null) {
            debugPrint('   매칭 완료: ${matchedRegNos.length}/${requiredRegNos.length}개');
          }
        }
      }
      
      debugPrint('=== 서울시 부동산 중개업소 정보 조회 완료 ===');
      debugPrint('✅ 총 ${allBrokerList.length}건 파싱 완료');
      if (requiredRegNos != null) {
        debugPrint('✅ 매칭된 등록번호: ${matchedRegNos.length}/${requiredRegNos.length}개');
      }
      
      return allBrokerList;
      
    } catch (e, stackTrace) {
      debugPrint('❌ 서울시 부동산 중개업소 정보 API 호출 오류');
      debugPrint('오류 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');
      return [];
    }
  }
  
  /// 단일 페이지 조회 (병렬 처리용)
  static Future<List<Map<String, dynamic>>> _fetchSeoulBrokerPage(
    String apiKey,
    int startIndex,
    int endIndex,
  ) async {
    try {
      final dataUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/landBizInfo/$startIndex/$endIndex/';
      final dataProxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(dataUrl)}',
      );
      
      final dataResponse = await http.get(dataProxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      
      if (dataResponse.statusCode != 200) {
        return []; // 개별 페이지 실패는 무시
      }
      
      final dataJson = json.decode(utf8.decode(dataResponse.bodyBytes));
      final result = dataJson['landBizInfo'];
      
      if (result == null) {
        return [];
      }
      
      final resultCode = result['RESULT']?['CODE']?.toString() ?? '';
      if (resultCode != 'INFO-000') {
        return [];
      }
      
      final rows = result['row'];
      if (rows == null) {
        return [];
      }
      
      if (rows is List) {
        return rows.cast<Map<String, dynamic>>().toList();
      } else if (rows is Map) {
        return [Map<String, dynamic>.from(rows)];
      }
      
      return [];
    } catch (e) {
      // 개별 페이지 실패는 무시하고 빈 리스트 반환
      return [];
    }
  }
  
  /// 서울시 부동산 중개업소 정보로 기존 Broker 목록 보강
  static Future<List<Broker>> _enhanceWithSeoulBrokerData(List<Broker> brokers) async {
    if (brokers.isEmpty) return brokers;
    
    try {
      // 이미 글로벌공인중개사무소 정보가 있는 것은 제외 (중복 방지)
      final brokersToEnhance = brokers.where((b) {
        return b.globalBrokerLanguage == null && b.phoneNumber == null;
      }).toList();
      
      if (brokersToEnhance.isEmpty) {
        return brokers;
      }
      
      // 서울 지역인지 확인
      final seoulBrokers = brokersToEnhance.where((b) {
        final address = b.roadAddress.isNotEmpty ? b.roadAddress : b.jibunAddress;
        return address.contains('서울') || b.sggCode?.startsWith('11') == true;
      }).toList();
      
      if (seoulBrokers.isEmpty) {
        return brokers;
      }
      
      // 필요한 등록번호만 추출 (조기 종료를 위해)
      final requiredRegNos = seoulBrokers
          .map((b) => b.registrationNumber.trim())
          .where((regNo) => regNo.isNotEmpty)
          .toSet();
      
      debugPrint('서울시 부동산 중개업소 정보 조회 (필요한 등록번호: ${requiredRegNos.length}개)');
      
      // 필요한 등록번호만 찾으면 조기 종료되도록 최적화
      final brokerData = await _fetchSeoulBrokerData(
        requiredRegistrationNumbers: requiredRegNos,
      );
      
      if (brokerData.isEmpty) {
        return brokers;
      }
      
      int matchedCount = 0;
      final enhancedBrokers = brokers.map((broker) {
        // 이미 글로벌공인중개사무소 정보가 있으면 그대로 반환
        if (broker.globalBrokerLanguage != null) {
          return broker;
        }
        
        final matchedBroker = _findMatchingBroker(broker, brokerData);
        
        if (matchedBroker == null) {
          return broker; // 매칭되지 않으면 그대로 반환
        }
        
        matchedCount++;
        
        // 정보 보강 (기존 값이 없을 때만 채워넣기)
        return Broker(
          name: broker.name,
          roadAddress: broker.roadAddress,
          jibunAddress: broker.jibunAddress,
          registrationNumber: broker.registrationNumber,
          etcAddress: broker.etcAddress,
          employeeCount: broker.employeeCount,
          registrationDate: broker.registrationDate,
          latitude: broker.latitude,
          longitude: broker.longitude,
          distance: broker.distance,
          systemRegNo: broker.systemRegNo ?? matchedBroker['SYS_REG_NO']?.toString(),
          ownerName: broker.ownerName ?? matchedBroker['MDT_BSNS_NM']?.toString(),
          businessName: broker.businessName ?? matchedBroker['BZMN_CONM']?.toString(),
          phoneNumber: broker.phoneNumber ?? matchedBroker['TELNO']?.toString(),
          businessStatus: broker.businessStatus ?? matchedBroker['STTS_SE']?.toString(),
          seoulAddress: broker.seoulAddress ?? matchedBroker['ADDR']?.toString(),
          district: broker.district ?? matchedBroker['CGG_CD']?.toString(),
          legalDong: broker.legalDong ?? matchedBroker['LGL_DONG_NM']?.toString(),
          sggCode: broker.sggCode ?? matchedBroker['SGG_CD']?.toString(),
          stdgCode: broker.stdgCode ?? matchedBroker['STDG_CD']?.toString(),
          lotnoSe: broker.lotnoSe ?? matchedBroker['LOTNO_SE']?.toString(),
          mno: broker.mno ?? matchedBroker['MNO']?.toString(),
          sno: broker.sno ?? matchedBroker['SNO']?.toString(),
          roadCode: broker.roadCode ?? matchedBroker['ROAD_CD']?.toString(),
          bldg: broker.bldg ?? matchedBroker['BLDG']?.toString(),
          bmno: broker.bmno ?? matchedBroker['BMNO']?.toString(),
          bsno: broker.bsno ?? matchedBroker['BSNO']?.toString(),
          penaltyStartDate: broker.penaltyStartDate ?? matchedBroker['PBADMS_DSPS_STRT_DD']?.toString(),
          penaltyEndDate: broker.penaltyEndDate ?? matchedBroker['PBADMS_DSPS_END_DD']?.toString(),
          inqCount: broker.inqCount ?? matchedBroker['INQ_CNT']?.toString(),
          introduction: broker.introduction,
          // 글로벌공인중개사무소 정보는 유지
          globalBrokerLanguage: broker.globalBrokerLanguage,
          globalBrokerAppnYear: broker.globalBrokerAppnYear,
          globalBrokerAppnNo: broker.globalBrokerAppnNo,
          globalBrokerAppnDe: broker.globalBrokerAppnDe,
        );
      }).toList();
      
      if (matchedCount > 0) {
        debugPrint('서울시 부동산 중개업소 정보 매칭: $matchedCount건');
      }
      return enhancedBrokers;
      
    } catch (e, stackTrace) {
      debugPrint('❌ 서울시 부동산 중개업소 정보 API 오류: $e');
      return brokers; // 오류 발생 시 원본 반환
    }
  }
  
  /// 기존 Broker와 서울시 부동산 중개업소 정보 데이터 매칭
  /// 매칭 기준: 등록번호만 (등록번호는 절대적이고 중복이 없음)
  static Map<String, dynamic>? _findMatchingBroker(
    Broker broker,
    List<Map<String, dynamic>> brokerData,
  ) {
    if (broker.registrationNumber.isEmpty) {
      return null;
    }
    
    final brokerRegNo = broker.registrationNumber.trim();
    
    // 등록번호로만 매칭 (등록번호는 절대적이고 중복이 없음, 원본 그대로 비교)
    for (final seoulBroker in brokerData) {
      final restBrkrInfo = seoulBroker['REST_BRKR_INFO']?.toString().trim() ?? '';
      if (restBrkrInfo.isNotEmpty && restBrkrInfo == brokerRegNo) {
        return seoulBroker;
      }
    }
    
    return null;
  }
  
  /// 기존 Broker와 서울시 글로벌공인중개사무소 데이터 매칭
  /// 매칭 기준: 등록번호만 (등록번호는 절대적이고 중복이 없음)
  static Map<String, dynamic>? _findMatchingGlobalBroker(
    Broker broker,
    List<Map<String, dynamic>> globalBrokerData,
  ) {
    if (broker.registrationNumber.isEmpty) {
      return null;
    }
    
    final brokerRegNo = broker.registrationNumber.trim();
    
    // 등록번호로만 매칭 (등록번호는 절대적이고 중복이 없음, 원본 그대로 비교)
    for (final globalBroker in globalBrokerData) {
      final raRegNo = globalBroker['RA_REGNO']?.toString().trim() ?? '';
      if (raRegNo.isNotEmpty && raRegNo == brokerRegNo) {
        return globalBroker;
      }
    }
    
    return null;
  }
  
  
  /// 이름 정규화 (공백 제거, 소문자 변환)
  static String _normalizeName(String name) {
    return name.replaceAll(' ', '').replaceAll('(', '').replaceAll(')', '').trim();
  }
  
  /// 주소 정규화 (공백 제거)
  static String _normalizeAddress(String address) {
    return address.replaceAll(' ', '').trim();
  }
  
  /// 글로벌 중개사와 기존 Broker 매칭 검증
  static bool _validateGlobalBrokerMatch(Broker broker, Map<String, dynamic> globalBroker) {
    debugPrint('    [검증] 업소명 확인 중...');
    // 업소명 확인
    final cmpNm = globalBroker['CMP_NM']?.toString() ?? '';
    if (cmpNm.isNotEmpty) {
      final brokerName = _normalizeName(broker.name.isNotEmpty ? broker.name : (broker.businessName ?? ''));
      final globalName = _normalizeName(cmpNm);
      debugPrint('    [검증] Broker 업소명 (정규화): "$brokerName"');
      debugPrint('    [검증] Global 업소명 (정규화): "$globalName"');
      if (brokerName.isNotEmpty && globalName.isNotEmpty &&
          !brokerName.contains(globalName) && !globalName.contains(brokerName)) {
        debugPrint('    [검증] ✗ 업소명이 유사하지 않음');
        return false; // 업소명이 유사하지 않음
      }
      debugPrint('    [검증] ✓ 업소명 일치 또는 유사');
    }
    
    debugPrint('    [검증] 소재지 확인 중...');
    // 소재지 확인
    final address = globalBroker['ADDRESS']?.toString() ?? '';
    if (address.isNotEmpty) {
      final brokerAddress = _normalizeAddress(
        broker.roadAddress.isNotEmpty ? broker.roadAddress : broker.jibunAddress
      );
      final globalAddress = _normalizeAddress(address);
      debugPrint('    [검증] Broker 주소 (정규화): "$brokerAddress"');
      debugPrint('    [검증] Global 주소 (정규화): "$globalAddress"');
      if (brokerAddress.isNotEmpty && globalAddress.isNotEmpty &&
          !brokerAddress.contains(globalAddress) && !globalAddress.contains(brokerAddress)) {
        debugPrint('    [검증] ✗ 소재지가 유사하지 않음');
        return false; // 소재지가 유사하지 않음
      }
      debugPrint('    [검증] ✓ 소재지 일치 또는 유사');
    }
    
    debugPrint('    [검증] 대표자명 확인 중...');
    // 대표자명 확인
    final rdealerNm = globalBroker['RDEALER_NM']?.toString() ?? '';
    final ownerValidation = _validateOwnerName(broker.ownerName, rdealerNm);
    debugPrint('    [검증] Broker 대표자명: "${broker.ownerName}"');
    debugPrint('    [검증] Global 대표자명: "$rdealerNm"');
    debugPrint('    [검증] 대표자명 검증 결과: ${ownerValidation ? "✓ 통과" : "✗ 실패"}');
    if (!ownerValidation) {
      return false; // 대표자명이 일치하지 않음
    }
    
    debugPrint('    [검증] ✓ 모든 검증 통과!');
    return true;
  }
  
  /// 대표자명 검증 (대표자성명 = 중개업자명)
  static bool _validateOwnerName(String? brokerOwnerName, String? globalOwnerName) {
    if (brokerOwnerName == null || brokerOwnerName.isEmpty) {
      return true; // 기존에 대표자명이 없으면 검증 통과
    }
    
    if (globalOwnerName == null || globalOwnerName.isEmpty) {
      return true; // 글로벌 데이터에 대표자명이 없으면 검증 통과
    }
    
    // 정규화 후 비교
    final normalizedBroker = _normalizeName(brokerOwnerName);
    final normalizedGlobal = _normalizeName(globalOwnerName);
    
    return normalizedBroker == normalizedGlobal || 
           normalizedBroker.contains(normalizedGlobal) || 
           normalizedGlobal.contains(normalizedBroker);
  }
  
  /// BBOX 생성 (검색 범위)
  static String _generateEpsg4326Bbox(double lat, double lon, int radiusMeters) {
    final latDelta = radiusMeters / 111000.0;
    final lonDelta = radiusMeters / (111000.0 * cos(lat * pi / 180));
    
    final ymin = lat - latDelta;
    final xmin = lon - lonDelta;
    final ymax = lat + latDelta;
    final xmax = lon + lonDelta;
    
    return '$ymin,$xmin,$ymax,$xmax,EPSG:4326';
  }

  static List<Broker> _parseJSON(String jsonText, double baseLat, double baseLon) {
    final brokers = <Broker>[];

    debugPrint('=== JSON 파싱 시작 ===');
    try {
      final data = json.decode(jsonText);
      debugPrint('파싱된 데이터 타입: ${data.runtimeType}');
      debugPrint('데이터 키: ${data is Map ? data.keys.toList() : "N/A"}');
      
      final List<dynamic> features = data['features'] ?? [];
      debugPrint('features 개수: ${features.length}');

      for (final dynamic featureRaw in features) {
        final feature = featureRaw as Map<String, dynamic>;
        final properties = feature['properties'] as Map<String, dynamic>? ?? {};

        // 각 필드 추출
        final name = properties['bsnm_cmpnm']?.toString() ?? '';
        final roadAddr = properties['rdnmadr']?.toString() ?? '';
        final jibunAddr = properties['mnnmadr']?.toString() ?? '';
        final registNo = properties['brkpg_regist_no']?.toString() ?? '';
        final etcAddr = properties['etc_adres']?.toString() ?? '';
        final employeeCount = properties['emplym_co']?.toString() ?? '';
        final registDate = properties['frst_regist_dt']?.toString().replaceAll('Z', '') ?? '';

        // 좌표 추출 (geometry.coordinates에서 [lon, lat])
        double? brokerLat;
        double? brokerLon;
        double? distance;

        final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
        final coordinates = geometry['coordinates'] as List?;
        if (coordinates != null && coordinates.length >= 2) {
          try {
            brokerLon = double.parse(coordinates[0].toString());
            brokerLat = double.parse(coordinates[1].toString());
            distance = _calculateHaversineDistance(baseLat, baseLon, brokerLat, brokerLon);
          } catch (_) {
            // 좌표 파싱 실패 시 거리 계산 스킵
          }
        }

        brokers.add(Broker(
          name: name,
          roadAddress: roadAddr,
          jibunAddress: jibunAddr,
          registrationNumber: registNo,
          etcAddress: etcAddr,
          employeeCount: employeeCount,
          registrationDate: registDate,
          latitude: brokerLat,
          longitude: brokerLon,
          distance: distance,
        ));
      }

      // 거리순 정렬
      brokers.sort((a, b) {
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

      debugPrint('✅ JSON 파싱 성공: ${brokers.length}개 공인중개사 파싱 완료');

    } catch (e, stackTrace) {
      debugPrint('❌ JSON 파싱 오류 발생');
      debugPrint('오류 타입: ${e.runtimeType}');
      debugPrint('오류 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');
      // 파싱 실패 시 빈 리스트 반환
    }

    debugPrint('=== JSON 파싱 완료 ===');
    return brokers;
  }
  
  /// Haversine 공식으로 거리 계산 (미터)
  static double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    // EPSG:5186 (TM 좌표)인 경우 유클리드 거리
    if (lon1 > 1000 && lon2 > 1000) {
      final dx = lon2 - lon1;
      final dy = lat2 - lat1;
      return sqrt(dx * dx + dy * dy);
    }
    
    // WGS84 좌표인 경우 Haversine 공식
    const R = 6371000.0; // 지구 반지름 (미터)
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
              sin(dLon / 2) * sin(dLon / 2);
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}

/// 공인중개사 정보 모델
class Broker {
  final String name;                // 상호명
  final String roadAddress;         // 도로명주소
  final String jibunAddress;        // 지번주소
  final String registrationNumber;  // 등록번호
  final String etcAddress;          // 기타주소 (동/호수)
  final String employeeCount;       // 고용인원
  final String registrationDate;    // 등록일
  final double? latitude;           // 위도
  final double? longitude;          // 경도
  final double? distance;           // 거리 (미터)
  
  // 서울시 API 추가 정보 (전체 21개 필드)
  final String? systemRegNo;        // 시스템등록번호 (SYS_REG_NO)
  final String? ownerName;          // 중개업자명 (MDT_BSNS_NM)
  final String? businessName;       // 사업자상호 (BZMN_CONM)
  final String? phoneNumber;        // 전화번호 (TELNO)
  final String? businessStatus;     // 상태구분 (STTS_SE)
  final String? seoulAddress;       // 서울시 API 주소 (ADDR)
  final String? district;           // 자치구명 (CGG_CD)
  final String? legalDong;          // 법정동명 (LGL_DONG_NM)
  final String? sggCode;            // 시군구코드 (SGG_CD)
  final String? stdgCode;           // 법정동코드 (STDG_CD)
  final String? lotnoSe;            // 지번구분 (LOTNO_SE)
  final String? mno;                // 본번 (MNO)
  final String? sno;                // 부번 (SNO)
  final String? roadCode;           // 도로명코드 (ROAD_CD)
  final String? bldg;               // 건물 (BLDG)
  final String? bmno;               // 건물 본번 (BMNO)
  final String? bsno;               // 건물 부번 (BSNO)
  final String? penaltyStartDate;   // 행정처분 시작일 (PBADMS_DSPS_STRT_DD)
  final String? penaltyEndDate;     // 행정처분 종료일 (PBADMS_DSPS_END_DD)
  final String? inqCount;           // 조회 개수 (INQ_CNT)
  final String? introduction;        // 공인중개사 소개 (Firestore에서 가져옴)
  
  // 서울시 글로벌공인중개사무소 정보
  final String? globalBrokerLanguage;  // 사용언어 (USE_LANG)
  final String? globalBrokerAppnYear;  // 지정연도 (APPN_YEAR)
  final String? globalBrokerAppnNo;    // 지정번호 (APPN_NO)
  final String? globalBrokerAppnDe;    // 지정일 (APPN_DE)
  
  Broker({
    required this.name,
    required this.roadAddress,
    required this.jibunAddress,
    required this.registrationNumber,
    required this.etcAddress,
    required this.employeeCount,
    required this.registrationDate,
    this.latitude,
    this.longitude,
    this.distance,
    this.systemRegNo,
    this.ownerName,
    this.businessName,
    this.phoneNumber,
    this.businessStatus,
    this.seoulAddress,
    this.district,
    this.legalDong,
    this.sggCode,
    this.stdgCode,
    this.lotnoSe,
    this.mno,
    this.sno,
    this.roadCode,
    this.bldg,
    this.bmno,
    this.bsno,
    this.penaltyStartDate,
    this.penaltyEndDate,
    this.inqCount,
    this.introduction,
    this.globalBrokerLanguage,
    this.globalBrokerAppnYear,
    this.globalBrokerAppnNo,
    this.globalBrokerAppnDe,
  });
  
  /// 거리를 읽기 쉬운 형태로 변환
  String get distanceText {
    if (distance == null) return '-';
    if (distance! >= 1000) {
      return '${(distance! / 1000).toStringAsFixed(1)}km';
    }
    return '${distance!.toStringAsFixed(0)}m';
  }
  
  /// 전체 주소 (도로명 + 기타)
  String get fullAddress {
    if (etcAddress.isEmpty || etcAddress == '-') {
      return roadAddress;
    }
    return '$roadAddress $etcAddress';
  }
}

