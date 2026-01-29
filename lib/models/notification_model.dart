import 'package:cloud_firestore/cloud_firestore.dart';

/// 알림 타입 상수
class NotificationType {
  static const String quoteReceived = 'quote_received';
  static const String quoteAnswered = 'quote_answered';
  static const String brokerSelected = 'broker_selected';
  static const String propertyRegistered = 'property_registered';
  static const String info = 'info';

  // MLS 거래 관련 알림
  static const String propertyDepositTaken = 'property_deposit_taken';  // 가계약 성사
  static const String propertySold = 'property_sold';                    // 거래 완료
  static const String propertyExpired = 'property_expired';              // 매물 만료
  static const String competitorAdvanced = 'competitor_advanced';        // 다른 중개사 단계 상승
  static const String visitScheduleApproved = 'visit_schedule_approved'; // 방문 승인
  static const String visitScheduleRejected = 'visit_schedule_rejected'; // 방문 거절
}

class NotificationModel {
  final String id;
  final String userId; // 알림 받는 사람
  final String title;
  final String message;
  final String type; // 'quote_received', 'quote_selected', 'property_registered' 등
  final String? relatedId; // 관련된 ID (견적ID, 매물ID 등)
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt, this.relatedId,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'info',
      relatedId: map['relatedId'],
      isRead: map['isRead'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

