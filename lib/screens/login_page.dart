import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/api_request/firebase_service.dart';
import 'forgot_password_page.dart';
import 'main_page.dart';
import 'broker/broker_dashboard_page.dart';
import 'user_type_selection_page.dart';

/// 통합 로그인 페이지 (일반 사용자/공인중개사 자동 구분)
class LoginPage extends StatefulWidget {
  final bool returnResult; // true: pop으로 결과 반환, false: 화면 전환까지 처리
  const LoginPage({super.key, this.returnResult = true});

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
      final result = await _firebaseService.authenticateUnified(
        _idController.text.trim(),
        _passwordController.text,
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
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => BrokerDashboardPage(
                  brokerId: brokerId,
                  brokerName: brokerName,
                  brokerData: result,
                ),
              ),
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
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.'),
            backgroundColor: AirbnbColors.error,
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
            backgroundColor: AirbnbColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: AirbnbColors.error,
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
          return false;
        }
        return true;
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
      backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 2,
        toolbarHeight: 70,
        shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로가기',
        ),
        centerTitle: true,
        title: Text(
          'MyHome',
          style: AppTypography.withColor(
            AppTypography.h2.copyWith(fontWeight: FontWeight.bold),
            AirbnbColors.primary,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AirbnbColors.background,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: EdgeInsets.all(AppSpacing.xxl),
                decoration: BoxDecoration(
                  color: AirbnbColors.background,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AirbnbColors.textPrimary.withValues(alpha: 0.08),
                      offset: const Offset(0, 8),
                      blurRadius: 24,
                      spreadRadius: 0,
                    ),
                  ],
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
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.5,
                                height: 1.1,
                              ),
                              AirbnbColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: AppSpacing.lg),
                          Text(
                            '계정에 로그인하여 서비스를 이용하세요',
                            style: AppTypography.withColor(
                              AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w400,
                                height: 1.6,
                              ),
                              AirbnbColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxl),
                    
                    // 아이디 입력
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이메일',
                          style: AppTypography.withColor(
                            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            AirbnbColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _idController,
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: '이메일을 입력하세요',
                            hintStyle: AppTypography.withColor(
                              AppTypography.bodySmall.copyWith(fontSize: 15),
                              AirbnbColors.textLight,
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: AirbnbColors.textSecondary,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AirbnbColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AirbnbColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: AirbnbColors.surface,
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg),
                    
                    // 비밀번호 입력
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '비밀번호',
                          style: AppTypography.withColor(
                            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            AirbnbColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: AppTypography.body,
                          decoration: InputDecoration(
                            hintText: '비밀번호를 입력하세요',
                            hintStyle: AppTypography.withColor(
                              AppTypography.bodySmall.copyWith(fontSize: 15),
                              AirbnbColors.textLight,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AirbnbColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                size: 20,
                                color: AirbnbColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AirbnbColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AirbnbColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
                            ),
                            filled: true,
                            fillColor: AirbnbColors.surface,
                            contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                          foregroundColor: AirbnbColors.textWhite,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                                ),
                              )
                            : const Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                            AirbnbColors.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg),
                    
                    // 회원가입 안내 섹션
                    Container(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AirbnbColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AirbnbColors.primary.withValues(alpha: 0.2),
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
                              AirbnbColors.textSecondary,
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
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
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
                                AirbnbColors.primary,
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
