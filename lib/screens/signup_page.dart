import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/utils/validation_utils.dart';
import 'package:property/screens/login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _agreeToPrivacy = false;
  bool _agreeToMarketing = false;
  final FirebaseService _firebaseService = FirebaseService();

  // 각 필드별 에러 메시지
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _passwordConfirmError;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }
  
  Color _getPasswordStrengthColor(int strength) {
    if (strength <= 1) return AirbnbColors.error;
    if (strength == 2) return AirbnbColors.warning;
    if (strength == 3) return AirbnbColors.primary;
    return AirbnbColors.success;
  }

  Future<void> _signup() async {
    // 모든 에러 초기화
    setState(() {
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
      _passwordConfirmError = null;
    });
    
    bool hasError = false;
    
    // 이메일 검증
    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = '이메일을 입력해주세요';
      });
      hasError = true;
    } else if (!ValidationUtils.isValidEmail(_emailController.text)) {
      setState(() {
        _emailError = '올바른 이메일 형식이 아닙니다 (예: user@example.com)';
      });
      hasError = true;
    }
    
    // 휴대폰 번호 검증 (입력된 경우만)
    if (_phoneController.text.isNotEmpty) {
      final phone = _phoneController.text.replaceAll('-', '').replaceAll(' ', '');
      if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(phone)) {
        setState(() {
          _phoneError = '올바른 휴대폰 번호를 입력해주세요 (예: 01012345678)';
        });
        hasError = true;
      }
    }

    // 비밀번호 검증
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = '비밀번호를 입력해주세요';
      });
      hasError = true;
    } else if (!ValidationUtils.isValidPasswordLength(_passwordController.text)) {
      setState(() {
        _passwordError = '비밀번호는 6자 이상이어야 합니다';
      });
      hasError = true;
    }

    // 비밀번호 확인 검증
    if (_passwordConfirmController.text.isEmpty) {
      setState(() {
        _passwordConfirmError = '비밀번호 확인을 입력해주세요';
      });
      hasError = true;
    } else if (!ValidationUtils.doPasswordsMatch(_passwordController.text, _passwordConfirmController.text)) {
      setState(() {
        _passwordConfirmError = '비밀번호가 일치하지 않습니다';
      });
      hasError = true;
    }
    
    // 약관 동의 확인
    if (!_agreeToTerms || !_agreeToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('필수 약관에 동의해주세요'),
          backgroundColor: AirbnbColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      hasError = true;
    }
    
    // 에러가 있으면 중단
    if (hasError) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 이메일에서 ID 추출 (@ 앞부분)
      final id = _emailController.text.split('@')[0];
      
      // 휴대폰 번호 (입력된 경우만)
      final phone = _phoneController.text.isNotEmpty 
          ? _phoneController.text.replaceAll('-', '').replaceAll(' ', '')
          : null;
      
      // 기본 이름 (이메일 앞부분 사용)
      final name = id;
      
      final success = await _firebaseService.registerUser(
        id,
        _passwordController.text,
        name,
        email: _emailController.text,
        phone: phone,
        role: 'user', // 모든 사용자는 일반 사용자로 등록
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다. 로그인해주세요.'),
            backgroundColor: AirbnbColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const LoginPage(returnResult: false),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 존재하는 이메일입니다.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('회원가입 중 오류가 발생했습니다: $e'),
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
      backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0.5,
        title: const HomeLogoButton(
          fontSize: 18,
          color: AirbnbColors.primary,
        ),
      ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목
            const Text(
              '일반 회원가입',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: AirbnbColors.textPrimary,
                letterSpacing: -1.5,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '이메일과 비밀번호로 간단하게 가입하세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: AirbnbColors.textSecondary,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 32),

            // 회원가입 폼
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AirbnbColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '기본 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AirbnbColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 이메일 입력 (필수)
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      if (_emailError != null) {
                        setState(() {
                          _emailError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '이메일 *',
                      hintText: '예: user@example.com',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _emailError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _emailError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _emailError,
                      errorStyle: const TextStyle(fontSize: 12),
                      helperText: _emailError == null ? '이메일이 로그인 ID로 사용됩니다' : null,
                      helperStyle: TextStyle(fontSize: 12, color: AirbnbColors.textLight),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 휴대폰 번호 입력 (선택)
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // 숫자만 입력
                    ],
                    onChanged: (value) {
                      if (_phoneError != null) {
                        setState(() {
                          _phoneError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '휴대폰 번호',
                      hintText: '예: 01012345678',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _phoneError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _phoneError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _phoneError,
                      errorStyle: const TextStyle(fontSize: 12),
                      helperText: _phoneError == null ? '본인 확인 및 비밀번호 찾기에 사용됩니다' : null,
                      helperStyle: TextStyle(fontSize: 12, color: AirbnbColors.textLight),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 비밀번호 입력
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (value) {
                      setState(() {
                        if (_passwordError != null) {
                          _passwordError = null;
                        }
                      });
                    },
                    decoration: InputDecoration(
                      labelText: '비밀번호 *',
                      hintText: '6자 이상 (영문, 숫자, 특수문자 조합 권장)',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _passwordError,
                      errorStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  
                  // 비밀번호 강도 표시
                  if (_passwordController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: ValidationUtils.getPasswordStrength(_passwordController.text) / 4,
                            backgroundColor: AirbnbColors.border,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getPasswordStrengthColor(ValidationUtils.getPasswordStrength(_passwordController.text)),
                            ),
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          ValidationUtils.getPasswordStrengthText(ValidationUtils.getPasswordStrength(_passwordController.text)),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getPasswordStrengthColor(ValidationUtils.getPasswordStrength(_passwordController.text)),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // 비밀번호 확인 입력
                  TextField(
                    controller: _passwordConfirmController,
                    obscureText: true,
                    onChanged: (value) {
                      if (_passwordConfirmError != null) {
                        setState(() {
                          _passwordConfirmError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '비밀번호 확인 *',
                      hintText: '비밀번호를 다시 입력하세요',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordConfirmError != null ? AirbnbColors.error : AirbnbColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _passwordConfirmError != null ? AirbnbColors.error : AirbnbColors.primary, 
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AirbnbColors.error, width: 2),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      errorText: _passwordConfirmError,
                      errorStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 약관 동의
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AirbnbColors.border),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _agreeToTerms,
                          onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                          title: const Text('서비스 이용약관 동의 (필수)', style: TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AirbnbColors.primary,
                        ),
                        CheckboxListTile(
                          value: _agreeToPrivacy,
                          onChanged: (value) => setState(() => _agreeToPrivacy = value ?? false),
                          title: const Text('개인정보 처리방침 동의 (필수)', style: TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AirbnbColors.primary,
                        ),
                        CheckboxListTile(
                          value: _agreeToMarketing,
                          onChanged: (value) => setState(() => _agreeToMarketing = value ?? false),
                          title: const Text('마케팅 정보 수신 동의 (선택)', style: TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: AirbnbColors.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 회원가입 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _signup,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                        ),
                      )
                    : const Icon(Icons.person_add, size: 24),
                label: Text(
                  _isLoading ? '가입 중...' : '회원가입',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                  foregroundColor: AirbnbColors.textWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 로그인으로 이동
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '이미 계정이 있으신가요? 로그인',
                  style: TextStyle(
                    fontSize: 14,
                    color: AirbnbColors.primary,
                  ),
                ),
              ),
            ),
          ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

