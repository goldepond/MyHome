import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';

/// 공인중개사 등록번호 검증 결과
class BrokerValidationResult {
  final bool isValid;
  final String? errorMessage;
  final BrokerInfo? brokerInfo;

  BrokerValidationResult({
    required this.isValid,
    this.errorMessage,
    this.brokerInfo,
  });

  factory BrokerValidationResult.success(BrokerInfo info) {
    return BrokerValidationResult(
      isValid: true,
      brokerInfo: info,
    );
  }

  factory BrokerValidationResult.failure(String message) {
    return BrokerValidationResult(
      isValid: false,
      errorMessage: message,
    );
  }
}

/// 공인중개사 정보 모델
class BrokerInfo {
  final String registrationNumber; // 등록번호
  final String ownerName;          // 대표자명
  final String businessName;       // 상호명
  final String address;            // 소재지
  final String? phoneNumber;       // 전화번호
  final bool isBusinessActive;     // 영업 상태 (true: 영업중)
  final String? systemRegNo;       // 시스템 고유 번호 (V-World 등)

  BrokerInfo({
    required this.registrationNumber,
    required this.ownerName,
    required this.businessName,
    required this.address,
    this.phoneNumber,
    this.isBusinessActive = true,
    this.systemRegNo,
  });
}

/// 전국 공인중개사 검증 서비스 (V-World 연동)
class BrokerVerificationService {
  
  /// 등록번호 및 대표자명 검증
  static Future<BrokerValidationResult> validateBroker({
    required String registrationNumber,
    required String ownerName,
  }) async {
    print('🌐 [BrokerVerification] ========== API 검증 시작 ==========');
    print('🌐 [BrokerVerification] 등록번호: $registrationNumber');
    print('🌐 [BrokerVerification] 대표자명: $ownerName');

    // 1. 입력값 기본 검증
    if (registrationNumber.isEmpty) {
      print('❌ [BrokerVerification] 등록번호 미입력');
      return BrokerValidationResult.failure('등록번호를 입력해주세요.');
    }
    if (ownerName.isEmpty) {
      print('❌ [BrokerVerification] 대표자명 미입력');
      return BrokerValidationResult.failure('대표자명을 입력해주세요.');
    }

    try {
      // 2. V-World API 호출 (부동산중개업 정보 조회)
      // 필터: brkpg_regist_no (등록번호)가 일치하는지 확인
      final queryParams = {
        'service': 'data',
        'request': 'GetFeature',
        'data': 'LT_C_UQ111', // 부동산중개업 레이어
        'key': VWorldApiConstants.apiKey,
        'format': 'json',
        'size': '10',
        'domain': 'myhome.app', // 모바일 앱 도메인 식별자
        'attrFilter': 'brkpg_regist_no:like:$registrationNumber',
      };

      // V-World WFS API 엔드포인트 사용
      // base url: https://api.vworld.kr/ned/wfs/getEstateBrkpgWFS (AppConstants에 정의된 URL이 이것과 다를 수 있으므로 확인 필요)
      // 여기서는 일반적인 data API 엔드포인트 사용 (https://api.vworld.kr/req/data)
      final uri = Uri.https('api.vworld.kr', '/req/data', queryParams);
      print('🌐 [BrokerVerification] API URL: $uri');

      // 앱 환경이므로 프록시 없이 직접 호출 시도
      print('🌐 [BrokerVerification] API 호출 중...');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5), // 짧은 타임아웃
        onTimeout: () => throw Exception('API 타임아웃'),
      );
      print('🌐 [BrokerVerification] API 응답 코드: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonText = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonText);
        print('🌐 [BrokerVerification] 응답 데이터: ${data.toString().substring(0, data.toString().length > 500 ? 500 : data.toString().length)}...');

        // V-World 응답 구조 파싱
        final responseData = data['response'];
        print('🌐 [BrokerVerification] response.status: ${responseData?['status']}');

        if (responseData != null && responseData['status'] == 'OK') {
          final resultData = responseData['result'];
          final features = resultData['featureCollection']['features'] as List?;
          print('🌐 [BrokerVerification] features 개수: ${features?.length ?? 0}');

          if (features != null && features.isNotEmpty) {
            for (final Map<String, dynamic> feature in features) {
              final props = feature['properties'];
              print('🌐 [BrokerVerification] feature properties: $props');
              // 필드명은 V-World 버전에 따라 다를 수 있음 (brkr_nm, bsnm_cmpnm 등)
              // brkr_nm: 중개업자명(대표자)
              // bsnm_cmpnm: 사업자상호
              final apiOwnerName = props['brkr_nm']?.toString() ?? '';
              print('🌐 [BrokerVerification] API 대표자명: $apiOwnerName');
              print('🌐 [BrokerVerification] 입력 대표자명: $ownerName');

              // 대표자명 비교 (공백 제거 등 정규화 후 비교)
              final namesMatch = _compareNames(ownerName, apiOwnerName);
              print('🌐 [BrokerVerification] 이름 일치 여부: $namesMatch');

              if (namesMatch) {
                print('✅ [BrokerVerification] 검증 성공!');
                print('✅ [BrokerVerification] 사업자명: ${props['bsnm_cmpnm']}');
                print('✅ [BrokerVerification] 주소: ${props['rdnmadr'] ?? props['mnnmadr']}');
                return BrokerValidationResult.success(BrokerInfo(
                  registrationNumber: props['brkpg_regist_no']?.toString() ?? registrationNumber,
                  ownerName: apiOwnerName,
                  businessName: props['bsnm_cmpnm']?.toString() ?? '',
                  address: props['rdnmadr']?.toString() ?? props['mnnmadr']?.toString() ?? '',
                  phoneNumber: props['telno']?.toString(),
                  systemRegNo: feature['id']?.toString(),
                ));
              }
            }

            print('❌ [BrokerVerification] 대표자명 불일치');
            return BrokerValidationResult.failure(
              '등록번호는 확인되었으나 대표자명이 일치하지 않습니다.\n'
              '입력하신 대표자명: $ownerName'
            );
          } else {
             print('❌ [BrokerVerification] features 없음');
             // 데이터 없음 -> Mock 또는 실패
          }
        } else {
          print('❌ [BrokerVerification] API 응답 status가 OK가 아님');
        }
      } else {
        print('❌ [BrokerVerification] API 응답 코드 오류: ${response.statusCode}');
        print('❌ [BrokerVerification] 응답 본문: ${response.body}');
      }

      // API 호출 실패 또는 데이터 없음 -> 검증 실패 처리
      print('❌ [BrokerVerification] 검증 실패 - 데이터 없음');
      return BrokerValidationResult.failure(
        '국가공간정보포털(V-World)에서 해당 정보를 찾을 수 없습니다.\n'
        '등록번호와 대표자명을 정확히 입력해주세요.'
      );

    } catch (e) {
      print('❌ [BrokerVerification] 예외 발생: $e');
      // 에러 발생 시 검증 실패 처리
      return BrokerValidationResult.failure(
        '공인중개사 검증 중 오류가 발생했습니다.\n'
        '네트워크 연결을 확인하고 다시 시도해주세요.'
      );
    }
  }
  
  /// 이름 비교 (부분 일치 허용, 공백 제거)
  static bool _compareNames(String name1, String name2) {
    final n1 = name1.replaceAll(RegExp(r'\s+'), '').trim();
    final n2 = name2.replaceAll(RegExp(r'\s+'), '').trim();
    return n1 == n2 || n1.contains(n2) || n2.contains(n1);
  }
}
