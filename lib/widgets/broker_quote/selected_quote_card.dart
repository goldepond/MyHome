import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/utils/call_utils.dart';

class SelectedQuoteCard extends StatelessWidget {
  final QuoteRequest quote;
  final bool isSubmitting;
  final bool isRegistered;
  final VoidCallback onRegisterPressed;

  const SelectedQuoteCard({
    super.key,
    required this.quote,
    required this.isSubmitting,
    required this.isRegistered,
    required this.onRegisterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.kSuccess.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.kSuccess.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.check_circle, color: AppColors.kSuccess, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '고객님이 제안해주신 상담을 선택해주셨어요! 감사합니다 🙏',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.kSuccess,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 16),
              _buildContactRow(
                icon: Icons.person,
                label: '고객님',
                value: quote.userName,
              ),
              const SizedBox(height: 12),
              _buildPhoneRow(
                phone: quote.userPhone ?? '미등록',
                requestId: quote.id,
              ),
              const SizedBox(height: 12),
              _buildContactRow(
                icon: Icons.email,
                label: '이메일',
                value: quote.userEmail,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (isSubmitting || isRegistered) ? null : onRegisterPressed,
                  icon: isSubmitting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(isRegistered ? Icons.check : Icons.upload_file),
                  label: Text(
                    isSubmitting 
                        ? '등록 중...' 
                        : (isRegistered ? '매물 등록 완료' : '집 구하기에 매물 등록하기')
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRegistered ? Colors.grey : AppColors.kPrimary,
                    foregroundColor: Colors.white,
                    elevation: isRegistered ? 0 : 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  isRegistered 
                      ? '이미 매물로 등록되었습니다.' 
                      : '매물 등록 시 집 구하기 목록에 즉시 노출됩니다.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPhoneRow({
    required String phone,
    required String requestId,
  }) {
    return Row(
      children: [
        Icon(Icons.phone, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '휴대폰',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.kPrimary,
                ),
              ),
              if (phone != '미등록' && phone != '-') ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: () => CallUtils.makeCall(phone, relatedId: requestId),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('전화걸기', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String? value,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value ?? '-',
            style: TextStyle(
              fontSize: isHighlight ? 18 : 15,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.kPrimary : const Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }
}

