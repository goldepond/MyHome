import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/broker_verification_service.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/utils/validation_utils.dart';

/// 공인중개사 회원가입 페이지
class BrokerSignupPage extends StatefulWidget {
  const BrokerSignupPage({super.key});

  @override
  State<BrokerSignupPage> createState() => _BrokerSignupPageState();
}

class _BrokerSignupPageState extends State<BrokerSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  bool _isLoading = false;
  bool _isValidating = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  BrokerInfo? _validatedBrokerInfo;

  final FirebaseService _firebaseService = FirebaseService();

  // 각 필드별 에러 메시지
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _ownerNameError;
  String? _businessNameError;
  String? _phoneNumberError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _registrationNumberController.dispose();
    _ownerNameController.dispose();
    _businessNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  /// 등록번호 및 대표자명 검증
  Future<void> _validateBroker() async {
    if (_registrationNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('등록번호를 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_ownerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('대표자명을 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isValidating = true;
      _validatedBrokerInfo = null;
    });

    try {
      // 등록번호 중복 확인
      final existingBroker = await _firebaseService.getBrokerByRegistrationNumber(
        _registrationNumberController.text.trim(),
      );

      if (existingBroker != null) {
        setState(() {
          _isValidating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 가입된 등록번호입니다. 로그인해주세요.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // API 검증
      final result = await BrokerVerificationService.validateBroker(
        registrationNumber: _registrationNumberController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
      );

      setState(() {
        _isValidating = false;
      });

      if (result.isValid && result.brokerInfo != null) {
        setState(() {
          _validatedBrokerInfo = result.brokerInfo;
        });

        // 검증된 정보로 자동 채우기
        _businessNameController.text = result.brokerInfo!.businessName;
        if (result.brokerInfo!.phoneNumber != null && result.brokerInfo!.phoneNumber!.isNotEmpty) {
          _phoneNumberController.text = result.brokerInfo!.phoneNumber!;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 검증 성공! 정보가 자동으로 입력되었습니다.'),
              backgroundColor: AppColors.kSuccess,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? '검증에 실패했습니다.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isValidating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('검증 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 회원가입 제출
  Future<void> _submitSignup() async {
    // 모든 에러 초기화
    setState(() {
      _emailError = null;
      _passwordError = null;
      _passwordConfirmError = null;
      _ownerNameError = null;
      _businessNameError = null;
      _phoneNumberError = null;
    });
    
    bool hasError = false;
    
    // 이메일 검증
    if (_emailController.text.isEmpty) {
      setState(() => _emailError = '이메일을 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.isValidEmail(_emailController.text)) {
      setState(() => _emailError = '올바른 이메일 형식이 아닙니다');
      hasError = true;
    }
    
    // 비밀번호 검증
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = '비밀번호를 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.isValidPasswordLength(_passwordController.text)) {
      setState(() => _passwordError = '비밀번호는 6자 이상이어야 합니다');
      hasError = true;
    }
    
    // 비밀번호 확인 검증
    if (_passwordConfirmController.text.isEmpty) {
      setState(() => _passwordConfirmError = '비밀번호 확인을 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.doPasswordsMatch(_passwordController.text, _passwordConfirmController.text)) {
      setState(() => _passwordConfirmError = '비밀번호가 일치하지 않습니다');
      hasError = true;
    }
    
    // 소유자 이름 검증
    if (_ownerNameController.text.isEmpty) {
      setState(() => _ownerNameError = '소유자 이름을 입력해주세요');
      hasError = true;
    }
    
    // 사무소명 검증
    if (_businessNameController.text.isEmpty) {
      setState(() => _businessNameError = '사무소명을 입력해주세요');
      hasError = true;
    }
    
    // 전화번호 검증
    if (_phoneNumberController.text.isEmpty) {
      setState(() => _phoneNumberError = '전화번호를 입력해주세요');
      hasError = true;
    }
    
    if (hasError) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 등록번호 검증 비활성화 - 검증 없이도 회원가입 가능
    // 검증 정보가 있으면 사용하고, 없으면 직접 입력한 값 사용

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase에 저장
      // 검증 정보가 있으면 사용하고, 없으면 직접 입력한 값 사용
      final errorMessage = await _firebaseService.registerBroker(
        brokerId: _emailController.text.trim(),
        password: _passwordController.text,
        brokerInfo: {
          'brokerRegistrationNumber': _validatedBrokerInfo?.registrationNumber ?? _registrationNumberController.text.trim(),
          'ownerName': _validatedBrokerInfo?.ownerName ?? _ownerNameController.text.trim(),
          'businessName': _businessNameController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'systemRegNo': _validatedBrokerInfo?.systemRegNo,
          'address': _validatedBrokerInfo?.address,
          'verified': _validatedBrokerInfo != null, // 검증 여부
        },
      );

      setState(() {
        _isLoading = false;
      });

      if (errorMessage == null && mounted) {
        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다!'),
            backgroundColor: AppColors.kSuccess,
          ),
        );

        // 로그인 페이지로 이동 (성공 정보 전달)
        Navigator.pop(context, {
          'brokerId': _emailController.text.trim(),
          'password': _passwordController.text,
        });
      } else if (mounted) {
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? '회원가입에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      backgroundColor: AppColors.kBackground,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.kPrimary,
        elevation: 0.5,
        title: const HomeLogoButton(
          fontSize: 18,
          color: AppColors.kPrimary,
        ),
      ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // 제목
              const Text(
                '공인중개사 회원가입',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '등록번호 검증은 선택사항입니다 (검증 없이도 가입 가능)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 32),

              // 등록번호 검증 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _validatedBrokerInfo != null
                        ? AppColors.kSuccess
                        : Colors.grey.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _validatedBrokerInfo != null
                              ? Icons.verified
                              : Icons.verified_user,
                          color: _validatedBrokerInfo != null
                              ? AppColors.kSuccess
                              : AppColors.kPrimary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '등록번호 검증',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        if (_validatedBrokerInfo != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.kSuccess.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '검증 완료',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.kSuccess,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _registrationNumberController,
                      decoration: InputDecoration(
                        labelText: '중개업 등록번호 *',
                        hintText: '예: 11230202200144',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      enabled: !_isValidating,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // 숫자만 입력
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '등록번호를 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ownerNameController,
                      decoration: InputDecoration(
                        labelText: '대표자명 *',
                        hintText: '예: 김중개',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      enabled: !_isValidating,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '대표자명을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isValidating ? null : _validateBroker,
                        icon: _isValidating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.verified_user, size: 20),
                        label: Text(
                          _isValidating ? '검증 중...' : '등록번호 검증하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 기본 정보 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      onChanged: (value) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: '이메일 또는 ID *',
                        hintText: '예: broker@example.com 또는 broker123',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _emailError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _emailError != null ? Colors.red : AppColors.kPrimary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        errorText: _emailError,
                        errorStyle: const TextStyle(fontSize: 12),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이메일 또는 ID를 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      onChanged: (value) {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: '비밀번호 *',
                        hintText: '6자 이상',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _passwordError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _passwordError != null ? Colors.red : AppColors.kPrimary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        errorText: _passwordError,
                        errorStyle: const TextStyle(fontSize: 12),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호를 입력해주세요';
                        }
                        if (!ValidationUtils.isValidPasswordLength(value)) {
                          return '비밀번호는 6자 이상이어야 합니다';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordConfirmController,
                      onChanged: (value) {
                        if (_passwordConfirmError != null) {
                          setState(() => _passwordConfirmError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인 *',
                        hintText: '비밀번호를 다시 입력하세요',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePasswordConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePasswordConfirm = !_obscurePasswordConfirm;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _passwordConfirmError != null ? Colors.red : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _passwordConfirmError != null ? Colors.red : AppColors.kPrimary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                        errorText: _passwordConfirmError,
                        errorStyle: const TextStyle(fontSize: 12),
                      ),
                      obscureText: _obscurePasswordConfirm,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '비밀번호 확인을 입력해주세요';
                        }
                        if (!ValidationUtils.doPasswordsMatch(_passwordController.text, value)) {
                          return '비밀번호가 일치하지 않습니다';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessNameController,
                      onChanged: (value) {
                        if (_businessNameError != null) {
                          setState(() => _businessNameError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: '사업자상호 *',
                        hintText: '예: ○○부동산',
                        prefixIcon: const Icon(Icons.business),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '사업자상호를 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneNumberController,
                      decoration: InputDecoration(
                        labelText: '전화번호',
                        hintText: '예: 0212345678',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.withValues(alpha: 0.05),
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')), // 숫자만 입력
                      ],
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
                  onPressed: _isLoading ? null : _submitSignup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                    backgroundColor: AppColors.kPrimary,
                    foregroundColor: Colors.white,
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
                      color: AppColors.kPrimary,
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
    ),
    );
  }
}


