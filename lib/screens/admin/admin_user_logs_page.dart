import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/action_log.dart';
import '../../api_request/log_service.dart';
import '../../constants/app_constants.dart';

/// 화면 이름 한글 매핑
const Map<String, String> _screenNameMap = {
  'MainPage': '메인 홈',
  'MainPageTab': '메인 홈',
  'HomePage': '홈페이지',
  'MLSQuickRegistrationPage': 'MLS 매물 등록',
  'MLSSellerDashboardPage': 'MLS 판매자 대시보드',
  'MLSPropertyDetailPage': 'MLS 매물 상세',
  'BrokerListPage': '중개사 목록',
  'BrokerDetailPage': '중개사 상세',
  'BrokerQuotePage': '중개사 견적 요청',
  'QuoteRequestPage': '견적 요청',
  'QuoteListPage': '견적 목록',
  'ChatPage': '채팅',
  'ChatRoomPage': '채팅방',
  'NotificationPage': '알림',
  'UserInfoPage': '내 정보',
  'PrivacySettingsPage': '개인정보 설정',
  'LoginPage': '로그인',
  'SignUpPage': '회원가입',
  'PropertyDetailPage': '매물 상세',
  'PropertyListPage': '매물 목록',
  'SearchPage': '검색',
  'SettingsPage': '설정',
};

/// 액션 타입 한글 매핑
const Map<String, String> _actionTypeMap = {
  'view_screen': '화면 조회',
  'click': '클릭',
  'submit': '제출',
  'search': '검색',
  'login': '로그인',
  'logout': '로그아웃',
};

class AdminUserLogsPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminUserLogsPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminUserLogsPage> createState() => _AdminUserLogsPageState();
}

class _AdminUserLogsPageState extends State<AdminUserLogsPage> {
  final LogService _logService = LogService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            color: AirbnbColors.background,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '사용자 활동 로그',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AirbnbColors.primary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '앱 내 사용자들의 주요 활동 내역을 실시간으로 확인합니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // 로그 리스트
          Expanded(
            child: StreamBuilder<List<ActionLog>>(
              stream: _logService.getLogs(limit: 100),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('오류 발생: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data ?? [];

                if (logs.isEmpty) {
                  return const Center(child: Text('기록된 로그가 없습니다.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogTile(log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(ActionLog log) {
    final dateFormat = DateFormat('MM/dd HH:mm:ss');

    // 한글로 변환
    final actionKorean = _actionTypeMap[log.actionType] ?? log.actionType;
    final screenKorean = _getScreenNameKorean(log.target);
    final userShortId = _shortenUserId(log.userId);

    IconData icon;
    Color color;

    switch (log.actionType) {
      case 'view_screen':
        icon = Icons.visibility;
        color = AirbnbColors.primary;
        break;
      case 'click':
        icon = Icons.touch_app;
        color = AirbnbColors.warning;
        break;
      case 'submit':
        icon = Icons.send;
        color = AirbnbColors.success;
        break;
      case 'search':
        icon = Icons.search;
        color = AirbnbColors.info;
        break;
      default:
        icon = Icons.info_outline;
        color = AirbnbColors.textSecondary;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        '$actionKorean: $screenKorean',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: AirbnbColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                userShortId,
                style: const TextStyle(fontSize: 12, color: AirbnbColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Icon(Icons.access_time, size: 14, color: AirbnbColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(log.timestamp),
                style: const TextStyle(color: AirbnbColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          if (log.metadata.isNotEmpty && _hasUsefulMetadata(log.metadata))
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatMetadata(log.metadata),
                style: const TextStyle(fontSize: 11, color: AirbnbColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  /// 화면 이름을 한글로 변환
  String _getScreenNameKorean(String target) {
    // 매핑에 있으면 한글 반환
    if (_screenNameMap.containsKey(target)) {
      return _screenNameMap[target]!;
    }

    // minified 또는 dynamic 이름은 "기타 화면"으로 표시
    if (target.contains('minified') || target.contains('dynamic') || target.contains('<')) {
      return '기타 화면';
    }

    // Page 접미사 제거하고 띄어쓰기 추가
    String readable = target.replaceAll('Page', '').replaceAll('Screen', '');
    // CamelCase를 띄어쓰기로 변환
    readable = readable.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return readable;
  }

  /// 사용자 ID를 짧게 표시 (처음 8자만)
  String _shortenUserId(String userId) {
    if (userId == 'anonymous') return '비로그인';
    if (userId.length > 8) {
      return '${userId.substring(0, 8)}...';
    }
    return userId;
  }

  /// 유용한 메타데이터가 있는지 확인
  bool _hasUsefulMetadata(Map<String, dynamic> metadata) {
    // screenClass만 있는 경우는 유용하지 않음
    if (metadata.length == 1 && metadata.containsKey('screenClass')) {
      return false;
    }
    return metadata.isNotEmpty;
  }

  /// 메타데이터를 읽기 쉽게 포맷
  String _formatMetadata(Map<String, dynamic> metadata) {
    final filtered = Map.from(metadata)..remove('screenClass');
    if (filtered.isEmpty) return '';

    return filtered.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }
}

