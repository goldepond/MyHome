/// 중개사 통계 모델
///
/// 중개사의 실적을 정량화하여 신뢰도를 높이고 공정한 영업 환경을 조성
class BrokerStats {
  final String brokerId;
  final String brokerRegistrationNumber;

  // 거래 통계
  final int totalDeals;           // 총 거래 성사 건수
  final int depositTakenCount;    // 가계약 건수
  final int soldCount;            // 거래 완료 건수
  final double successRate;       // 성사율 (%)

  // 평점 통계
  final double averageRating;     // 평균 평점 (1.0~5.0)
  final int totalReviews;         // 총 리뷰 수
  final int recommendCount;       // 추천 수
  final int notRecommendCount;    // 비추천 수

  // 응답 통계
  final double responseRate;      // 응답률 (%)
  final int avgResponseTimeMinutes; // 평균 응답 시간 (분)
  final int totalInquiries;       // 총 문의 수
  final int respondedCount;       // 응답한 문의 수

  // 전문 분야
  final List<String> specialties; // ['아파트', '빌라', '오피스텔']
  final String? primaryRegion;    // 주요 활동 지역

  // 메타데이터
  final DateTime lastUpdatedAt;

  BrokerStats({
    required this.brokerId,
    required this.brokerRegistrationNumber,
    required this.lastUpdatedAt, this.totalDeals = 0,
    this.depositTakenCount = 0,
    this.soldCount = 0,
    this.successRate = 0.0,
    this.averageRating = 0.0,
    this.totalReviews = 0,
    this.recommendCount = 0,
    this.notRecommendCount = 0,
    this.responseRate = 0.0,
    this.avgResponseTimeMinutes = 0,
    this.totalInquiries = 0,
    this.respondedCount = 0,
    this.specialties = const [],
    this.primaryRegion,
  });

  Map<String, dynamic> toMap() {
    return {
      'brokerId': brokerId,
      'brokerRegistrationNumber': brokerRegistrationNumber,
      'totalDeals': totalDeals,
      'depositTakenCount': depositTakenCount,
      'soldCount': soldCount,
      'successRate': successRate,
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'recommendCount': recommendCount,
      'notRecommendCount': notRecommendCount,
      'responseRate': responseRate,
      'avgResponseTimeMinutes': avgResponseTimeMinutes,
      'totalInquiries': totalInquiries,
      'respondedCount': respondedCount,
      'specialties': specialties,
      'primaryRegion': primaryRegion,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    };
  }

  factory BrokerStats.fromMap(Map<String, dynamic> map) {
    return BrokerStats(
      brokerId: map['brokerId'] ?? '',
      brokerRegistrationNumber: map['brokerRegistrationNumber'] ?? '',
      totalDeals: map['totalDeals'] ?? 0,
      depositTakenCount: map['depositTakenCount'] ?? 0,
      soldCount: map['soldCount'] ?? 0,
      successRate: (map['successRate'] ?? 0).toDouble(),
      averageRating: (map['averageRating'] ?? 0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      recommendCount: map['recommendCount'] ?? 0,
      notRecommendCount: map['notRecommendCount'] ?? 0,
      responseRate: (map['responseRate'] ?? 0).toDouble(),
      avgResponseTimeMinutes: map['avgResponseTimeMinutes'] ?? 0,
      totalInquiries: map['totalInquiries'] ?? 0,
      respondedCount: map['respondedCount'] ?? 0,
      specialties: List<String>.from(map['specialties'] ?? []),
      primaryRegion: map['primaryRegion'],
      lastUpdatedAt: map['lastUpdatedAt'] != null
        ? DateTime.parse(map['lastUpdatedAt'])
        : DateTime.now(),
    );
  }

  BrokerStats copyWith({
    String? brokerId,
    String? brokerRegistrationNumber,
    int? totalDeals,
    int? depositTakenCount,
    int? soldCount,
    double? successRate,
    double? averageRating,
    int? totalReviews,
    int? recommendCount,
    int? notRecommendCount,
    double? responseRate,
    int? avgResponseTimeMinutes,
    int? totalInquiries,
    int? respondedCount,
    List<String>? specialties,
    String? primaryRegion,
    DateTime? lastUpdatedAt,
  }) {
    return BrokerStats(
      brokerId: brokerId ?? this.brokerId,
      brokerRegistrationNumber: brokerRegistrationNumber ?? this.brokerRegistrationNumber,
      totalDeals: totalDeals ?? this.totalDeals,
      depositTakenCount: depositTakenCount ?? this.depositTakenCount,
      soldCount: soldCount ?? this.soldCount,
      successRate: successRate ?? this.successRate,
      averageRating: averageRating ?? this.averageRating,
      totalReviews: totalReviews ?? this.totalReviews,
      recommendCount: recommendCount ?? this.recommendCount,
      notRecommendCount: notRecommendCount ?? this.notRecommendCount,
      responseRate: responseRate ?? this.responseRate,
      avgResponseTimeMinutes: avgResponseTimeMinutes ?? this.avgResponseTimeMinutes,
      totalInquiries: totalInquiries ?? this.totalInquiries,
      respondedCount: respondedCount ?? this.respondedCount,
      specialties: specialties ?? this.specialties,
      primaryRegion: primaryRegion ?? this.primaryRegion,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  /// 추천 비율 계산 (%)
  double get recommendRate {
    if (totalReviews == 0) return 0;
    return (recommendCount / totalReviews) * 100;
  }

  /// 거래 성사율 계산 (%)
  double calculateSuccessRate(int totalParticipations) {
    if (totalParticipations == 0) return 0;
    return (totalDeals / totalParticipations) * 100;
  }

  /// 빈 통계 생성
  factory BrokerStats.empty({
    required String brokerId,
    required String brokerRegistrationNumber,
  }) {
    return BrokerStats(
      brokerId: brokerId,
      brokerRegistrationNumber: brokerRegistrationNumber,
      lastUpdatedAt: DateTime.now(),
    );
  }
}
