import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/broker_stats.dart';

/// 판매자에게 보여줄 중개사 지표 카드
///
/// 방문 요청 승인 시 중개사의 성과 지표를 표시합니다.
/// 행동 데이터 기반으로 조작이 불가능한 객관적 지표만 표시합니다.
class BrokerMetricsCard extends StatelessWidget {
  final BrokerMetricsSummary metrics;
  final bool compact;

  const BrokerMetricsCard({
    required this.metrics,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactView();
    }
    return _buildFullView();
  }

  Widget _buildCompactView() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_rounded,
                size: 16,
                color: AirbnbColors.textSecondary,
              ),
              const SizedBox(width: 6),
              const Text(
                '중개사 지표',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AirbnbColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (!metrics.hasEnoughData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '데이터 부족',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCompactChip(
                '방문성사',
                metrics.visitSuccessRateGrade,
                _getGradeColor(metrics.visitSuccessRateGrade),
              ),
              _buildCompactChip(
                '노쇼',
                metrics.noShowRisk,
                _getRiskColor(metrics.noShowRisk),
              ),
              _buildCompactChip(
                '응답',
                metrics.responseSpeedGrade,
                _getGradeColor(metrics.responseSpeedGrade),
              ),
              _buildCompactChip(
                '거래',
                '${metrics.completedDeals}건',
                AirbnbColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              color: AirbnbColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullView() {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AirbnbColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AirbnbColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metrics.brokerName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AirbnbColors.textPrimary,
                      ),
                    ),
                    if (metrics.brokerCompany != null)
                      Text(
                        metrics.brokerCompany!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (!metrics.hasEnoughData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        '데이터 부족',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // 지표 그리드
          _buildMetricRow(
            icon: Icons.check_circle_outline,
            label: '방문 성사율',
            value: '${(metrics.visitSuccessRate * 100).toStringAsFixed(0)}%',
            grade: metrics.visitSuccessRateGrade,
            gradeColor: _getGradeColor(metrics.visitSuccessRateGrade),
            tooltip: '요청한 방문 중 실제 성사된 비율',
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            icon: Icons.person_off_outlined,
            label: '노쇼 위험도',
            value: '${(metrics.noShowRate * 100).toStringAsFixed(1)}%',
            grade: metrics.noShowRisk,
            gradeColor: _getRiskColor(metrics.noShowRisk),
            tooltip: '승인 후 미방문 비율',
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            icon: Icons.timer_outlined,
            label: '평균 응답 속도',
            value: metrics.avgResponseTimeFormatted,
            grade: metrics.responseSpeedGrade,
            gradeColor: _getGradeColor(metrics.responseSpeedGrade),
            tooltip: '요청 후 판매자 응답까지 걸리는 시간',
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            icon: Icons.price_check,
            label: '제안가 정직도',
            value: '${(metrics.avgPriceDeviation * 100).toStringAsFixed(0)}%',
            grade: metrics.priceHonesty,
            gradeColor: _getPriceHonestyColor(metrics.priceHonesty),
            tooltip: '제안가 대비 최종 거래가 비율 (높을수록 정직)',
          ),
          const SizedBox(height: 12),
          _buildMetricRow(
            icon: Icons.handshake_outlined,
            label: '거래 완료',
            value: '${metrics.completedDeals}건',
            grade: null,
            gradeColor: AirbnbColors.primary,
            tooltip: '총 완료된 거래 수',
          ),

          if (!metrics.hasEnoughData) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '이 중개사는 아직 충분한 거래 데이터가 없습니다. 지표가 정확하지 않을 수 있습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    required String? grade,
    required Color gradeColor,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AirbnbColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AirbnbColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AirbnbColors.textPrimary,
            ),
          ),
          if (grade != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                grade,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: gradeColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case '매우 높음':
      case '매우 빠름':
        return Colors.green;
      case '높음':
      case '빠름':
        return Colors.teal;
      case '보통':
        return Colors.orange;
      case '낮음':
      case '느림':
        return Colors.red;
      default:
        return AirbnbColors.textSecondary;
    }
  }

  Color _getRiskColor(String risk) {
    switch (risk) {
      case '매우 낮음':
        return Colors.green;
      case '낮음':
        return Colors.teal;
      case '보통':
        return Colors.orange;
      case '높음':
        return Colors.red;
      default:
        return AirbnbColors.textSecondary;
    }
  }

  Color _getPriceHonestyColor(String honesty) {
    switch (honesty) {
      case '매우 정직':
        return Colors.green;
      case '정직':
        return Colors.teal;
      case '보통':
        return Colors.orange;
      case '저가 압박 경향':
        return Colors.red;
      default:
        return AirbnbColors.textSecondary;
    }
  }
}

/// 중개사 지표 로딩 위젯
class BrokerMetricsLoader extends StatelessWidget {
  final String brokerId;
  final Future<BrokerMetricsSummary?> Function(String) loader;
  final bool compact;

  const BrokerMetricsLoader({
    required this.brokerId,
    required this.loader,
    this.compact = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BrokerMetricsSummary?>(
      future: loader(brokerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AirbnbColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AirbnbColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, size: 16, color: AirbnbColors.textLight),
                SizedBox(width: 8),
                Text(
                  '아직 거래 이력이 없습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return BrokerMetricsCard(
          metrics: snapshot.data!,
          compact: compact,
        );
      },
    );
  }
}
