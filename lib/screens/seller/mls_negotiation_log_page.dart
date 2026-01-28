import 'package:flutter/material.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../widgets/common_design_system.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// P5. 네고 피드백 로그 (협의 기록 & 종결)
///
/// 중개사/매수자 반응, 제안 조건을 기록하고 비교합니다.
/// 거래 완료를 선언하면 자동 클로징(알림/차단/회수)을 수행합니다.
class MLSNegotiationLogPage extends StatefulWidget {
  final String propertyId;

  const MLSNegotiationLogPage({
    Key? key,
    required this.propertyId,
  }) : super(key: key);

  @override
  State<MLSNegotiationLogPage> createState() => _MLSNegotiationLogPageState();
}

class _MLSNegotiationLogPageState extends State<MLSNegotiationLogPage> {
  final _mlsService = MLSPropertyService();

  MLSProperty? _property;
  bool _isLoading = false;
  String? _selectedBrokerId;

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
        appBar: AppBar(title: const Text('협의 기록')),
        body: const Center(child: Text('매물 정보를 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('협의 기록'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPropertySummary(),
          const SizedBox(height: 24),
          _buildVisitFeedbackSection(),
          const SizedBox(height: 24),
          _buildNegotiationSection(),
          const SizedBox(height: 24),
          if (_property!.negotiations.isNotEmpty)
            _buildComparisonSection(),
          const SizedBox(height: 24),
          _buildTransactionSection(),
        ],
      ),
    );
  }

  Widget _buildPropertySummary() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매물 정보',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          _buildInfoRow('주소', _property!.roadAddress),
          _buildInfoRow('희망가', '${_property!.desiredPrice.toStringAsFixed(0)} 만원'),
          _buildInfoRow('상태', _getStatusText(_property!.status)),
          if (_property!.currentBrokerId != null)
            _buildInfoRow('진행 중개사', _property!.currentBrokerId!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  Widget _buildVisitFeedbackSection() {
    final completedVisits = _property!.visitSchedules
      .where((s) => s.status == VisitStatus.completed && s.feedback != null)
      .toList();

    if (completedVisits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '방문 피드백',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completedVisits.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final visit = completedVisits[index];
              return _buildVisitFeedbackCard(visit);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisitFeedbackCard(VisitSchedule visit) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  visit.brokerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${visit.scheduledAt.month}/${visit.scheduledAt.day}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              visit.feedback ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNegotiationSection() {
    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '협의 이력',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showAddNegotiationDialog,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('추가'),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_property!.negotiations.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '협의 이력이 없습니다',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _property!.negotiations.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final negotiation = _property!.negotiations[
                  _property!.negotiations.length - 1 - index
                ];
                return _buildNegotiationCard(negotiation);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNegotiationCard(NegotiationLog negotiation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  negotiation.brokerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${negotiation.createdAt.month}/${negotiation.createdAt.day}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (negotiation.proposedPrice != null)
            _buildNegotiationRow(
              '제안 가격',
              '${negotiation.proposedPrice!.toStringAsFixed(0)} 만원',
              Icons.attach_money,
            ),
          if (negotiation.proposedMoveInDate != null)
            _buildNegotiationRow(
              '이사 희망일',
              '${negotiation.proposedMoveInDate!.year}-${negotiation.proposedMoveInDate!.month.toString().padLeft(2, '0')}-${negotiation.proposedMoveInDate!.day.toString().padLeft(2, '0')}',
              Icons.calendar_today,
            ),
          if (negotiation.conditions != null && negotiation.conditions!.isNotEmpty)
            _buildNegotiationRow(
              '조건',
              negotiation.conditions!,
              Icons.description,
            ),
          if (negotiation.buyerFeedback != null && negotiation.buyerFeedback!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.comment, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        '매수자 반응',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    negotiation.buyerFeedback!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNegotiationRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonSection() {
    final negotiations = _property!.negotiations;
    final priceProposals = negotiations
      .where((n) => n.proposedPrice != null)
      .toList();

    if (priceProposals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '조건 비교',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(3),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('중개사', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('제안가', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('조건', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              ...priceProposals.map((negotiation) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(negotiation.brokerName),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${negotiation.proposedPrice!.toStringAsFixed(0)}만원',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(negotiation.conditions ?? '-'),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSection() {
    final canComplete = _property!.status == PropertyStatus.underOffer ||
                        _property!.status == PropertyStatus.depositTaken;

    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '거래 종료',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          if (_property!.status == PropertyStatus.sold) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 12),
                      Text(
                        '거래가 완료되었습니다',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  if (_property!.finalPrice != null) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow('최종 거래가', '${_property!.finalPrice!.toStringAsFixed(0)} 만원'),
                  ],
                  if (_property!.finalBrokerId != null)
                    _buildInfoRow('중개사', _property!.finalBrokerId!),
                ],
              ),
            ),
          ] else ...[
            const Text(
              '협의가 완료되면 거래 완료를 선언해주세요.\n모든 중개사에게 자동으로 종료 알림이 발송됩니다.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: canComplete ? _showCompleteTransactionDialog : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: const Text('거래 완료 선언', style: TextStyle(fontSize: 18)),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddNegotiationDialog() {
    final priceController = TextEditingController();
    final conditionsController = TextEditingController();
    final feedbackController = TextEditingController();
    DateTime? moveInDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('협의 내용 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '중개사 선택',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedBrokerId,
                  items: _property!.brokerResponses.values
                    .where((r) => r.hasViewed)
                    .map((r) => DropdownMenuItem(
                      value: r.brokerId,
                      child: Text(r.brokerName),
                    ))
                    .toList(),
                  onChanged: (value) => setState(() => _selectedBrokerId = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: '제안 가격 (만원)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(moveInDate == null
                    ? '이사 희망일 선택'
                    : '${moveInDate!.year}-${moveInDate!.month.toString().padLeft(2, '0')}-${moveInDate!.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => moveInDate = date);
                    }
                  },
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: conditionsController,
                  decoration: const InputDecoration(
                    labelText: '조건',
                    border: OutlineInputBorder(),
                    hintText: '예: 잔금 2개월 후, 옵션 포함',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: feedbackController,
                  decoration: const InputDecoration(
                    labelText: '매수자 반응',
                    border: OutlineInputBorder(),
                    hintText: '예: 가격이 조금 비싸다고 함',
                  ),
                  maxLines: 3,
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
                if (_selectedBrokerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('중개사를 선택해주세요')),
                  );
                  return;
                }

                Navigator.pop(context);
                _addNegotiation(
                  brokerId: _selectedBrokerId!,
                  brokerName: _property!.brokerResponses[_selectedBrokerId]!.brokerName,
                  proposedPrice: priceController.text.isNotEmpty ? double.parse(priceController.text) : null,
                  proposedMoveInDate: moveInDate,
                  conditions: conditionsController.text.isNotEmpty ? conditionsController.text : null,
                  buyerFeedback: feedbackController.text.isNotEmpty ? feedbackController.text : null,
                );
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNegotiation({
    required String brokerId,
    required String brokerName,
    double? proposedPrice,
    DateTime? proposedMoveInDate,
    String? conditions,
    String? buyerFeedback,
  }) async {
    try {
      final log = NegotiationLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        brokerId: brokerId,
        brokerName: brokerName,
        proposedPrice: proposedPrice,
        proposedMoveInDate: proposedMoveInDate,
        conditions: conditions,
        buyerFeedback: buyerFeedback,
        createdAt: DateTime.now(),
      );

      await _mlsService.addNegotiationLog(
        propertyId: widget.propertyId,
        log: log,
      );

      await _loadProperty();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('협의 내용이 추가되었습니다')),
      );
    } catch (e) {
      Logger.error('Failed to add negotiation log', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('추가에 실패했습니다')),
      );
    }
  }

  void _showCompleteTransactionDialog() {
    final priceController = TextEditingController(
      text: _property!.negotiations.isNotEmpty &&
            _property!.negotiations.last.proposedPrice != null
        ? _property!.negotiations.last.proposedPrice!.toStringAsFixed(0)
        : _property!.desiredPrice.toStringAsFixed(0),
    );
    String? selectedBrokerId = _property!.currentBrokerId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('거래 완료'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: '최종 거래 중개사',
                  border: OutlineInputBorder(),
                ),
                value: selectedBrokerId,
                items: _property!.brokerResponses.values
                  .where((r) => r.hasViewed)
                  .map((r) => DropdownMenuItem(
                    value: r.brokerId,
                    child: Text(r.brokerName),
                  ))
                  .toList(),
                onChanged: (value) => setState(() => selectedBrokerId = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: '최종 거래가 (만원)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '거래 완료를 선언하면:\n• 모든 중개사에게 종료 알림 발송\n• 안심번호 비활성화\n• 매물 상태가 "거래완료"로 변경됩니다',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedBrokerId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('중개사를 선택해주세요')),
                  );
                  return;
                }

                Navigator.pop(context);
                _completeTransaction(
                  finalBrokerId: selectedBrokerId!,
                  finalPrice: double.parse(priceController.text),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('거래 완료'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeTransaction({
    required String finalBrokerId,
    required double finalPrice,
  }) async {
    try {
      await _mlsService.completeTransaction(
        propertyId: widget.propertyId,
        finalBrokerId: finalBrokerId,
        finalPrice: finalPrice,
      );

      await _loadProperty();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거래가 완료되었습니다')),
      );
    } catch (e) {
      Logger.error('Failed to complete transaction', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('거래 완료 처리에 실패했습니다')),
      );
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
}
