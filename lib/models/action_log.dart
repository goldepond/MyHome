import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자 행동 로그 모델
class ActionLog {
  final String? id;
  final String userId; // 사용자 UID (없으면 'anonymous')
  final String actionType; // 'view_screen', 'click', 'submit', 'search'
  final String target; // 화면명 또는 버튼명 (예: 'HouseDetailPage', 'QuoteButton')
  final Map<String, dynamic> metadata; // 추가 정보 (체류시간, 검색어, 매물ID 등)
  final DateTime timestamp;

  ActionLog({
    required this.userId, required this.actionType, required this.target, required this.timestamp, this.id,
    this.metadata = const {},
  });

  factory ActionLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActionLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      actionType: data['actionType'] ?? '',
      target: data['target'] ?? '',
      metadata: data['metadata'] ?? {},
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'actionType': actionType,
      'target': target,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

