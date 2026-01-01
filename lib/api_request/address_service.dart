import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';
import 'package:property/utils/logger.dart';

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
    
    // 키워드가 비어있는지 확인
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return AddressSearchResult(
        fullData: [],
        addresses: [],
        totalCount: 0,
        errorMessage: '검색 키워드를 입력해주세요.',
      );
    }
    
    // 비정상적인 키워드 필터링 (컴파일 에러 메시지, 경고 메시지 등)
    if (trimmedKeyword.contains('error:') || 
        trimmedKeyword.contains('warning:') ||
        trimmedKeyword.contains('at [property]') ||
        trimmedKeyword.contains('list_element_type_not_assignable') ||
        trimmedKeyword.contains('unnecessary_cast') ||
        trimmedKeyword.contains('unused_element') ||
        trimmedKeyword.contains('unused_field') ||
        trimmedKeyword.contains('unused_local_variable') ||
        trimmedKeyword.contains('unused_import') ||
        trimmedKeyword.contains('unnecessary_null_comparison') ||
        trimmedKeyword.contains('unnecessary_non_null_assertion') ||
        trimmedKeyword.length > 500) {
      return AddressSearchResult(
        fullData: [],
        addresses: [],
        totalCount: 0,
        errorMessage: '올바른 주소를 입력해주세요.',
      );
    }
    
    if (trimmedKeyword.length < 2) {
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
      if (apiKey.isEmpty) {
      } else {
      }
      
      final uri = Uri.parse(
        '${ApiConstants.baseJusoUrl}'
        '?currentPage=$page'
        '&countPerPage=${ApiConstants.pageSize}'
        '&keyword=${Uri.encodeComponent(trimmedKeyword)}'
        '&confmKey=$apiKey'
        '&resultType=json',
      );


      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );
      
      
      http.Response response;
      try {
        response = await http.get(proxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
        onTimeout: () {
          throw TimeoutException('주소 검색 시간이 초과되었습니다.');
        },
      );
      } catch (e) {
        // HTTP 요청 자체가 실패한 경우
        if (e is TimeoutException) {
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '주소 검색 시간이 초과되었습니다.',
          );
        }
        // 기타 네트워크 오류
        return AddressSearchResult(
          fullData: [],
          addresses: [],
          totalCount: 0,
          errorMessage: '네트워크 연결 오류가 발생했습니다. 인터넷 연결을 확인해주세요.',
        );
      }
      
      // 503 또는 5xx 에러 처리
      if (response.statusCode == 503 || (response.statusCode >= 500 && response.statusCode < 600)) {
        return AddressSearchResult(
          fullData: [],
          addresses: [],
          totalCount: 0,
          errorMessage: '주소 검색 서비스가 일시적으로 사용할 수 없습니다. 잠시 후 다시 시도해주세요. (오류 코드: ${response.statusCode})',
        );
      }
      
      if (response.statusCode == 200) {
        // 응답 본문이 비어있는지 확인
        if (response.body.isEmpty) {
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '서버에서 빈 응답을 받았습니다.',
          );
        }
        
        
        Map<String, dynamic> data;
        try {
          final decoded = json.decode(response.body);
          
          if (decoded is! Map<String, dynamic>) {
            return AddressSearchResult(
              fullData: [],
              addresses: [],
              totalCount: 0,
              errorMessage: '서버 응답 형식 오류가 발생했습니다.',
            );
          }
          data = decoded;
        } catch (e) {
          
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
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: '서버 응답 형식이 올바르지 않습니다.',
          );
        }
        
        final results = data['results'] as Map<String, dynamic>;
        
        final common = results['common'];
        
        if (common is Map) {
        }
        
        final errorCode = common is Map ? common['errorCode'] : null;
        final errorMsg = common is Map ? common['errorMessage'] : null;
        
        
        if (errorCode != '0') {
          return AddressSearchResult(
            fullData: [],
            addresses: [],
            totalCount: 0,
            errorMessage: 'API 오류: $errorMsg',
          );
        }
        
        
        try {
          // results는 이미 위에서 선언됨
          final common = results['common'] as Map<String, dynamic>?;
          final juso = results['juso'];
          
          if (juso is List) {
          }
          
          final total = common != null 
              ? int.tryParse(common['totalCount']?.toString() ?? '0') ?? 0
              : 0;
          
          
          if (juso != null && juso.length > 0) {
            final List<dynamic> rawList = juso as List;
            
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
            
            
            final List<Map<String,String>> convertedFullData = rawList
                .map((item) {
                  try {
                    final map = item as Map<String, dynamic>;
                    return map.map((key, value) => MapEntry(key, value?.toString() ?? ''));
                  } catch (e) {
                    return <String, String>{};
                  }
                })
                .where((e) => e.isNotEmpty)
                .toList();
            
            
            return AddressSearchResult(
              fullData: convertedFullData,
              addresses: addressList,
              totalCount: total,
            );
          } else {
            return AddressSearchResult(
              fullData: [],
              addresses: [],
              totalCount: 0,
              errorMessage: '검색 결과 없음',
            );
          }
        } catch (e) {
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
    } catch (e) {
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
      } catch (e) {
        // 예외 처리 중 오류 발생 시 로깅
        Logger.warning(
          '주소 검색 예외 처리 중 오류',
          metadata: {'error': e.toString()},
        );
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