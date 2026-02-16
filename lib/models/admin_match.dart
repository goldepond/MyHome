/// 관리자 수동 매칭 모델
///
/// 관리자가 외부 매물의 집주인과 중개사를 직접 연결할 때
/// 매칭 과정과 상태를 추적하는 모델
class AdminMatch {
  final String id;
  final String propertyId; // 매물 ID
  final String? propertyAddress; // 매물 주소 (조회 편의)

  // 중개사 정보
  final String? brokerId; // 앱 내 중개사 ID (있을 경우)
  final String brokerName; // 중개사 이름
  final String? brokerPhone; // 중개사 전화번호
  final String? brokerCompany; // 중개사무소명

  // 관리자 정보
  final String adminId; // 매칭 처리 관리자 ID

  // 매칭 상태
  final AdminMatchStatus status;

  // 연락처 공유 추적
  final String? sellerPhone; // 집주인 번호
  final bool contactShared; // 연락처 공유 여부
  final DateTime? contactSharedAt; // 연락처 공유 시각

  // 메모 및 추가 정보
  final String? notes; // 관리자 메모 (통화 내용 등)
  final String? buyerInfo; // 매수자 정보 메모

  // 타임스탬프
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminMatch({
    required this.id,
    required this.propertyId,
    required this.brokerName,
    required this.adminId,
    required this.createdAt,
    required this.updatedAt,
    this.propertyAddress,
    this.brokerId,
    this.brokerPhone,
    this.brokerCompany,
    this.status = AdminMatchStatus.pending,
    this.sellerPhone,
    this.contactShared = false,
    this.contactSharedAt,
    this.notes,
    this.buyerInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'propertyId': propertyId,
      'propertyAddress': propertyAddress,
      'brokerId': brokerId,
      'brokerName': brokerName,
      'brokerPhone': brokerPhone,
      'brokerCompany': brokerCompany,
      'adminId': adminId,
      'status': status.toString().split('.').last,
      'sellerPhone': sellerPhone,
      'contactShared': contactShared,
      'contactSharedAt': contactSharedAt?.toIso8601String(),
      'notes': notes,
      'buyerInfo': buyerInfo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AdminMatch.fromMap(Map<String, dynamic> map) {
    return AdminMatch(
      id: map['id'] ?? '',
      propertyId: map['propertyId'] ?? '',
      propertyAddress: map['propertyAddress'],
      brokerId: map['brokerId'],
      brokerName: map['brokerName'] ?? '',
      brokerPhone: map['brokerPhone'],
      brokerCompany: map['brokerCompany'],
      adminId: map['adminId'] ?? '',
      status: AdminMatchStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => AdminMatchStatus.pending,
      ),
      sellerPhone: map['sellerPhone'],
      contactShared: map['contactShared'] ?? false,
      contactSharedAt: map['contactSharedAt'] != null
          ? DateTime.parse(map['contactSharedAt'])
          : null,
      notes: map['notes'],
      buyerInfo: map['buyerInfo'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  AdminMatch copyWith({
    String? id,
    String? propertyId,
    String? propertyAddress,
    String? brokerId,
    String? brokerName,
    String? brokerPhone,
    String? brokerCompany,
    String? adminId,
    AdminMatchStatus? status,
    String? sellerPhone,
    bool? contactShared,
    DateTime? contactSharedAt,
    String? notes,
    String? buyerInfo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminMatch(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      brokerId: brokerId ?? this.brokerId,
      brokerName: brokerName ?? this.brokerName,
      brokerPhone: brokerPhone ?? this.brokerPhone,
      brokerCompany: brokerCompany ?? this.brokerCompany,
      adminId: adminId ?? this.adminId,
      status: status ?? this.status,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      contactShared: contactShared ?? this.contactShared,
      contactSharedAt: contactSharedAt ?? this.contactSharedAt,
      notes: notes ?? this.notes,
      buyerInfo: buyerInfo ?? this.buyerInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 관리자 매칭 상태
enum AdminMatchStatus {
  pending, // 매칭 생성됨
  contacted, // 집주인에게 연락함
  connected, // 중개사-집주인 연결 완료
  visiting, // 방문 진행 중
  completed, // 거래 성사
  failed, // 불발
}
