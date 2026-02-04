import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property/constants/app_constants.dart';
import 'package:property/utils/logger.dart';

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
    // 1. 입력값 기본 검증
    if (registrationNumber.isEmpty) {
      return BrokerValidationResult.failure('등록번호를 입력해주세요.');
    }
    if (ownerName.isEmpty) {
      return BrokerValidationResult.failure('대표자명을 입력해주세요.');
    }

    try {
      // 2. V-World API 호출 (부동산중개업 정보 조회)
      final queryParams = {
        'service': 'data',
        'request': 'GetFeature',
        'data': 'LT_C_UQ111',
        'key': VWorldApiConstants.apiKey,
        'format': 'json',
        'size': '10',
        'domain': 'myhome.app',
        'attrFilter': 'brkpg_regist_no:like:$registrationNumber',
      };

      final uri = Uri.https('api.vworld.kr', '/req/data', queryParams);
      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('API 타임아웃'),
      );

      if (response.statusCode == 200) {
        final jsonText = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonText);
        final responseData = data['response'];

        if (responseData != null && responseData['status'] == 'OK') {
          final resultData = responseData['result'];
          final features = resultData['featureCollection']['features'] as List?;

          if (features != null && features.isNotEmpty) {
            for (final Map<String, dynamic> feature in features) {
              final props = feature['properties'];
              final apiOwnerName = props['brkr_nm']?.toString() ?? '';
              final namesMatch = _compareNames(ownerName, apiOwnerName);

              if (namesMatch) {
                Logger.info('공인중개사 검증 성공: $registrationNumber');
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

            return BrokerValidationResult.failure(
              '등록번호는 확인되었으나 대표자명이 일치하지 않습니다.\n'
              '입력하신 대표자명: $ownerName'
            );
          }
        }
      }

      // API 호출 실패 또는 데이터 없음
      return BrokerValidationResult.failure(
        '국가공간정보포털(V-World)에서 해당 정보를 찾을 수 없습니다.\n'
        '등록번호와 대표자명을 정확히 입력해주세요.'
      );

    } catch (e) {
      Logger.warning('공인중개사 검증 실패', metadata: {'error': e.toString()});
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
