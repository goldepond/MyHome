import 'package:flutter/material.dart';
import '../../api_request/mls_property_service.dart';
import '../../models/mls_property.dart';
import '../../constants/app_constants.dart';

/// 관리자 매물 검증 페이지
///
/// 매도인이 등록한 매물을 검토하고 승인/거절합니다.
/// 등기 확인 후 수동으로 검증 상태를 부여합니다.
class AdminPropertyVerificationPage extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminPropertyVerificationPage({
    required this.userId,
    required this.userName,
    super.key,
  });

  @override
  State<AdminPropertyVerificationPage> createState() => _AdminPropertyVerificationPageState();
}

class _AdminPropertyVerificationPageState extends State<AdminPropertyVerificationPage> {
  final _mlsService = MLSPropertyService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '매물 검증',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '등기 확인 후 매물을 승인하거나 거절합니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 검증 대기 매물 목록
          Expanded(
            child: StreamBuilder<List<MLSProperty>>(
              stream: _mlsService.getPendingProperties(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('오류: ${snapshot.error}'),
                  );
                }

                final properties = snapshot.data ?? [];

                if (properties.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    return _buildPropertyCard(properties[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AirbnbColors.textLight,
          ),
          const SizedBox(height: 16),
          const Text(
            '검증 대기 중인 매물이 없습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AirbnbColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '모든 매물이 검증되었습니다',
            style: TextStyle(
              fontSize: 14,
              color: AirbnbColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(MLSProperty property) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
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
          // 이미지 (있는 경우)
          if (property.thumbnailUrl != null || property.imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  property.thumbnailUrl ?? property.imageUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _a, _b) => Container(
                    color: AirbnbColors.surface,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상태 뱃지
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AirbnbColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending, size: 14, color: AirbnbColors.warning),
                          SizedBox(width: 4),
                          Text(
                            '검증 대기',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AirbnbColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(property.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AirbnbColors.textLight,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 주소
                Text(
                  property.roadAddress,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AirbnbColors.textPrimary,
                  ),
                ),
                if (property.buildingName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    property.buildingName,
                    style: TextStyle(
                      fontSize: 14,
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 매물 정보
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.attach_money, _formatPrice(property.desiredPrice)),
                    if (property.propertyType != null)
                      _buildInfoChip(Icons.home, property.propertyType!),
                    if (property.area != null)
                      _buildInfoChip(Icons.square_foot, '${property.area!.toStringAsFixed(1)}㎡'),
                    if (property.floor != null)
                      _buildInfoChip(Icons.layers, '${property.floor}층'),
                  ],
                ),

                const SizedBox(height: 16),

                // 매도인 정보
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: AirbnbColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '매도인: ${property.userName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 액션 버튼
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(property),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('거절'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.error,
                          side: const BorderSide(color: AirbnbColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _approveProperty(property),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('검증 승인'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AirbnbColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AirbnbColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: AirbnbColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _approveProperty(MLSProperty property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('매물 승인'),
        content: Text('${property.roadAddress}\n\n이 매물을 검증 승인하시겠습니까?\n승인 후 중개사에게 배포됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.primary,
            ),
            child: const Text('승인'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _mlsService.approveProperty(
          propertyId: property.id,
          adminId: widget.userId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('매물이 승인되었습니다'),
              backgroundColor: AirbnbColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('승인 실패: $e'),
              backgroundColor: AirbnbColors.error,
            ),
          );
        }
      }
    }
  }

  /// 거절 사유 템플릿 목록
  static const List<String> _rejectionTemplates = [
    '주소 불일치',
    '서류 불충분',
    '중복 매물',
    '등기 정보 불일치',
    '연락처 확인 불가',
    '매물 정보 부정확',
  ];

  Future<void> _showRejectDialog(MLSProperty property) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('매물 거절'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.roadAddress,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // 거절 사유 템플릿 칩
                const Text(
                  '빠른 선택',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _rejectionTemplates.map((template) {
                    final isSelected = reasonController.text == template;
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          reasonController.text = template;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AirbnbColors.error.withValues(alpha: 0.15)
                              : AirbnbColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AirbnbColors.error
                                : AirbnbColors.border,
                          ),
                        ),
                        child: Text(
                          template,
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected
                                ? AirbnbColors.error
                                : AirbnbColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    labelText: '거절 사유',
                    hintText: '위에서 선택하거나 직접 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('거절 사유를 입력해주세요')),
                  );
                  return;
                }
                Navigator.pop(context, reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.error,
              ),
              child: const Text('거절'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await _mlsService.rejectProperty(
          propertyId: property.id,
          adminId: widget.userId,
          reason: result,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('매물이 거절되었습니다'),
              backgroundColor: AirbnbColors.warning,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('거절 실패: $e'),
              backgroundColor: AirbnbColors.error,
            ),
          );
        }
      }
    }
  }

  String _formatPrice(double price) {
    final priceInMan = price.round();
    if (priceInMan >= 10000) {
      final uk = priceInMan ~/ 10000;
      final remainder = priceInMan % 10000;
      if (remainder > 0) return '$uk억 $remainder만원';
      return '$uk억';
    }
    return '$priceInMan만원';
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
