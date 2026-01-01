import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';
import 'package:property/utils/logger.dart';

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
    
    try {
      int radiusUsed = radiusMeters;
      bool wasExpanded = false;

      // 1단계: VWorld API에서 기본 중개사 정보 조회
      List<Broker> brokers = await _searchFromVWorld(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );

      // 2단계: 결과가 없으면 반경을 넓혀가며 재시도
      if (shouldAutoRetry && brokers.isEmpty && radiusMeters < 10000) {
        final retryResult = await _retryWithExpandedRadius(
          latitude: latitude,
          longitude: longitude,
          initialRadius: radiusMeters,
        );
        brokers = retryResult.brokers;
        radiusUsed = retryResult.radiusMetersUsed;
        wasExpanded = retryResult.wasExpanded;
      }

      // 3단계: 서울 지역인 경우 서울시 API 데이터로 보강
      if (brokers.isNotEmpty) {
        // 3-1. 먼저 글로벌공인중개사무소 정보로 보강
        brokers = await _enhanceWithSeoulGlobalBrokerData(brokers);
        
        // 3-2. 매칭 실패한 것들은 부동산 중개업소 정보로 보강
        brokers = await _enhanceWithSeoulBrokerData(brokers);
      }

      
      return BrokerSearchResult(
        brokers: brokers,
        radiusMetersUsed: radiusUsed,
        wasExpanded: wasExpanded || radiusUsed != radiusMeters,
      );
    } catch (e) {
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
    
    // BBOX 생성 (EPSG:4326 기준)
    final bbox = _generateEpsg4326Bbox(latitude, longitude, radiusMeters);
    
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


    final proxyUri = Uri.parse(
      '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
    );
    
    
    http.Response response;
    try {
      response = await http.get(proxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          throw Exception('API 타임아웃');
        },
      );
      
    } catch (e) {
      return [];
    }
    
    if (response.statusCode == 200) {
      try {
        final jsonText = utf8.decode(response.bodyBytes);
        
        final brokers = _parseJSON(jsonText, latitude, longitude);
        
        return brokers;
      } catch (e) {
        return [];
      }
    } else {
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
    
    return const BrokerSearchResult(
      brokers: [],
      radiusMetersUsed: maxRadius,
      wasExpanded: true,
    );
  }

  /// 서울시 글로벌공인중개사무소 정보 조회 및 기존 Broker 목록과 매칭하여 보강
  static Future<List<Broker>> _enhanceWithSeoulGlobalBrokerData(List<Broker> brokers) async {
    if (brokers.isEmpty) return brokers;
    
    try {
      
      // 서울 지역인지 확인 (sggCode로 판단하거나, 주소에 "서울" 포함 여부로 판단)
      final seoulBrokers = brokers.where((b) {
        final address = b.roadAddress.isNotEmpty ? b.roadAddress : b.jibunAddress;
        return address.contains('서울') || b.sggCode?.startsWith('11') == true;
      }).toList();
      
      
      if (seoulBrokers.isEmpty) {
        return brokers;
      }
      
      // 서울시 글로벌공인중개사무소 데이터 조회
      final globalBrokerData = await _fetchSeoulGlobalBrokerData();
      
      if (globalBrokerData.isEmpty) {
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
      } else {
      }
      return enhancedBrokers;
    } catch (e) {
      return brokers; // 오류 발생 시 원본 반환
    }
  }
  
  /// 서울시 글로벌공인중개사무소 API에서 데이터 조회
  static Future<List<Map<String, dynamic>>> _fetchSeoulGlobalBrokerData() async {
    try {
      final apiKey = ApiConstants.seoulOpenApiKey;
      if (apiKey.isEmpty) {
        return [];
      }
      
      
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
        return [];
      }
      
      final countJson = json.decode(utf8.decode(countResponse.bodyBytes));
      final totalCount = int.tryParse(countJson['brkPgGlobal']?['list_total_count']?.toString() ?? '0') ?? 0;
      
      
      if (totalCount == 0) {
        return [];
      }
      
      // 한 번에 최대 1000건까지만 조회 가능
      final maxIndex = totalCount > 1000 ? 1000 : totalCount;
      final dataUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/brkPgGlobal/1/$maxIndex/';
      
      final dataProxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(dataUrl)}',
      );
      
      
      final dataResponse = await http.get(dataProxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      
      if (dataResponse.statusCode != 200) {
        return [];
      }
      
      final dataJson = json.decode(utf8.decode(dataResponse.bodyBytes));
      final result = dataJson['brkPgGlobal'];
      
      if (result == null) {
        return [];
      }
      
      // RESULT 확인
      final resultCode = result['RESULT']?['CODE']?.toString() ?? '';
      if (resultCode != 'INFO-000') {
        return [];
      }
      
      // row 데이터 추출
      final rows = result['row'];
      if (rows == null) {
        return [];
      }
      
      List<Map<String, dynamic>> brokerList = [];
      if (rows is List) {
        brokerList = rows.cast<Map<String, dynamic>>().toList();
      } else if (rows is Map) {
        brokerList = [Map<String, dynamic>.from(rows)];
      }
      
      
      return brokerList;
    } catch (e) {
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
        return [];
      }
      
      // 먼저 전체 데이터 개수 조회
      final countUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/landBizInfo/1/1/';
      
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(countUrl)}',
      );
      
      
      final countResponse = await http.get(proxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      
      
      if (countResponse.statusCode != 200) {
        
        return [];
      }
      
      final countJson = json.decode(utf8.decode(countResponse.bodyBytes));
      
      final totalCount = int.tryParse(countJson['landBizInfo']?['list_total_count']?.toString() ?? '0') ?? 0;
      
      
      if (totalCount == 0) {
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
      
      if (requiredRegNos != null) {
      }
      
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
          if (requiredRegNos != null) {
          }
        }
      }
      
      if (requiredRegNos != null) {
      }
      
      return allBrokerList;
    } catch (e) {
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
      }
      return enhancedBrokers;
    } catch (e) {
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

    try {
      final data = json.decode(jsonText);
      
      final List<dynamic> features = data['features'] ?? [];

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
          } catch (e) {
            // 좌표 파싱 실패 시 거리 계산 스킵
            Logger.warning(
              '좌표 파싱 실패',
              metadata: {'coordinates': coordinates.toString(), 'error': e.toString()},
            );
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
    } catch (e) {
      // 파싱 실패 시 빈 리스트 반환
    }

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

