import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/action_log.dart';
import '../../api_request/log_service.dart';
import '../../constants/app_constants.dart';

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
      backgroundColor: AppColors.kBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사용자 활동 로그',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.kPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '앱 내 사용자들의 주요 활동 내역을 실시간으로 확인합니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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
    
    IconData icon;
    Color color;
    
    switch (log.actionType) {
      case 'view_screen':
        icon = Icons.visibility;
        color = Colors.blue;
        break;
      case 'click':
        icon = Icons.touch_app;
        color = Colors.orange;
        break;
      case 'submit':
        icon = Icons.send;
        color = Colors.green;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.grey;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        '${log.actionType} : ${log.target}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User: ${log.userId}'),
          Text(
            dateFormat.format(log.timestamp),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          if (log.metadata.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.metadata.toString(),
                style: const TextStyle(fontFamily: 'Courier', fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

