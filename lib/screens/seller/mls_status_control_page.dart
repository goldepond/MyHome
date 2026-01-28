import 'package:flutter/material.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../widgets/common_design_system.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// P4. 매물 상태 컨트롤 패널 (실시간 상태 동기화)
///
/// 매물 상태를 "단일 상태 머신"으로 통제하여 중개사 간 충돌을 방지합니다.
class MLSStatusControlPage extends StatefulWidget {
  final String propertyId;

  const MLSStatusControlPage({
    Key? key,
    required this.propertyId,
  }) : super(key: key);

  @override
  State<MLSStatusControlPage> createState() => _MLSStatusControlPageState();
}

class _MLSStatusControlPageState extends State<MLSStatusControlPage> {
  final _mlsService = MLSPropertyService();

  MLSProperty? _property;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProperty();
  }

  Future<void> _loadProperty() async {
    setState(() => _isLoading = true);
    try {
      final property = await _mlsService.getProperty(widget.propertyId);
      if (property != null && mounted) {
        setState(() => _property = property);
      }
    } catch (e) {
      Logger.error('Failed to load property', error: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_property == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('상태 관리')),
        body: const Center(child: Text('매물 정보를 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('매물 상태 관리'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCurrentStatusCard(),
          const SizedBox(height: 24),
          _buildStatusFlow(),
          const SizedBox(height: 24),
          _buildProgressSummary(),
          const SizedBox(height: 24),
          _buildStatusHistory(),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(_property!.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  _getStatusIcon(_property!.status),
                  size: 48,
                  color: _getStatusColor(_property!.status),
                ),
                const SizedBox(height: 12),
                Text(
                  _getStatusText(_property!.status),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(_property!.status),
                  ),
                ),
                if (_property!.statusChangedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_property!.statusChangedAt!.year}-${_property!.statusChangedAt!.month.toString().padLeft(2, '0')}-${_property!.statusChangedAt!.day.toString().padLeft(2, '0')} ${_property!.statusChangedAt!.hour.toString().padLeft(2, '0')}:${_property!.statusChangedAt!.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFlow() {
    final statuses = [
      PropertyStatus.active,
      PropertyStatus.inquiry,
      PropertyStatus.underOffer,
      PropertyStatus.depositTaken,
      PropertyStatus.sold,
    ];

    final currentIndex = statuses.indexOf(_property!.status);

    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상태 전환',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Column(
            children: List.generate(statuses.length, (index) {
              final status = statuses[index];
              final isCurrentOrPast = index <= currentIndex;
              final isCurrent = index == currentIndex;
              final canTransition = index == currentIndex + 1;

              return Column(
                children: [
                  _buildStatusFlowItem(
                    status: status,
                    isActive: isCurrentOrPast,
                    isCurrent: isCurrent,
                    canTransition: canTransition,
                  ),
                  if (index < statuses.length - 1)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      height: 30,
                      width: 2,
                      color: isCurrentOrPast
                        ? _getStatusColor(status)
                        : Colors.grey.shade300,
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFlowItem({
    required PropertyStatus status,
    required bool isActive,
    required bool isCurrent,
    required bool canTransition,
  }) {
    return GestureDetector(
      onTap: canTransition ? () => _showStatusTransitionDialog(status) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent
            ? _getStatusColor(status).withValues(alpha: 0.1)
            : Colors.transparent,
          border: Border.all(
            color: isActive
              ? _getStatusColor(status)
              : Colors.grey.shade300,
            width: isCurrent ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                  ? _getStatusColor(status)
                  : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(status),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Colors.black : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _getStatusDescription(status),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (canTransition)
              const Icon(Icons.arrow_forward, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummary() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '진행 현황',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          if (_property!.currentBrokerId != null)
            _buildProgressRow(
              '진행 중개사',
              _property!.currentBrokerId!,
              Icons.business,
            ),
          _buildProgressRow(
            '배포 중개사',
            '${_property!.targetBrokerIds.length}개',
            Icons.send,
          ),
          _buildProgressRow(
            '열람 중개사',
            '${_property!.brokerResponses.values.where((r) => r.hasViewed).length}개',
            Icons.check_circle,
          ),
          _buildProgressRow(
            '방문 예약',
            '${_property!.visitSchedules.where((s) => s.status == VisitStatus.approved).length}건',
            Icons.calendar_today,
          ),
          _buildProgressRow(
            '협의 이력',
            '${_property!.negotiations.length}건',
            Icons.handshake,
          ),
          if (_property!.depositTakenAt != null)
            _buildProgressRow(
              '가계약일',
              '${_property!.depositTakenAt!.year}-${_property!.depositTakenAt!.month.toString().padLeft(2, '0')}-${_property!.depositTakenAt!.day.toString().padLeft(2, '0')}',
              Icons.assignment_turned_in,
            ),
          if (_property!.soldAt != null)
            _buildProgressRow(
              '거래완료일',
              '${_property!.soldAt!.year}-${_property!.soldAt!.month.toString().padLeft(2, '0')}-${_property!.soldAt!.day.toString().padLeft(2, '0')}',
              Icons.done_all,
            ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHistory() {
    if (_property!.statusHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상태 변경 이력',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _property!.statusHistory.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final history = _property!.statusHistory[
                _property!.statusHistory.length - 1 - index
              ];
              return _buildHistoryItem(history);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(StatusHistory history) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getStatusColor(history.to).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(history.to),
                color: _getStatusColor(history.to),
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _getStatusText(history.from),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(history.to),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${history.changedAt.year}-${history.changedAt.month.toString().padLeft(2, '0')}-${history.changedAt.day.toString().padLeft(2, '0')} ${history.changedAt.hour.toString().padLeft(2, '0')}:${history.changedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (history.reason != null && history.reason!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  history.reason!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showStatusTransitionDialog(PropertyStatus newStatus) {
    final isDestructive = newStatus == PropertyStatus.depositTaken ||
                          newStatus == PropertyStatus.sold;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_getStatusText(newStatus)}(으)로 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_getStatusDescription(newStatus)),
            if (isDestructive) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning, color: AppColors.warning, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '이 상태로 변경하면 모든 중개사에게 광고 중단 알림이 발송되고, 안심번호가 비활성화됩니다.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(newStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppColors.warning : AppColors.primary,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(PropertyStatus newStatus) async {
    setState(() => _isLoading = true);

    try {
      await _mlsService.updateStatus(
        propertyId: widget.propertyId,
        newStatus: newStatus,
        changedBy: _property!.userId,
        reason: 'Status updated by seller',
      );

      await _loadProperty();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_getStatusText(newStatus)}(으)로 변경되었습니다')),
      );
    } catch (e) {
      Logger.error('Failed to update status', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상태 변경에 실패했습니다')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStatusText(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.draft:
        return '임시저장';
      case PropertyStatus.pending:
        return '검증 대기';
      case PropertyStatus.rejected:
        return '검증 거절';
      case PropertyStatus.active:
        return '활성';
      case PropertyStatus.inquiry:
        return '문의 중';
      case PropertyStatus.underOffer:
        return '협의 중';
      case PropertyStatus.depositTaken:
        return '가계약';
      case PropertyStatus.sold:
        return '거래완료';
      case PropertyStatus.cancelled:
        return '취소';
    }
  }

  String _getStatusDescription(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.draft:
        return '매물 정보를 작성 중입니다';
      case PropertyStatus.pending:
        return '매물 검증을 대기 중입니다';
      case PropertyStatus.rejected:
        return '매물 검증이 거절되었습니다';
      case PropertyStatus.active:
        return '중개사에게 배포되어 누구나 방문 유치 가능';
      case PropertyStatus.inquiry:
        return '특정 중개사와 방문 일정이 잡힘';
      case PropertyStatus.underOffer:
        return '특정 매수자와 가격/조건 협의 진행 중';
      case PropertyStatus.depositTaken:
        return '가계약금 입금 완료, 모든 광고 중단';
      case PropertyStatus.sold:
        return '본계약 체결, 거래 완료';
      case PropertyStatus.cancelled:
        return '매물 등록이 취소됨';
    }
  }

  Color _getStatusColor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.draft:
        return Colors.grey;
      case PropertyStatus.pending:
        return Colors.amber;
      case PropertyStatus.rejected:
        return AppColors.error;
      case PropertyStatus.active:
        return AppColors.success;
      case PropertyStatus.inquiry:
        return Colors.blue;
      case PropertyStatus.underOffer:
        return AppColors.warning;
      case PropertyStatus.depositTaken:
        return Colors.orange;
      case PropertyStatus.sold:
        return AppColors.primary;
      case PropertyStatus.cancelled:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.draft:
        return Icons.edit;
      case PropertyStatus.pending:
        return Icons.hourglass_empty;
      case PropertyStatus.rejected:
        return Icons.block;
      case PropertyStatus.active:
        return Icons.visibility;
      case PropertyStatus.inquiry:
        return Icons.question_answer;
      case PropertyStatus.underOffer:
        return Icons.handshake;
      case PropertyStatus.depositTaken:
        return Icons.assignment_turned_in;
      case PropertyStatus.sold:
        return Icons.done_all;
      case PropertyStatus.cancelled:
        return Icons.cancel;
    }
  }
}
