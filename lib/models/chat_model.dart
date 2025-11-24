import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoom {
  final String id;
  final String quoteRequestId;
  final String userId;
  final String brokerId;
  final String userPhone; // 안심번호 등
  final String brokerPhone;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String lastMessage;
  final bool isClosed;

  ChatRoom({
    required this.id,
    required this.quoteRequestId,
    required this.userId,
    required this.brokerId,
    required this.userPhone,
    required this.brokerPhone,
    required this.createdAt,
    required this.lastMessageAt,
    required this.lastMessage,
    this.isClosed = false,
  });

  factory ChatRoom.fromMap(String id, Map<String, dynamic> map) {
    return ChatRoom(
      id: id,
      quoteRequestId: map['quoteRequestId'] ?? '',
      userId: map['userId'] ?? '',
      brokerId: map['brokerId'] ?? '',
      userPhone: map['userPhone'] ?? '',
      brokerPhone: map['brokerPhone'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: map['lastMessage'] ?? '',
      isClosed: map['isClosed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quoteRequestId': quoteRequestId,
      'userId': userId,
      'brokerId': brokerId,
      'userPhone': userPhone,
      'brokerPhone': brokerPhone,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessage': lastMessage,
      'isClosed': isClosed,
    };
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      roomId: map['roomId'] ?? '',
      senderId: map['senderId'] ?? '',
      message: map['message'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'senderId': senderId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }
}

