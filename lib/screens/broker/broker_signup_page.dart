import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
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
  String? _businessNameError;
  String? _registrationNumberError;

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
    print('🔍 [BrokerSignup] 등록번호 검증 시작');
    print('🔍 [BrokerSignup] 등록번호: ${_registrationNumberController.text.trim()}');
    print('🔍 [BrokerSignup] 대표자명: ${_ownerNameController.text.trim()}');

    if (_registrationNumberController.text.trim().isEmpty) {
      print('❌ [BrokerSignup] 등록번호 미입력');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('등록번호를 입력해주세요.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    if (_ownerNameController.text.trim().isEmpty) {
      print('❌ [BrokerSignup] 대표자명 미입력');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('대표자명을 입력해주세요.'),
          backgroundColor: AirbnbColors.warning,
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
      print('🔍 [BrokerSignup] 등록번호 중복 확인 중...');
      final existingBroker = await _firebaseService.getBrokerByRegistrationNumber(
        _registrationNumberController.text.trim(),
      );
      print('🔍 [BrokerSignup] 중복 확인 결과: ${existingBroker != null ? "이미 존재" : "신규"}');

      if (existingBroker != null) {
        print('❌ [BrokerSignup] 이미 가입된 등록번호');
        setState(() {
          _isValidating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미 가입된 등록번호입니다. 로그인해주세요.'),
              backgroundColor: AirbnbColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // API 검증
      print('🔍 [BrokerSignup] 국토부 API 검증 호출...');
      final result = await BrokerVerificationService.validateBroker(
        registrationNumber: _registrationNumberController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
      );
      print('🔍 [BrokerSignup] API 검증 결과: isValid=${result.isValid}, error=${result.errorMessage}');

      setState(() {
        _isValidating = false;
      });

      if (result.isValid && result.brokerInfo != null) {
        print('✅ [BrokerSignup] 검증 성공!');
        print('✅ [BrokerSignup] 사업자명: ${result.brokerInfo!.businessName}');
        print('✅ [BrokerSignup] 주소: ${result.brokerInfo!.address}');
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
              backgroundColor: AirbnbColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ [BrokerSignup] 검증 실패: ${result.errorMessage}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? '검증에 실패했습니다.'),
              backgroundColor: AirbnbColors.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [BrokerSignup] 검증 중 예외 발생: $e');
      setState(() {
        _isValidating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('검증 중 오류가 발생했습니다: $e'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

  /// 회원가입 제출
  Future<void> _submitSignup() async {
    print('📝 [BrokerSignup] ========== 회원가입 제출 시작 ==========');
    print('📝 [BrokerSignup] 이메일: ${_emailController.text.trim()}');
    print('📝 [BrokerSignup] 등록번호: ${_registrationNumberController.text.trim()}');
    print('📝 [BrokerSignup] 대표자명: ${_ownerNameController.text.trim()}');
    print('📝 [BrokerSignup] 사업자명: ${_businessNameController.text.trim()}');
    print('📝 [BrokerSignup] 전화번호: ${_phoneNumberController.text.trim()}');
    print('📝 [BrokerSignup] 검증 여부: ${_validatedBrokerInfo != null}');

    // 모든 에러 초기화
    setState(() {
      _emailError = null;
      _passwordError = null;
      _passwordConfirmError = null;
      _businessNameError = null;
      _registrationNumberError = null;
    });

    bool hasError = false;

    // 등록번호 검증 (필수)
    if (_registrationNumberController.text.trim().isEmpty) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 등록번호 미입력');
      setState(() => _registrationNumberError = '중개업 등록번호를 입력해주세요');
      hasError = true;
    }

    // 이메일 검증
    if (_emailController.text.isEmpty) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 이메일 미입력');
      setState(() => _emailError = '이메일을 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.isValidEmail(_emailController.text)) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 이메일 형식 오류');
      setState(() => _emailError = '올바른 이메일 형식이 아닙니다');
      hasError = true;
    }

    // 비밀번호 검증
    if (_passwordController.text.isEmpty) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 비밀번호 미입력');
      setState(() => _passwordError = '비밀번호를 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.isValidPasswordLength(_passwordController.text)) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 비밀번호 6자 미만');
      setState(() => _passwordError = '비밀번호는 6자 이상이어야 합니다');
      hasError = true;
    }

    // 비밀번호 확인 검증
    if (_passwordConfirmController.text.isEmpty) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 비밀번호 확인 미입력');
      setState(() => _passwordConfirmError = '비밀번호 확인을 입력해주세요');
      hasError = true;
    } else if (!ValidationUtils.doPasswordsMatch(_passwordController.text, _passwordConfirmController.text)) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 비밀번호 불일치');
      setState(() => _passwordConfirmError = '비밀번호가 일치하지 않습니다');
      hasError = true;
    }

    // 소유자 이름 검증
    if (_ownerNameController.text.isEmpty) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 소유자 이름 미입력');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('소유자 이름을 입력해주세요')),
      );
      hasError = true;
    }

    // 사무소명 검증
    if (_businessNameController.text.isEmpty) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 사무소명 미입력');
      setState(() => _businessNameError = '사무소명을 입력해주세요');
      hasError = true;
    }

    // 전화번호 검증
    if (_phoneNumberController.text.isEmpty) {
      print('❌ [BrokerSignup] 유효성 검사 실패: 전화번호 미입력');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전화번호를 입력해주세요')),
      );
      hasError = true;
    }

    if (hasError) {
      print('❌ [BrokerSignup] 유효성 검사 실패로 중단');
      return;
    }

    print('✅ [BrokerSignup] 유효성 검사 통과');

    if (!_formKey.currentState!.validate()) {
      print('❌ [BrokerSignup] Form 검증 실패');
      return;
    }

    print('✅ [BrokerSignup] Form 검증 통과');

    setState(() {
      _isLoading = true;
    });

    try {
      print('📝 [BrokerSignup] Firebase registerBroker 호출...');
      // Firebase에 저장
      // 검증 정보가 있으면 사용하고, 없으면 직접 입력한 값 사용
      final brokerInfo = {
        'brokerRegistrationNumber': _validatedBrokerInfo?.registrationNumber ?? _registrationNumberController.text.trim(),
        'ownerName': _validatedBrokerInfo?.ownerName ?? _ownerNameController.text.trim(),
        'businessName': _businessNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'systemRegNo': _validatedBrokerInfo?.systemRegNo,
        'address': _validatedBrokerInfo?.address,
        'verified': _validatedBrokerInfo != null, // 검증 여부
      };
      print('📝 [BrokerSignup] brokerInfo: $brokerInfo');

      final errorMessage = await _firebaseService.registerBroker(
        brokerId: _emailController.text.trim(),
        password: _passwordController.text,
        brokerInfo: brokerInfo,
      );

      print('📝 [BrokerSignup] registerBroker 결과: ${errorMessage ?? "성공"}');

      setState(() {
        _isLoading = false;
      });

      if (errorMessage == null && mounted) {
        print('✅ [BrokerSignup] 회원가입 완료!');
        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다!'),
            backgroundColor: AirbnbColors.success,
          ),
        );

        // 로그인 페이지로 이동 (성공 정보 전달)
        Navigator.pop(context, {
          'brokerId': _emailController.text.trim(),
          'password': _passwordController.text,
        });
      } else if (mounted) {
        print('❌ [BrokerSignup] 회원가입 실패: $errorMessage');
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage ?? '회원가입에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    } catch (e) {
      print('❌ [BrokerSignup] 예외 발생: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
    print('📝 [BrokerSignup] ========== 회원가입 제출 종료 ==========');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && FocusScope.of(context).hasFocus) {
          FocusScope.of(context).unfocus();
          await Future.delayed(const Duration(milliseconds: 100));
        }
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
      backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.primary,
        elevation: 0.5,
        title: const HomeLogoButton(
          fontSize: 18,
          color: AirbnbColors.primary,
        ),
      ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveHelper.getMaxWidth(context)),
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
                  color: AirbnbColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '중개업 등록번호를 입력하고 검증해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: AirbnbColors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // 등록번호 검증 섹션
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AirbnbColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _validatedBrokerInfo != null
                        ? AirbnbColors.success
                        : AirbnbColors.textSecondary.withValues(alpha: 0.3),
                    width: 2,
                  ),
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
                    Row(
                      children: [
                        Icon(
                          _validatedBrokerInfo != null
                              ? Icons.verified
                              : Icons.verified_user,
                          color: _validatedBrokerInfo != null
                              ? AirbnbColors.success
                              : AirbnbColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '등록번호 검증',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AirbnbColors.textPrimary,
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
                              color: AirbnbColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '검증 완료',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.success,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _registrationNumberController,
                      onChanged: (value) {
                        if (_registrationNumberError != null) {
                          setState(() => _registrationNumberError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: '중개업 등록번호 *',
                        hintText: '예: 11230202200144',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _registrationNumberError != null ? AirbnbColors.error : AirbnbColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _registrationNumberError != null ? AirbnbColors.error : AirbnbColors.primary,
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
                        errorText: _registrationNumberError,
                        errorStyle: const TextStyle(fontSize: 12),
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
                        fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
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
                          backgroundColor: AirbnbColors.primary,
                          foregroundColor: AirbnbColors.background,
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
                  color: AirbnbColors.background,
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
                        fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
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
                        fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
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
                    backgroundColor: AirbnbColors.primary,
                    foregroundColor: AirbnbColors.background,
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
        ),
      ),
    ),
    );
  }
}


