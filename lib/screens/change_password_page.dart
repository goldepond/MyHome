import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/utils/validation_utils.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_currentController.text.isEmpty ||
        _newController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('현재/새 비밀번호를 모두 입력해주세요.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    if (_newController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('새 비밀번호와 확인이 일치하지 않습니다.'),
          backgroundColor: AirbnbColors.error,
        ),
      );
      return;
    }

    if (!ValidationUtils.isValidPasswordLength(_newController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호는 6자 이상 입력해주세요.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final errorMessage = await _firebaseService.changePassword(
      _currentController.text,
      _newController.text,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('비밀번호가 변경되었습니다.'),
          backgroundColor: AirbnbColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AirbnbColors.error,
        ),
      );
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
        resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.primary,
        elevation: 2,
        title: Text(
          '비밀번호 변경',
          style: AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewInsets = MediaQuery.of(context).viewInsets;
              final actualHeight = constraints.maxHeight - viewInsets.bottom;
              
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: actualHeight - 48,
                  ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
              decoration: CommonDesignSystem.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '현재 비밀번호',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _currentController,
                    obscureText: _obscureCurrent,
                    decoration: InputDecoration(
                      hintText: '현재 비밀번호를 입력하세요',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCurrent = !_obscureCurrent;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md),
                  const Text(
                    '새 비밀번호',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newController,
                    obscureText: _obscureNew,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '6자 이상 (영문/숫자/특수문자 권장)',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNew = !_obscureNew;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                    ),
                  ),
                  if (_newController.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: ValidationUtils.getPasswordStrength(_newController.text) / 4,
                      backgroundColor: AirbnbColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _strengthColor(ValidationUtils.getPasswordStrength(_newController.text)),
                      ),
                      minHeight: 4,
                    ),
                  ],
                  SizedBox(height: AppSpacing.md),
                  const Text(
                    '새 비밀번호 확인',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: '새 비밀번호를 다시 입력하세요',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirm = !_obscureConfirm;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                        foregroundColor: AirbnbColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                              ),
                            )
                          : const Text(
                              '비밀번호 변경',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
                  ),
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }

  Color _strengthColor(int strength) {
    if (strength <= 1) return AirbnbColors.error;
    if (strength == 2) return AirbnbColors.warning;
    if (strength == 3) return AirbnbColors.primary;
    return AirbnbColors.success;
  }
}



