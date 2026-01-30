import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../api_request/firebase_service.dart';
import '../../models/chat_model.dart';
import '../../constants/app_constants.dart';
import '../../widgets/report_dialog.dart';

class ChatRoomPage extends StatefulWidget {
  final String roomId;
  final String title; // 상대방 이름

  const ChatRoomPage({
    required this.roomId,
    required this.title,
    super.key,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // 상대방 (중개사) 정보
  String? _otherParticipantId;
  String? _otherParticipantName;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    try {
      final roomData = await _firebaseService.getChatRoom(widget.roomId);
      if (roomData != null && mounted) {
        final participants = roomData['participants'] as List<dynamic>?;
        if (participants != null) {
          // 현재 사용자가 아닌 다른 참여자 찾기
          for (final participant in participants) {
            final id = participant['id'] as String?;
            if (id != null && id != _currentUserId) {
              setState(() {
                _otherParticipantId = id;
                _otherParticipantName = participant['name'] as String? ?? widget.title;
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      // 실패 시 widget.title 사용
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 1,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'report') {
                _reportBroker();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 20, color: AirbnbColors.textSecondary),
                    SizedBox(width: 12),
                    Text('중개사 신고'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
        body: SafeArea(
          child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _firebaseService.getChatMessages(widget.roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('대화를 시작해보세요.'));
                }

                return ListView.builder(
                  reverse: true, // 최신 메시지가 아래에 오도록
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final timeFormat = DateFormat('a h:mm', 'ko_KR');
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMe) ...[
            Text(
              timeFormat.format(message.timestamp),
              style: const TextStyle(fontSize: 10, color: AirbnbColors.textSecondary),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AirbnbColors.primary : AirbnbColors.background,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isMe ? const Radius.circular(0) : null,
                bottomLeft: !isMe ? const Radius.circular(0) : null,
              ),
              boxShadow: [
                BoxShadow(
                  color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              message.message,
              style: TextStyle(
                color: isMe ? AirbnbColors.background : AirbnbColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
          if (!isMe) ...[
            const SizedBox(width: 4),
            Text(
              timeFormat.format(message.timestamp),
              style: const TextStyle(fontSize: 10, color: AirbnbColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AirbnbColors.background,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: '메시지 입력...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AirbnbColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                minLines: 1,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AirbnbColors.primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: AirbnbColors.background, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _firebaseService.sendMessage(
      roomId: widget.roomId,
      senderId: _currentUserId,
      message: text,
    );

    _messageController.clear();
  }

  Future<void> _reportBroker() async {
    if (_otherParticipantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상대방 정보를 불러오는 중입니다. 잠시 후 다시 시도해주세요.')),
      );
      return;
    }

    // 현재 사용자 정보 가져오기
    final userData = await _firebaseService.getUser(_currentUserId);
    final reporterName = userData?['name'] as String? ??
                        FirebaseAuth.instance.currentUser?.email ??
                        '익명';

    if (mounted) {
      showReportDialog(
        context: context,
        reporterId: _currentUserId,
        reporterName: reporterName,
        brokerId: _otherParticipantId!,
        brokerName: _otherParticipantName ?? widget.title,
      );
    }
  }
}

