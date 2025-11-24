import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

// 도로명 주소 검색 결과 모델
class AddressSearchResult {
  final List<Map<String,String>> fullData; // _JsonMap
  final List<String> addresses;
  final int totalCount;
  final String? errorMessage;

  AddressSearchResult({
    required this.fullData,
    required this.addresses,
    required this.totalCount,
    this.errorMessage,
  });
}

class AddressService {
  // ignore: unused_field
  static const int _coolDown = 3; // Reserved for cooldown, do not remove
  static DateTime lastCalledTime = DateTime.utc(2000); // Reserved

  // 도로명 주소 검색
  //
  // - 최소 2글자 이상만 입력하면 '중앙' → '중앙공원로' 처럼
  //   도로명 / 건물명 일부만으로도 검색이 가능하도록 완화했다.
  Future<AddressSearchResult> searchRoadAddress(String keyword, {int page = 1}) async {
    debugPrint('=== 주소 검색 시작 ===');
    debugPrint('검색 키워드: $keyword');
    debugPrint('페이지: $page');
    
    if (keyword.trim().length < 2) {
      debugPrint('키워드가 너무 짧습니다: ${keyword.trim().length}자');
      return AddressSearchResult(
        fullData: [],
        addresses: [],
        totalCount: 0,
        errorMessage: '도로명, 건물명, 지번 등을 최소 2글자 이상 입력해 주세요.',
      );
    }

    try {
      // API 키 확인
      final apiKey = ApiConstants.jusoApiKey;
      debugPrint('=== API 키 확인 ===');
      debugPrint('API 키 존재 여부: ${apiKey.isNotEmpty}');
      debugPrint('API 키 길이: ${apiKey.length}');
      if (apiKey.isEmpty) {
        debugPrint('⚠️ API 키가 비어있습니다!');
      } else {
        debugPrint('API 키 (처음 10자): ${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}...');
      }
      
      final uri = Uri.parse(
        '${ApiConstants.baseJusoUrl}'
        '?currentPage=$page'
        '&countPerPage=${ApiConstants.pageSize}'
        '&keyword=${Uri.encodeComponent(keyword)}'
        '&confmKey=$apiKey'
        '&resultType=json',
      );

      debugPrint('=== 요청 URL 생성 ===');
      debugPrint('기본 URL: ${ApiConstants.baseJusoUrl}');
      debugPrint('요청 파라미터:');
      debugPrint('  - currentPage: $page');
      debugPrint('  - countPerPage: ${ApiConstants.pageSize}');
      debugPrint('  - keyword: $keyword');
      debugPrint('  - confmKey: ${apiKey.isNotEmpty ? "${apiKey.substring(0, apiKey.length > 10 ? 10 : apiKey.length)}..." : "(비어있음)"}');
      debugPrint('  - resultType: json');
      debugPrint('최종 URI: ${uri.toString().replaceAll(apiKey, '***API_KEY***')}');

      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );
      
      debugPrint('프록시 URI: ${proxyUri.toString().replaceAll(apiKey, '***API_KEY***')}');
      
      debugPrint('=== HTTP 요청 시작 ===');
      http.Response response;
      try {
        debugPrint('프록시 서버로 요청 전송 중...');
        response = await http.get(proxyUri).timeout(
        Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
            debugPrint('⏱️ 요청 타임아웃 발생');
          throw TimeoutException('주소 검색 시간이 초과되었습니다.');
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
        // HTTP 요청 자체가 실패한 경우
        if (e is TimeoutException) {
          debugPrint('타임아웃으로 인한 실패');
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '주소 검색 시간이 초과되었습니다.',
          );
        }
        // 기타 네트워크 오류
        debugPrint('네트워크 오류로 인한 실패');
        return AddressSearchResult(
          fullData: [],
          addresses: [],
          totalCount: 0,
          errorMessage: '네트워크 연결 오류가 발생했습니다. 인터넷 연결을 확인해주세요.',
        );
      }
      
      debugPrint('=== 응답 상태 확인 ===');
      // 503 또는 5xx 에러 처리
      if (response.statusCode == 503 || (response.statusCode >= 500 && response.statusCode < 600)) {
        debugPrint('❌ 서버 오류 발생: ${response.statusCode}');
        debugPrint('응답 본문: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        return AddressSearchResult(
          fullData: [],
          addresses: [],
          totalCount: 0,
          errorMessage: '주소 검색 서비스가 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해주세요. (오류 코드: ${response.statusCode})',
        );
      }
      
      if (response.statusCode == 200) {
        debugPrint('✅ HTTP 200 응답 수신');
        // 응답 본문이 비어있는지 확인
        if (response.body.isEmpty) {
          debugPrint('❌ 응답 본문이 비어있습니다');
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '서버에서 빈 응답을 받았습니다.',
          );
        }
        
        debugPrint('=== JSON 파싱 시작 ===');
        debugPrint('응답 본문 (처음 500자): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        
        Map<String, dynamic> data;
        try {
          final decoded = json.decode(response.body);
          debugPrint('JSON 파싱 성공');
          debugPrint('파싱된 데이터 타입: ${decoded.runtimeType}');
          
          if (decoded is! Map<String, dynamic>) {
            debugPrint('❌ 주소 검색 응답이 Map 형식이 아닙니다: ${decoded.runtimeType}');
            return AddressSearchResult(
              fullData: [],
              addresses: [],
              totalCount: 0,
              errorMessage: '서버 응답 형식 오류가 발생했습니다.',
            );
          }
          data = decoded;
          debugPrint('응답 데이터 키: ${data.keys.toList()}');
        } catch (e, stackTrace) {
          debugPrint('주소 검색 JSON 파싱 오류: $e');
          debugPrint('예외 타입: ${e.runtimeType}');
          debugPrint('스택 트레이스: $stackTrace');
          final bodyPreview = response.body.length > 200 
              ? response.body.substring(0, 200) 
              : response.body;
          debugPrint('응답 본문 (일부): $bodyPreview');
          
          // minified 예외 처리
          final typeName = e.runtimeType.toString();
          if (typeName.startsWith('minified:')) {
            return AddressSearchResult(
              fullData: [],
              addresses: [],
              totalCount: 0,
              errorMessage: '서버 응답을 처리하는 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
            );
          }
          
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '서버 응답 형식 오류가 발생했습니다.',
          );
        }
        
        // results 키가 없는 경우 처리
        if (data['results'] == null || data['results'] is! Map) {
          debugPrint('주소 검색 응답에 results 키가 없거나 형식이 올바르지 않습니다.');
          debugPrint('응답 데이터 키: ${data.keys.toList()}');
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '서버 응답 형식이 올바르지 않습니다.',
          );
        }
        
        debugPrint('=== API 응답 분석 ===');
        final results = data['results'] as Map<String, dynamic>;
        debugPrint('results 타입: ${results.runtimeType}');
        debugPrint('results 키: ${results.keys.toList()}');
        
        final common = results['common'];
        debugPrint('common 타입: ${common.runtimeType}');
        
        if (common is Map) {
          debugPrint('common 키: ${common.keys.toList()}');
          debugPrint('common 내용: $common');
        }
        
        final errorCode = common is Map ? common['errorCode'] : null;
        final errorMsg = common is Map ? common['errorMessage'] : null;
        
        debugPrint('오류 코드: $errorCode');
        debugPrint('오류 메시지: $errorMsg');
        
        if (errorCode != '0') {
          debugPrint('❌ API 오류 발생');
          debugPrint('오류 코드: $errorCode');
          debugPrint('오류 메시지: $errorMsg');
          debugPrint('전체 응답 데이터: $data');
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: 'API 오류: $errorMsg',
          );
        }
        
        debugPrint('✅ API 오류 없음 (errorCode: 0)');
        
        try {
          debugPrint('=== 검색 결과 처리 시작 ===');
          // results는 이미 위에서 선언됨
          final common = results['common'] as Map<String, dynamic>?;
          final juso = results['juso'];
          
          debugPrint('juso 타입: ${juso.runtimeType}');
          if (juso is List) {
            debugPrint('juso 리스트 길이: ${juso.length}');
          }
          
          final total = common != null 
              ? int.tryParse(common['totalCount']?.toString() ?? '0') ?? 0
              : 0;
          
          debugPrint('전체 검색 결과 수: $total');
          
          if (juso != null && juso.length > 0) {
            debugPrint('✅ 검색 결과 발견: ${juso.length}개');
            final List<dynamic> rawList = juso as List;
            
            debugPrint('주소 리스트 변환 시작...');
            final addressList = rawList
                .map((e) {
                  final road = e['roadAddr']?.toString() ?? '';
                  final jibun = e['jibunAddr']?.toString() ?? '';
                  if (road.isEmpty) return jibun;
                  if (jibun.isEmpty) return road;
                  return '$road\n지번 $jibun';
                })
                .where((e) => e.isNotEmpty)
                .toList();
            
            debugPrint('주소 리스트 변환 완료: ${addressList.length}개');
            
            debugPrint('전체 데이터 변환 시작...');
            final List<Map<String,String>> convertedFullData = rawList
                .map((item) {
                  try {
                    final map = item as Map<String, dynamic>;
                    return map.map((key, value) => MapEntry(key, value?.toString() ?? ''));
                  } catch (e) {
                    debugPrint('❌ 주소 데이터 변환 오류: $e');
                    return <String, String>{};
                  }
                })
                .where((e) => e.isNotEmpty)
                .toList();
            
            debugPrint('전체 데이터 변환 완료: ${convertedFullData.length}개');
            debugPrint('=== 주소 검색 성공 ===');
            
            return AddressSearchResult(
              fullData: convertedFullData,
              addresses: addressList,
              totalCount: total,
            );
          } else {
            debugPrint('⚠️ 검색 결과 없음');
            debugPrint('juso: $juso');
            return AddressSearchResult(
              fullData: [],
              addresses: [],
              totalCount: 0,
              errorMessage: '검색 결과 없음',
            );
          }
        } catch (e, stackTrace) {
          debugPrint('❌ 검색 결과 처리 중 예외 발생');
          debugPrint('예외 타입: ${e.runtimeType}');
          debugPrint('예외 메시지: $e');
          debugPrint('스택 트레이스: $stackTrace');
          debugPrint('응답 데이터: $data');
          
          String errorMsg = '검색 결과 처리 중 오류가 발생했습니다.';
          final typeName = e.runtimeType.toString();
          if (typeName.startsWith('minified:')) {
            errorMsg = '검색 결과를 처리하는 중 오류가 발생했습니다.';
          }
          
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: errorMsg,
          );
        }
      } else {
        debugPrint('❌ HTTP 상태 코드 오류: ${response.statusCode}');
        debugPrint('응답 본문: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        return AddressSearchResult(
          fullData: [],
          addresses: [],
          totalCount: 0,
          errorMessage: 'API 서버 오류 (${response.statusCode})',
        );
      }
    } on TimeoutException {
      return AddressSearchResult(
        fullData: [],
        addresses: [],
        totalCount: 0,
        errorMessage: '주소 검색 시간이 초과되었습니다.',
      );
    } catch (e, stackTrace) {
      // 디버그 모드에서 상세 로깅
      debugPrint('주소 검색 예외 발생:');
      debugPrint('예외 타입: ${e.runtimeType}');
      debugPrint('예외 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');
      
      // 예외 메시지를 안전하게 추출
      String errorMsg = '알 수 없는 오류가 발생했습니다.';
      try {
        final typeName = e.runtimeType.toString();
        
        // minified 타입 감지 (릴리스 빌드)
        if (typeName.startsWith('minified:')) {
          // minified 예외는 일반적인 오류 메시지로 대체
          errorMsg = '주소 검색 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
        } else if (e is TimeoutException) {
          errorMsg = '주소 검색 시간이 초과되었습니다.';
        } else if (e is FormatException) {
          errorMsg = '서버 응답 형식 오류가 발생했습니다.';
        } else if (e is http.ClientException) {
          errorMsg = '네트워크 연결 오류가 발생했습니다.';
        } else if (e is SocketException) {
          errorMsg = '네트워크 연결을 할 수 없습니다.';
        } else {
          final exceptionStr = e.toString();
          
          // Instance of가 포함되지 않은 경우에만 메시지 사용
          if (!exceptionStr.contains('Instance of') && 
              !exceptionStr.contains('minified:') && 
              exceptionStr.isNotEmpty) {
            errorMsg = exceptionStr.length > 100 
                ? exceptionStr.substring(0, 100) 
                : exceptionStr;
          } else if (typeName.isNotEmpty && 
                     typeName != 'Object' && 
                     !typeName.startsWith('minified:')) {
            // 타입 이름으로 대체 (minified 제외)
            errorMsg = '주소 검색 중 오류가 발생했습니다.';
          }
        }
      } catch (_) {
        // 예외 처리 중 오류 발생 시 기본 메시지 사용
        debugPrint('예외 메시지 추출 중 오류 발생');
      }
      
      return AddressSearchResult(
        fullData: [],
        addresses: [],
        totalCount: 0,
        errorMessage: errorMsg,
      );
    }
  }

  // EPSG 5179(UTM-K GRS80), VWORLD 는 EPSG 4326

  // http://125.60.46.141/addrlink/qna/qnaDetail.do?currentPage=3&keyword=%EC%A2%8C%ED%91%9C%EC%A0%9C%EA%B3%B5&searchType=subjectCn&noticeType=QNA&noticeTypeTmp=QNA&noticeMgtSn=128567&bulletinRefSn=128567&page=
} 