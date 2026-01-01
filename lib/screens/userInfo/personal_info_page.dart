import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/screens/main_page.dart';
import 'package:property/screens/change_password_page.dart';
import 'package:property/screens/policy/privacy_policy_page.dart';
import 'package:property/screens/policy/terms_of_service_page.dart';
import 'package:property/widgets/customer_service_dialog.dart';

class PersonalInfoPage extends StatefulWidget {
  final String userId;
  final String userName;

  const PersonalInfoPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final FirebaseService _firebaseService = FirebaseService();
  
  // 사용자 정보 관련 변수들
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;
  

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    if (mounted) {
      setState(() {
        _isLoadingUserData = true;
      });
    }
    
    try {
      final userData = await _firebaseService.getUser(widget.userId);
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoadingUserData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }


  // 로그아웃 기능
  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AirbnbColors.error),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Firebase 로그아웃
      await _firebaseService.signOut();
      
      // 로그인 페이지로 이동하고 모든 이전 페이지 스택 제거
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const MainPage(
              userId: '',
              userName: '',
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  // 회원탈퇴 기능
  Future<void> _deleteAccount(BuildContext context) async {
    // 첫 번째 확인 다이얼로그
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원탈퇴'),
        content: const Text(
          '정말 회원탈퇴를 하시겠습니까?\n\n'
          '탈퇴 시 모든 데이터가 삭제되며 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AirbnbColors.error),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;
    if (!mounted) return;
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '⚠️ 최종 확인',
          style: TextStyle(color: AirbnbColors.error),
        ),
        content: const Text(
          '회원탈퇴를 진행하시겠습니까?\n\n'
          '이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AirbnbColors.error),
            child: const Text(
              '탈퇴하기',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (finalConfirm != true) return;

    // 로딩 다이얼로그 표시
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('회원탈퇴 처리 중...'),
          ],
        ),
      ),
    );

    try {
      final errorMessage = await _firebaseService.deleteUserAccount(widget.userId);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      if (errorMessage == null) {
        // 성공
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('회원탈퇴가 완료되었습니다.'),
              backgroundColor: AirbnbColors.success,
              duration: Duration(seconds: 3),
            ),
          );

          // 메인 페이지로 이동하고 모든 스택 제거
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainPage(
                userId: '',
                userName: '',
              ),
            ),
            (route) => false,
          );
        }
      } else {
        // 실패
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AirbnbColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원탈퇴 중 오류가 발생했습니다: $e'),
            backgroundColor: AirbnbColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final bannerHeight = isMobile ? AppSpacing.xxxl * 5 : (isTablet ? AppSpacing.xxxl * 5.625 : AppSpacing.xxxl * 6.25);
    const double overlapHeight = AppSpacing.xxxl * 1.25;

    return Scaffold(
      backgroundColor: AirbnbColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            alignment: Alignment.topCenter,
          children: [
              // 히어로 배너 (메인페이지 스타일)
            Container(
                height: bannerHeight,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 48.0 : 64.0,
                horizontal: isMobile ? 24.0 : 48.0,
              ),
              decoration: const BoxDecoration(
                color: AirbnbColors.background,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 매우 큰 헤드라인 (Stripe/Vercel 스타일)
                    Text(
                      '내 정보',
                      textAlign: TextAlign.center,
                      style: AppTypography.withColor(
                        AppTypography.display.copyWith(
                          fontSize: isMobile ? AppTypography.display.fontSize! : (isTablet ? AppTypography.display.fontSize! * 1.3 : AppTypography.display.fontSize! * 1.6),
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                        AirbnbColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // 큰 서브헤드
                    Text(
                      '내 계정 정보를 확인하고 관리하세요',
                      textAlign: TextAlign.center,
                      style: AppTypography.withColor(
                        AppTypography.bodyLarge.copyWith(
                          fontSize: isMobile ? AppTypography.bodyLarge.fontSize! : AppTypography.h4.fontSize!,
                          fontWeight: FontWeight.w400,
                          height: 1.6,
                        ),
                        AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

              // 메인 콘텐츠 (배너와 겹치게 배치)
              Padding(
                padding: EdgeInsets.only(top: bannerHeight - overlapHeight),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 사용자 정보 카드
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AirbnbColors.background,
                      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '내 정보',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const ChangePasswordPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.password, color: AirbnbColors.background),
                                label: const Text(
                                  '전화번호 변경',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AirbnbColors.background,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                                  foregroundColor: AirbnbColors.background,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                            if (_isLoadingUserData)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else ...[
                              if (_userData?['email'] != null) ...[
                                const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                                _buildInfoRow(
                                  Icons.email_outlined, 
                                  '이메일', 
                                  _userData!['email'],
                                ),
                              ],
                              if (_userData?['phone'] != null && _userData!['phone'].toString().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                                _buildEditableInfoRow(
                                  Icons.phone_outlined, 
                                  '전화번호', 
                                  _userData!['phone'],
                                  onEdit: () => _showEditPhoneDialog(),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                              _buildEditableInfoRow(
                                Icons.person, 
                                '이름', 
                                _userData?['name'] ?? widget.userName,
                                onEdit: () => _showEditNameDialog(),
                              ),
                              const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                              _buildInfoRow(
                                Icons.badge_outlined, 
                                '역할', 
                                _getRoleDisplayName(_userData?['role'] ?? 'user'),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 계정 정보 섹션
                    if (_userData != null && !_isLoadingUserData) ...[
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: AirbnbColors.background,
                        shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '계정 정보',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AirbnbColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (_userData?['createdAt'] != null) ...[
                                _buildInfoRow(
                                  Icons.calendar_today_outlined,
                                  '가입일',
                                  _formatDate(_userData!['createdAt']),
                                ),
                                const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                              ],
                              if (_userData?['updatedAt'] != null && _userData!['updatedAt'] != _userData!['createdAt']) ...[
                                _buildInfoRow(
                                  Icons.update_outlined,
                                  '최종 수정일',
                                  _formatDate(_userData!['updatedAt']),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // 고객센터 / 문의하기 섹션
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AirbnbColors.background,
                      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Text(
                                '고객센터 / 문의하기',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AirbnbColors.textPrimary,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.support_agent_outlined, color: AirbnbColors.primary),
                              title: const Text('문의하기 / 피드백'),
                              subtitle: const Text('카카오톡, 페이스북, 스레드, 이메일'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                showCustomerServiceDialog(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 정책 및 도움말 섹션
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AirbnbColors.background,
                      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Text(
                                '정책 및 도움말',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AirbnbColors.textPrimary,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.privacy_tip_outlined, color: AirbnbColors.primary),
                              title: const Text('개인정보 처리방침'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.description_outlined, color: AirbnbColors.primary),
                              title: const Text('이용약관'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 로그아웃 섹션
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: AirbnbColors.background,
                      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '계정 관리',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _logout(context),
                                icon: const Icon(Icons.logout, color: AirbnbColors.background),
                                label: const Text(
                                  '로그아웃',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AirbnbColors.background,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AirbnbColors.error,
                                  foregroundColor: AirbnbColors.background,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteAccount(context),
                                icon: const Icon(Icons.delete_forever, color: AirbnbColors.error),
                                label: const Text(
                                  '회원탈퇴',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AirbnbColors.error,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AirbnbColors.error,
                                  side: const BorderSide(color: AirbnbColors.error, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                        const SizedBox(height: 24),
                  ],
              ),
            ),
          ),
        ),
      ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return '관리자';
      case 'broker':
        return '공인중개사';
      case 'user':
      default:
        return '일반 사용자';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return '-';
      }
      
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');
      return '$year년 $month월 $day일';
    } catch (e) {
      return '-';
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AirbnbColors.borderLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: AirbnbColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AirbnbColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AirbnbColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableInfoRow(IconData icon, String label, String value, {required VoidCallback onEdit}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AirbnbColors.borderLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: AirbnbColors.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AirbnbColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AirbnbColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: AirbnbColors.primary),
          onPressed: onEdit,
          tooltip: '$label 수정',
        ),
      ],
    );
  }

  /// 이름 수정 다이얼로그
  Future<void> _showEditNameDialog() async {
    final nameController = TextEditingController(
      text: _userData?['name'] ?? widget.userName ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이름 수정'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '이름',
            border: OutlineInputBorder(),
            hintText: '이름을 입력하세요',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('이름을 입력해주세요.'),
                    backgroundColor: AirbnbColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
              foregroundColor: AirbnbColors.background,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateName(nameController.text.trim());
    }

    nameController.dispose();
  }

  /// 이름 업데이트
  Future<void> _updateName(String newName) async {
    try {
      final success = await _firebaseService.updateUserName(widget.userId, newName);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이름이 수정되었습니다.'),
              backgroundColor: AirbnbColors.success,
            ),
          );
          // 정보 다시 로드
          _loadUserData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이름 수정에 실패했습니다.'),
              backgroundColor: AirbnbColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

  /// 휴대폰 번호 수정 다이얼로그
  Future<void> _showEditPhoneDialog() async {
    final phoneController = TextEditingController(
      text: _userData?['phone'] ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴대폰 번호 수정'),
        content: TextField(
          controller: phoneController,
          decoration: const InputDecoration(
            labelText: '휴대폰 번호',
            border: OutlineInputBorder(),
            hintText: '010-1234-5678',
            helperText: '하이픈(-) 없이 숫자만 입력하거나 하이픈 포함 입력 가능',
          ),
          keyboardType: TextInputType.phone,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('휴대폰 번호를 입력해주세요.'),
                    backgroundColor: AirbnbColors.error,
                  ),
                );
                return;
              }

              // 간단한 전화번호 형식 검증 (하이픈 제거 후 검증)
              final cleanPhone = phone.replaceAll('-', '').replaceAll(' ', '').replaceAll('(', '').replaceAll(')', '');
              if (cleanPhone.length < 10 || cleanPhone.length > 11) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('올바른 휴대폰 번호 형식이 아닙니다.\n예: 010-1234-5678 또는 01012345678'),
                    backgroundColor: AirbnbColors.error,
                  ),
                );
                return;
              }
              // 010, 011, 016, 017, 018, 019로 시작하는지 확인
              if (!cleanPhone.startsWith('010') && 
                  !cleanPhone.startsWith('011') && 
                  !cleanPhone.startsWith('016') && 
                  !cleanPhone.startsWith('017') && 
                  !cleanPhone.startsWith('018') && 
                  !cleanPhone.startsWith('019')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('휴대폰 번호는 010, 011, 016, 017, 018, 019로 시작해야 합니다.'),
                    backgroundColor: AirbnbColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
              foregroundColor: AirbnbColors.background,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updatePhone(phoneController.text.trim());
    }

    phoneController.dispose();
  }

  /// 휴대폰 번호 업데이트
  Future<void> _updatePhone(String newPhone) async {
    try {
      final success = await _firebaseService.updateUserPhone(widget.userId, newPhone);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('휴대폰 번호가 수정되었습니다.'),
              backgroundColor: AirbnbColors.success,
            ),
          );
          // 정보 다시 로드
          _loadUserData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('휴대폰 번호 수정에 실패했습니다.'),
              backgroundColor: AirbnbColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

} 