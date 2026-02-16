/// 중개 제안 모델
///
/// 공개 매물에 대해 중개사가 자유롭게 제안하는 경쟁 모델.
/// 판매자/관리자가 제안을 비교하고 한 명을 선정한다.
class BrokerOffer {
  final String id;
  final String propertyId; // 매물 ID
  final String propertyAddress; // 매물 주소 (조회 편의)

  // 중개사 정보
  final String brokerName; // 중개사 이름
  final String brokerPhone; // 전화번호
  final String? brokerCompany; // 사무소명
  final String? brokerId; // 앱 내 중개사 ID (있을 경우)

  // 제안 내용
  final String pitch; // 한마디 (왜 나를 선택해야 하는지)

  // 상태
  final BrokerOfferStatus status;
  final DateTime? selectedAt; // 선정 시각

  // 타임스탬프
  final DateTime createdAt;

  BrokerOffer({
    required this.id,
    required this.propertyId,
    required this.brokerName,
    required this.brokerPhone,
    required this.pitch,
    required this.createdAt,
    this.propertyAddress = '',
    this.brokerCompany,
    this.brokerId,
    this.status = BrokerOfferStatus.pending,
    this.selectedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propertyId': propertyId,
      'propertyAddress': propertyAddress,
      'brokerName': brokerName,
      'brokerPhone': brokerPhone,
      'brokerCompany': brokerCompany,
      'brokerId': brokerId,
      'pitch': pitch,
      'status': status.toString().split('.').last,
      'selectedAt': selectedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BrokerOffer.fromMap(Map<String, dynamic> map) {
    return BrokerOffer(
      id: map['id'] ?? '',
      propertyId: map['propertyId'] ?? '',
      propertyAddress: map['propertyAddress'] ?? '',
      brokerName: map['brokerName'] ?? '',
      brokerPhone: map['brokerPhone'] ?? '',
      brokerCompany: map['brokerCompany'],
      brokerId: map['brokerId'],
      pitch: map['pitch'] ?? '',
      status: BrokerOfferStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => BrokerOfferStatus.pending,
      ),
      selectedAt: map['selectedAt'] != null
          ? DateTime.parse(map['selectedAt'])
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}

/// 중개 제안 상태
enum BrokerOfferStatus {
  pending, // 제안 대기
  selected, // 선정됨
  rejected, // 미선정
}
