import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/apple_design_system.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/firebase_service.dart';
import 'forgot_password_page.dart';
import 'main_page.dart';
import 'broker/mls_broker_dashboard_page.dart';
import 'user_type_selection_page.dart';

/// 로그인 모드
enum LoginMode {
  login,    // 기존 계정 로그인
  register, // 회원가입
}

/// 통합 로그인 페이지 (일반 사용자/공인중개사 자동 구분)
class LoginPage extends StatefulWidget {
  final bool returnResult; // true: pop으로 결과 반환, false: 화면 전환까지 처리
  final LoginMode initialMode; // 초기 모드 (로그인/회원가입)
  const LoginPage({super.key, this.returnResult = true, this.initialMode = LoginMode.login});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 로그인 필드
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 통합 로그인 (일반 사용자/공인중개사 자동 구분)
  Future<void> _login() async {
    if (_idController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 비밀번호 사용
      final password = _passwordController.text.trim();

      final result = await _firebaseService.authenticateUnified(
        _idController.text.trim(),
        password,
      );

      if (result != null && mounted) {
        final userType = result['userType'] ?? 'user';
        
        if (userType == 'broker') {
          // 공인중개사 로그인
          final brokerId = result['brokerId'] ?? result['uid'];
          final brokerName = result['ownerName'] ?? result['businessName'] ?? '공인중개사';

          if (widget.returnResult) {
            Navigator.of(context).pop({
              'userId': brokerId,
              'userName': brokerName,
              'userType': 'broker',
              'brokerData': result,
            });
          } else {
            // 네비게이션 스택을 완전히 정리하고 새 페이지로 이동
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MLSBrokerDashboardPage(
                  brokerId: brokerId,
                  brokerName: brokerName,
                  brokerData: result,
                ),
              ),
              (route) => false, // 모든 이전 라우트 제거
            );
          }
        } else {
          // 일반 사용자 로그인
          final userId = result['uid'] ?? result['id'] ?? _idController.text;
          final userName = result['name'] ?? userId;

          if (widget.returnResult) {
            Navigator.of(context).pop({
              'userId': userId,
              'userName': userName,
              'userType': 'user',
            });
          } else {
            // 네비게이션 스택을 완전히 정리하고 새 페이지로 이동
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MainPage(
                  userId: userId,
                  userName: userName,
                  initialTabIndex: 0,
                ),
              ),
              (route) => false, // 모든 이전 라우트 제거
            );
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 이메일과 전화번호를 확인해주세요.'),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = '로그인에 실패했습니다.';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '등록되지 않은 이메일입니다.\n회원가입을 먼저 진행해주세요.';
          break;
        case 'wrong-password':
          errorMessage = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          errorMessage = '이메일 형식이 올바르지 않습니다.';
          break;
        default:
          errorMessage = '로그인 중 오류가 발생했습니다.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppleColors.systemRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 소셜 로그인 공통 처리
  Future<void> _handleSocialLoginResult(Map<String, dynamic>? result, String provider) async {
    if (result != null && mounted) {
      final userType = result['userType'] ?? 'user';
      final userId = result['uid'] ?? result['id'] ?? '';
      final userName = result['name'] ?? '사용자';

      if (widget.returnResult) {
        Navigator.of(context).pop({
          'userId': userId,
          'userName': userName,
          'userType': userType,
          'authProvider': provider,
        });
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainPage(
              userId: userId,
              userName: userName,
              initialTabIndex: 0,
            ),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$provider 로그인에 실패했습니다.'),
          backgroundColor: AppleColors.systemRed,
        ),
      );
    }
  }

  // Google 로그인
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.signInWithGoogle();
      await _handleSocialLoginResult(result, 'Google');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google 로그인 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 카카오 로그인
  Future<void> _loginWithKakao() async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.signInWithKakao();
      await _handleSocialLoginResult(result, '카카오');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오 로그인 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 네이버 로그인
  Future<void> _loginWithNaver() async {
    setState(() => _isLoading = true);
    try {
      final result = await _firebaseService.signInWithNaver();
      await _handleSocialLoginResult(result, '네이버');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('네이버 로그인 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 소셜 로그인 버튼들
  Widget _buildSocialLoginButtons() {
    return Column(
      children: [
        // 네이버 로그인 버튼
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _loginWithNaver,
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF03C75A), // 네이버 그린
              foregroundColor: Colors.white,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'N',
                  style: AppTypography.button.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '네이버로 로그인',
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 카카오 로그인 버튼
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _loginWithKakao,
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE500), // 카카오 옐로우
              foregroundColor: const Color(0xFF191919),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 카카오 말풍선 아이콘 (간단한 대체)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF191919),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    size: 12,
                    color: Color(0xFFFEE500),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '카카오로 로그인',
                  style: AppTypography.button.copyWith(color: const Color(0xFF191919)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // 구글 로그인 버튼
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _loginWithGoogle,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppleColors.label,
              side: const BorderSide(color: AppleColors.separator),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google 로고 (간단한 대체)
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppleColors.separator),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF4285F4), // Google Blue
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Google로 로그인',
                  style: AppTypography.button.copyWith(color: AppleColors.label),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
      backgroundColor: AppleColors.systemBackground,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppleColors.systemBackground,
        foregroundColor: AppleColors.label,
        elevation: 2,
        toolbarHeight: 70,
        shadowColor: AppleColors.label.withValues(alpha: 0.1),
        surfaceTintColor: AppleColors.systemBackground.withValues(alpha: 0),
        automaticallyImplyLeading: false,
        leading: AccessibleWidget.iconButton(
          icon: Icons.arrow_back,
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          tooltip: '뒤로가기',
          semanticLabel: '뒤로가기',
        ),
        centerTitle: true,
        title: Text(
          'MyHome',
          style: AppTypography.withColor(
            AppTypography.h2.copyWith(fontWeight: FontWeight.bold),
            AppleColors.systemBlue,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppleColors.systemBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(AppSpacing.xxl),
                decoration: CommonDesignSystem.cardDecoration(
                  borderRadius: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 타이틀 섹션 (메인페이지 스타일)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '로그인',
                            style: AppTypography.withColor(
                              AppTypography.display.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1.1,
                              ),
                              AppleColors.label,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            '계정에 로그인하여 서비스를 이용하세요',
                            style: AppTypography.withColor(
                              AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w400,
                                height: 1.6,
                              ),
                              AppleColors.secondaryLabel,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    
                    // 아이디 입력
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이메일',
                          style: AppTypography.withColor(
                            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            AppleColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _idController,
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: '이메일을 입력하세요',
                            hintStyle: AppTypography.withColor(
                              AppTypography.bodySmall,
                              AppleColors.tertiaryLabel,
                            ),
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: AppleColors.secondaryLabel,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppleColors.separator),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppleColors.separator),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppleColors.systemBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: AppleColors.secondarySystemBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    
                    // 비밀번호 입력
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '비밀번호',
                          style: AppTypography.withColor(
                            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            AppleColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: '비밀번호를 입력하세요',
                            hintStyle: AppTypography.withColor(
                              AppTypography.bodySmall,
                              AppleColors.tertiaryLabel,
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppleColors.secondaryLabel,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: AppleColors.secondaryLabel,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppleColors.separator),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppleColors.separator),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppleColors.systemBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: AppleColors.secondarySystemBackground,
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    
                    // 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: CommonDesignSystem.primaryButtonStyle(),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppleColors.systemBackground),
                                ),
                              )
                            : const Text(
                                '로그인',
                                style: AppTypography.button,
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '비밀번호 찾기',
                          style: AppTypography.withColor(
                            AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            AppleColors.systemBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 소셜 로그인 구분선
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppleColors.separator,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          child: Text(
                            '또는',
                            style: AppTypography.withColor(
                              AppTypography.caption,
                              AppleColors.tertiaryLabel,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppleColors.separator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 소셜 로그인 버튼들
                    _buildSocialLoginButtons(),
                    const SizedBox(height: AppSpacing.lg),

                    // 회원가입 안내 섹션
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppleColors.systemBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppleColors.systemBlue.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '계정이 없으신가요? ',
                            style: AppTypography.withColor(
                              AppTypography.bodySmall,
                              AppleColors.secondaryLabel,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                  builder: (context) => const UserTypeSelectionPage(),
                                  ),
                                );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '회원가입',
                              style: AppTypography.withColor(
                                AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                AppleColors.systemBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 하단 링크 블록 제거 (중복 방지)
                  ],
                ),
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
