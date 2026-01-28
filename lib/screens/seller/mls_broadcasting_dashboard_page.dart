import 'package:flutter/material.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../api_request/broker_service.dart';
import '../../widgets/common_design_system.dart';
import '../../constants/app_constants.dart';
import '../../utils/logger.dart';

/// P2. 배포 대시보드 (원클릭 배포 & 접수 현황)
///
/// 지정 지역(동 단위 이상)으로 매물 정보를 한 번에 배포하고,
/// 중개사 수락/거절/열람 현황을 실시간으로 확인합니다.
class MLSBroadcastingDashboardPage extends StatefulWidget {
  final String propertyId;

  const MLSBroadcastingDashboardPage({
    Key? key,
    required this.propertyId,
  }) : super(key: key);

  @override
  State<MLSBroadcastingDashboardPage> createState() => _MLSBroadcastingDashboardPageState();
}

class _MLSBroadcastingDashboardPageState extends State<MLSBroadcastingDashboardPage> {
  final _mlsService = MLSPropertyService();

  MLSProperty? _property;
  List<Broker> _nearbyBrokers = [];
  bool _isLoading = false;
  bool _isBroadcasting = false;
  int _searchRadius = 1; // km

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
        await _searchNearbyBrokers();
      }
    } catch (e) {
      Logger.error('Failed to load property', error: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchNearbyBrokers() async {
    if (_property == null || _property!.latitude == null || _property!.longitude == null) {
      return;
    }

    try {
      final result = await BrokerService.searchNearbyBrokers(
        latitude: _property!.latitude!,
        longitude: _property!.longitude!,
        radiusMeters: _searchRadius * 1000,
      );

      if (mounted) {
        setState(() {
          _nearbyBrokers = result.brokers;
          _searchRadius = (result.radiusMetersUsed / 1000).round();
        });
      }
    } catch (e) {
      Logger.error('Failed to search nearby brokers', error: e);
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
        appBar: AppBar(title: const Text('매물 배포')),
        body: const Center(child: Text('매물 정보를 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('매물 배포 현황'),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPropertySummary(),
          const SizedBox(height: 24),
          _buildBroadcastSection(),
          const SizedBox(height: 24),
          _buildBrokerResponsesSection(),
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
          _buildInfoRow('배포 지역', '${_property!.district} ${_property!.region}'),
          if (_property!.broadcastedAt != null)
            _buildInfoRow(
              '배포 시각',
              '${_property!.broadcastedAt!.year}-${_property!.broadcastedAt!.month.toString().padLeft(2, '0')}-${_property!.broadcastedAt!.day.toString().padLeft(2, '0')} ${_property!.broadcastedAt!.hour.toString().padLeft(2, '0')}:${_property!.broadcastedAt!.minute.toString().padLeft(2, '0')}',
            ),
          _buildInfoRow('상태', _getStatusText(_property!.status)),
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
            width: 80,
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

  Widget _buildBroadcastSection() {
    final isBroadcasted = _property!.broadcastedAt != null;

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
                '배포 대상',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '반경 ${_searchRadius}km',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_nearbyBrokers.isEmpty)
            const Text('주변에 등록된 중개사가 없습니다')
          else
            Text(
              '${_nearbyBrokers.length}개의 중개사가 검색되었습니다',
              style: const TextStyle(fontSize: 16),
            ),
          const SizedBox(height: 16),
          if (!isBroadcasted)
            ElevatedButton(
              onPressed: _isBroadcasting ? null : _broadcastProperty,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _isBroadcasting
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('중개사에게 배포하기', style: TextStyle(fontSize: 18)),
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: AppColors.success),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '배포 완료',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isBroadcasting ? null : _broadcastProperty,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: _isBroadcasting
                    ? const CircularProgressIndicator()
                    : const Text('재배포'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBrokerResponsesSection() {
    if (_property!.brokerResponses.isEmpty) {
      return const SizedBox.shrink();
    }

    final responses = _property!.brokerResponses.values.toList();
    final receivedCount = responses.where((r) => r.stage == BrokerStage.received).length;
    final viewedCount = responses.where((r) => r.stage == BrokerStage.viewed).length;
    final requestedCount = responses.where((r) => r.stage == BrokerStage.requested).length;
    final approvedCount = responses.where((r) => r.stage == BrokerStage.approved || r.stage == BrokerStage.completed).length;

    return Container(
      decoration: CommonDesignSystem.cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '중개사 응답 현황',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusChip('수신', receivedCount, Colors.grey),
              _buildStatusChip('열람', viewedCount, Colors.blue),
              _buildStatusChip('요청', requestedCount, Colors.orange),
              _buildStatusChip('승인', approvedCount, AppColors.success),
            ],
          ),
          const Divider(height: 32),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: responses.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final response = responses[index];
              return _buildBrokerResponseCard(response);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBrokerResponseCard(BrokerResponse response) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  response.brokerName.isNotEmpty ? response.brokerName : '중개사',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStageStatusText(response.stage),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getStageStatusColor(response.stage),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            _getStageStatusIcon(response.stage),
            color: _getStageStatusColor(response.stage),
          ),
        ],
      ),
    );
  }

  Future<void> _broadcastProperty() async {
    if (_nearbyBrokers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배포할 중개사가 없습니다')),
      );
      return;
    }

    setState(() => _isBroadcasting = true);

    try {
      final brokerIds = _nearbyBrokers.map((b) => b.registrationNumber).toList();
      await _mlsService.broadcastProperty(
        propertyId: widget.propertyId,
        brokerIds: brokerIds,
      );

      await _loadProperty();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${brokerIds.length}개 중개사에게 배포되었습니다')),
      );
    } catch (e) {
      Logger.error('Failed to broadcast property', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배포에 실패했습니다')),
      );
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
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

  String _getStageStatusText(BrokerStage stage) {
    switch (stage) {
      case BrokerStage.received:
        return '수신됨';
      case BrokerStage.viewed:
        return '열람함';
      case BrokerStage.requested:
        return '방문 요청';
      case BrokerStage.approved:
        return '승인됨';
      case BrokerStage.completed:
        return '완료';
    }
  }

  Color _getStageStatusColor(BrokerStage stage) {
    switch (stage) {
      case BrokerStage.received:
        return Colors.grey;
      case BrokerStage.viewed:
        return Colors.blue;
      case BrokerStage.requested:
        return Colors.orange;
      case BrokerStage.approved:
        return AppColors.success;
      case BrokerStage.completed:
        return Colors.purple;
    }
  }

  IconData _getStageStatusIcon(BrokerStage stage) {
    switch (stage) {
      case BrokerStage.received:
        return Icons.notifications_outlined;
      case BrokerStage.viewed:
        return Icons.visibility;
      case BrokerStage.requested:
        return Icons.schedule;
      case BrokerStage.approved:
        return Icons.check_circle;
      case BrokerStage.completed:
        return Icons.done_all;
    }
  }
}
