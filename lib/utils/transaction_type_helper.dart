/// 거래 유형에 따른 텍스트 변환 유틸리티
/// 
/// 매매/전세/월세 거래 유형에 따라 적절한 용어를 반환합니다.
class TransactionTypeHelper {
  /// 소유자 역할 텍스트 반환
  /// - 매매: 판매자
  /// - 전세/월세: 임대인
  static String getOwnerRole(String transactionType) {
    return transactionType == '매매' ? '판매자' : '임대인';
  }
  
  /// 구매자 역할 텍스트 반환
  /// - 매매: 구매자
  /// - 전세/월세: 임차인
  static String getBuyerRole(String transactionType) {
    return transactionType == '매매' ? '구매자' : '임차인';
  }
  
  /// 가격 라벨 반환
  static String getPriceLabel(String transactionType) {
    switch (transactionType) {
      case '매매':
        return '매매가';
      case '전세':
        return '전세 보증금';
      case '월세':
        return '월세';
      default:
        return '가격';
    }
  }
  
  /// 권장 가격 라벨 반환
  static String getRecommendedPriceLabel(String transactionType) {
    switch (transactionType) {
      case '매매':
        return '권장 매도가';
      case '전세':
        return '권장 전세금';
      case '월세':
        return '권장 임대료';
      default:
        return '권장 가격';
    }
  }
  
  /// 희망 가격 라벨 반환
  static String getDesiredPriceLabel(String transactionType) {
    switch (transactionType) {
      case '매매':
        return '희망 매도가';
      case '전세':
        return '희망 전세금';
      case '월세':
        return '희망 임대료';
      default:
        return '희망 가격';
    }
  }
  
  /// 적정 가격 라벨 반환
  static String getAppropriatePriceLabel(String transactionType) {
    switch (transactionType) {
      case '매매':
        return '적정 매도가';
      case '전세':
        return '적정 전세금';
      case '월세':
        return '적정 임대료';
      default:
        return '적정 가격';
    }
  }
  
  /// 가격 질문 텍스트 반환
  static String getPriceQuestion(String transactionType) {
    switch (transactionType) {
      case '매매':
        return '매도가는 얼마로 보시나요?';
      case '전세':
        return '전세금은 얼마로 보시나요?';
      case '월세':
        return '임대료는 얼마로 보시나요?';
      default:
        return '가격은 얼마로 보시나요?';
    }
  }
  
  /// 소유자 호칭 반환 (님 붙임)
  static String getOwnerRoleWithHonorific(String transactionType) {
    return '${getOwnerRole(transactionType)}님';
  }
  
  /// 구매자 호칭 반환 (님 붙임)
  static String getBuyerRoleWithHonorific(String transactionType) {
    return '${getBuyerRole(transactionType)}님';
  }
}

