import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/login_page.dart';
import 'package:property/screens/main_page.dart';

class SubmitSuccessPage extends StatelessWidget {
  final String title;
  final String description;
  final String userName;
  final String? userId;

  const SubmitSuccessPage({
    super.key,
    required this.title,
    required this.description,
    required this.userName,
    this.userId,
  });

  Future<void> _handleHistoryTap(BuildContext context) async {
    if (userId != null && userId!.isNotEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              MainPage(userId: userId!, userName: userName, initialTabIndex: 2),
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    if (result == null) {
      return;
    }

    if ((result['userId'] is String &&
                (result['userId'] as String).isNotEmpty) ||
            (result['userName'] is String &&
            (result['userName'] as String).isNotEmpty)) {
      final String resolvedUserId =
          (result['userId'] is String &&
              (result['userId'] as String).isNotEmpty)
          ? result['userId']
          : result['userName'];
      final String resolvedUserName =
          (result['userName'] is String &&
              (result['userName'] as String).isNotEmpty)
          ? result['userName']
          : result['userId'];

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MainPage(
            userId: resolvedUserId,
            userName: resolvedUserName,
            initialTabIndex: 2,
          ),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인에 실패했습니다. 이메일/비밀번호를 확인해주세요.'),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 2,
        title: const Text('요청 완료', style: TextStyle(color: AirbnbColors.textPrimary)),
        centerTitle: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AirbnbColors.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: AirbnbColors.success, size: 72),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AirbnbColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AirbnbColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (userId == null || userId!.isEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AirbnbColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AirbnbColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline, color: AirbnbColors.primary, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '게스트 모드로 전송되었습니다. 로그인하면 상담 현황이 자동으로 저장되고 알림을 받을 수 있어요.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AirbnbColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.primary,
                          side: const BorderSide(color: AirbnbColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('계속 둘러보기'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _handleHistoryTap(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.primary,
                          foregroundColor: AirbnbColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            (userId != null && userId!.isNotEmpty)
                                ? '현황 보기'
                                : '로그인하고 현황 보기',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
