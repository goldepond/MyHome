/// 중개 수수료 계산 유틸리티
///
/// 한국 부동산 중개 수수료 관련 법정 기준 및 계산 기능 제공
/// 참고: 공인중개사법 시행규칙 별표 1 (중개보수 요율)
library;

class CommissionCalculator {
  /// 거래 유형
  static const String transactionSale = '매매';
  static const String transactionJeonse = '전세';
  static const String transactionMonthlyRent = '월세';

  /// 매물 유형
  static const String propertyResidential = '주택';
  static const String propertyApartment = '아파트';
  static const String propertyVilla = '빌라';
  static const String propertyOfficetel = '오피스텔';
  static const String propertyCommercial = '상가';
  static const String propertyLand = '토지';

  /// 법정 중개 수수료율 상한 (2021년 10월 개정)
  ///
  /// 매매 기준:
  /// - 5천만원 미만: 0.6% (한도 25만원)
  /// - 5천만원~2억 미만: 0.5% (한도 80만원)
  /// - 2억~9억 미만: 0.4%
  /// - 9억~12억 미만: 0.5%
  /// - 12억~15억 미만: 0.6%
  /// - 15억 이상: 0.7%
  static double getLegalMaxRate({
    required int transactionPrice,
    required String transactionType,
    String? propertyType,
  }) {
    // 주거용 부동산 매매
    if (transactionType == transactionSale) {
      if (transactionPrice < 50000000) {
        return 0.6;
      } else if (transactionPrice < 200000000) {
        return 0.5;
      } else if (transactionPrice < 900000000) {
        return 0.4;
      } else if (transactionPrice < 1200000000) {
        return 0.5;
      } else if (transactionPrice < 1500000000) {
        return 0.6;
      } else {
        return 0.7;
      }
    }

    // 전세
    if (transactionType == transactionJeonse) {
      if (transactionPrice < 50000000) {
        return 0.5;
      } else if (transactionPrice < 100000000) {
        return 0.4;
      } else if (transactionPrice < 600000000) {
        return 0.3;
      } else if (transactionPrice < 1200000000) {
        return 0.4;
      } else if (transactionPrice < 1500000000) {
        return 0.5;
      } else {
        return 0.6;
      }
    }

    // 월세 (보증금 + 월세 × 100 기준)
    if (transactionType == transactionMonthlyRent) {
      if (transactionPrice < 50000000) {
        return 0.5;
      } else if (transactionPrice < 100000000) {
        return 0.4;
      } else if (transactionPrice < 600000000) {
        return 0.3;
      } else if (transactionPrice < 1200000000) {
        return 0.4;
      } else if (transactionPrice < 1500000000) {
        return 0.5;
      } else {
        return 0.6;
      }
    }

    // 기타 (상가, 토지 등): 협의 (상한 0.9%)
    return 0.9;
  }

  /// 법정 수수료 한도 금액 (5천만원~2억 미만 구간)
  static int? getLegalMaxAmount({
    required int transactionPrice,
    required String transactionType,
  }) {
    if (transactionType == transactionSale) {
      if (transactionPrice < 50000000) {
        return 250000; // 25만원
      } else if (transactionPrice < 200000000) {
        return 800000; // 80만원
      }
    }

    if (transactionType == transactionJeonse ||
        transactionType == transactionMonthlyRent) {
      if (transactionPrice < 50000000) {
        return 200000; // 20만원
      } else if (transactionPrice < 100000000) {
        return 300000; // 30만원
      }
    }

    return null; // 한도 없음
  }

  /// 중개 수수료 계산
  ///
  /// [transactionPrice] 거래 금액 (원)
  /// [commissionRate] 수수료율 (%, 예: 0.4 = 0.4%)
  /// [transactionType] 거래 유형 (매매/전세/월세)
  ///
  /// Returns: 계산된 수수료 금액 (원)
  static int calculateCommission({
    required int transactionPrice,
    required double commissionRate,
    String transactionType = transactionSale,
  }) {
    final commission = (transactionPrice * commissionRate / 100).round();

    // 법정 한도 적용
    final maxAmount = getLegalMaxAmount(
      transactionPrice: transactionPrice,
      transactionType: transactionType,
    );

    if (maxAmount != null && commission > maxAmount) {
      return maxAmount;
    }

    return commission;
  }

  /// 수수료율이 법정 상한을 초과하는지 확인
  static bool isRateOverLegalMax({
    required int transactionPrice,
    required double commissionRate,
    required String transactionType,
  }) {
    final maxRate = getLegalMaxRate(
      transactionPrice: transactionPrice,
      transactionType: transactionType,
    );
    return commissionRate > maxRate;
  }

  /// 수수료 검증 결과
  static CommissionValidation validateCommission({
    required int transactionPrice,
    required double commissionRate,
    required String transactionType,
  }) {
    final maxRate = getLegalMaxRate(
      transactionPrice: transactionPrice,
      transactionType: transactionType,
    );

    final calculatedCommission = calculateCommission(
      transactionPrice: transactionPrice,
      commissionRate: commissionRate,
      transactionType: transactionType,
    );

    final maxCommission = calculateCommission(
      transactionPrice: transactionPrice,
      commissionRate: maxRate,
      transactionType: transactionType,
    );

    final isOverMax = commissionRate > maxRate;

    return CommissionValidation(
      isValid: !isOverMax,
      calculatedCommission: calculatedCommission,
      maxLegalRate: maxRate,
      maxLegalCommission: maxCommission,
      isOverLegalMax: isOverMax,
      warningMessage: isOverMax
          ? '법정 최고 수수료율($maxRate%)을 초과합니다.'
          : null,
    );
  }

  /// 수수료 금액 포맷팅 (만원 단위)
  static String formatCommission(int commission) {
    if (commission >= 100000000) {
      final eok = commission / 100000000;
      final remainder = commission % 100000000;
      if (remainder > 0) {
        final man = remainder ~/ 10000;
        if (man > 0) {
          return '${eok.toStringAsFixed(0)}억 $man만원';
        }
      }
      return '${eok.toStringAsFixed(eok == eok.roundToDouble() ? 0 : 1)}억원';
    } else if (commission >= 10000) {
      final man = commission / 10000;
      if (man >= 1000) {
        // 1000만원 이상이면 천만원 단위로
        return '${(man / 100).toStringAsFixed(0)}백만원';
      }
      return '${man.toStringAsFixed(man == man.roundToDouble() ? 0 : 1)}만원';
    }
    return '$commission원';
  }

  /// 거래 금액 문자열에서 숫자 추출
  static int? parsePrice(String? priceStr) {
    if (priceStr == null || priceStr.isEmpty) return null;

    final cleanStr = priceStr.replaceAll(RegExp(r'[^0-9억천만원\.]'), '');

    if (cleanStr.contains('억')) {
      final parts = cleanStr.split('억');
      final double? eok = double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9\.]'), ''));
      if (eok == null) return null;

      int total = (eok * 100000000).toInt();

      if (parts.length > 1) {
        final remainder = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        if (remainder.isNotEmpty) {
          final remainderInt = int.tryParse(remainder);
          if (remainderInt != null) {
            if (parts[1].contains('천만')) {
              total += remainderInt * 10000000;
            } else if (parts[1].contains('만')) {
              total += remainderInt * 10000;
            } else {
              total += remainderInt * 10000;
            }
          }
        }
      }

      return total;
    }

    final digits = cleanStr.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  /// 수수료율 문자열에서 숫자 추출
  static double? parseRate(String? rateStr) {
    if (rateStr == null || rateStr.isEmpty) return null;

    final cleanStr = rateStr.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanStr.isEmpty) return null;

    return double.tryParse(cleanStr);
  }

  /// 월세 거래 금액 계산 (보증금 + 월세 × 100)
  static int calculateMonthlyRentTransactionAmount({
    required int deposit,
    required int monthlyRent,
  }) {
    final calculated = deposit + (monthlyRent * 100);
    // 보증금보다 작으면 보증금 기준
    return calculated > deposit ? calculated : deposit;
  }
}

/// 수수료 검증 결과 클래스
class CommissionValidation {
  final bool isValid;
  final int calculatedCommission;
  final double maxLegalRate;
  final int maxLegalCommission;
  final bool isOverLegalMax;
  final String? warningMessage;

  const CommissionValidation({
    required this.isValid,
    required this.calculatedCommission,
    required this.maxLegalRate,
    required this.maxLegalCommission,
    required this.isOverLegalMax,
    this.warningMessage,
  });
}
