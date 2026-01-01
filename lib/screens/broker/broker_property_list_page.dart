import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/property.dart';
import 'package:property/screens/broker/property_edit_form_page.dart';
import 'package:property/screens/broker/broker_property_detail_page.dart';
import 'package:intl/intl.dart';

/// 공인중개사가 등록한 매물 목록 페이지
class BrokerPropertyListPage extends StatefulWidget {
  final String brokerId;
  final Map<String, dynamic> brokerData;

  const BrokerPropertyListPage({
    required this.brokerId,
    required this.brokerData,
    super.key,
  });

  @override
  State<BrokerPropertyListPage> createState() => _BrokerPropertyListPageState();
}

class _BrokerPropertyListPageState extends State<BrokerPropertyListPage> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    // 반응형 레이아웃
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1400.0 : screenWidth;
    final horizontalPadding = isWeb ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        title: const Text('내가 등록한 매물'),
        backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
        foregroundColor: AirbnbColors.textPrimary,
      ),
      body: StreamBuilder<List<Property>>(
        stream: _firebaseService.getPropertiesByBrokerId(widget.brokerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AirbnbColors.error),
                  const SizedBox(height: 16),
                  const Text(
                    '매물 목록을 불러오는 중 오류가 발생했습니다.',
                    style: TextStyle(color: AirbnbColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final properties = snapshot.data ?? [];

          if (properties.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_outlined, size: 64, color: AirbnbColors.textLight),
                  SizedBox(height: 16),
                  Text(
                    '등록한 매물이 없습니다.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
              child: ListView.builder(
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final property = properties[index];
                  return _buildPropertyCard(property);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    final priceFormat = NumberFormat('#,###');

    // 가격 포맷팅
    String priceText = '';
    if (property.transactionType == '매매') {
      if (property.price >= 100000000) {
        priceText = '${(property.price / 100000000).toStringAsFixed(1)}억원';
      } else if (property.price >= 10000) {
        priceText = '${(property.price / 10000).toStringAsFixed(0)}만원';
      } else {
        priceText = '${priceFormat.format(property.price)}원';
      }
    } else if (property.transactionType == '전세') {
      if (property.price >= 100000000) {
        priceText = '전세 ${(property.price / 100000000).toStringAsFixed(1)}억원';
      } else if (property.price >= 10000) {
        priceText = '전세 ${(property.price / 10000).toStringAsFixed(0)}만원';
      } else {
        priceText = '전세 ${priceFormat.format(property.price)}원';
      }
    } else if (property.transactionType == '월세') {
      priceText = '월세 (상세정보 참조)';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 (주소 + 버튼들)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    property.address,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BrokerPropertyDetailPage(
                              property: property,
                              brokerData: widget.brokerData,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('상세보기'),
                      style: TextButton.styleFrom(
                        foregroundColor: AirbnbColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PropertyEditFormPage(
                              property: property,
                              brokerData: widget.brokerData,
                            ),
                          ),
                        );
                      },
                      tooltip: '수정',
                      color: AirbnbColors.primary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 가격 및 거래 유형
            Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AirbnbColors.getTransactionTypeColor(property.transactionType).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      property.transactionType,
                      style: TextStyle(
                        fontSize: 12,
                        color: AirbnbColors.getTransactionTypeColor(property.transactionType),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    priceText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AirbnbColors.textPrimary,
                    ),
                  ),
                ],
              ),
            if (property.area != null) ...[
              const SizedBox(height: 8),
              Text(
                '면적: ${property.area!.toStringAsFixed(2)}㎡',
                style: const TextStyle(
                  fontSize: 14,
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            // 상태 및 등록일
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(property.contractStatus).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      property.contractStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(property.contractStatus),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '등록일: ${dateFormat.format(property.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AirbnbColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '대기':
        return AirbnbColors.primary;
      case '진행중':
        return AirbnbColors.warning;
      case '완료':
        return AirbnbColors.success;
      case '취소':
        return AirbnbColors.error;
      default:
        return AirbnbColors.textSecondary;
    }
  }
}

