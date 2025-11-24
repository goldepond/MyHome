import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';
import 'package:property/constants/status_constants.dart';
import 'package:intl/intl.dart';

/// 내집구매 상세보기 페이지
/// 구매자가 매물의 모든 정보를 확인할 수 있는 페이지
class BuyerPropertyDetailPage extends StatelessWidget {
  final Property property;
  final String? currentUserId;
  final String? currentUserName;

  const BuyerPropertyDetailPage({
    required this.property,
    this.currentUserId,
    this.currentUserName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 반응형 레이아웃
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1400.0 : screenWidth;
    final horizontalPadding = isWeb ? 24.0 : 16.0;

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

    // 이미지 URL 파싱
    List<String> imageUrls = [];
    if (property.propertyImages != null && property.propertyImages!.isNotEmpty) {
      try {
        final decoded = jsonDecode(property.propertyImages!) as List;
        imageUrls = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        // 파싱 실패 시 무시
      }
    }

    // 라이프사이클 상태
    final lifecycle = PropertyLifecycleStatus.fromProperty(property);
    final lifecycleColor = PropertyLifecycleStatus.color(lifecycle);
    final lifecycleLabel = PropertyLifecycleStatus.label(lifecycle);

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        title: const Text('매물 상세보기'),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 갤러리
                if (imageUrls.isNotEmpty) ...[
                  _buildImageGallery(imageUrls),
                  const SizedBox(height: 24),
                ],

                // 기본 정보 카드
                _buildInfoCard(
                  title: '기본 정보',
                  icon: Icons.info_outline,
                  color: Colors.blue,
                  children: [
                    _buildInfoRow('주소', property.address),
                    if (property.addressCity != null && property.addressCity!.isNotEmpty)
                      _buildInfoRow('시/도', property.addressCity!),
                    _buildInfoRow('거래 유형', property.transactionType),
                    _buildInfoRow('가격', priceText),
                    if (property.area != null)
                      _buildInfoRow('면적', '${property.area!.toStringAsFixed(2)}㎡'),
                    _buildInfoRow('계약 상태', property.contractStatus),
                    _buildInfoRow('매물 상태', lifecycleLabel, valueColor: lifecycleColor),
                    _buildInfoRow('등록일', dateFormat.format(property.createdAt)),
                    if (property.updatedAt != null)
                      _buildInfoRow('수정일', dateFormat.format(property.updatedAt!)),
                  ],
                ),
                const SizedBox(height: 16),

                // 건물 정보 카드
                if (property.buildingName != null ||
                    property.buildingType != null ||
                    property.totalFloors != null ||
                    property.floor != null ||
                    property.structure != null ||
                    property.buildingYear != null ||
                    property.exclusiveArea != null ||
                    property.commonArea != null ||
                    property.parkingArea != null ||
                    property.buildingNumber != null)
                  _buildInfoCard(
                    title: '건물 정보',
                    icon: Icons.apartment,
                    color: Colors.purple,
                    children: [
                      if (property.buildingName != null && property.buildingName!.isNotEmpty)
                        _buildInfoRow('단지명', property.buildingName!),
                      if (property.buildingType != null && property.buildingType!.isNotEmpty)
                        _buildInfoRow('건물 유형', property.buildingType!),
                      if (property.buildingNumber != null && property.buildingNumber!.isNotEmpty)
                        _buildInfoRow('건물번호', property.buildingNumber!),
                      if (property.totalFloors != null)
                        _buildInfoRow('전체 층수', '${property.totalFloors}층'),
                      if (property.floor != null)
                        _buildInfoRow('해당 층', '${property.floor}층'),
                      if (property.structure != null && property.structure!.isNotEmpty)
                        _buildInfoRow('구조', property.structure!),
                      if (property.buildingYear != null && property.buildingYear!.isNotEmpty)
                        _buildInfoRow('건축년도', property.buildingYear!),
                      if (property.buildingPermit != null && property.buildingPermit!.isNotEmpty)
                        _buildInfoRow('건축허가', property.buildingPermit!),
                      if (property.exclusiveArea != null && property.exclusiveArea!.isNotEmpty)
                        _buildInfoRow('전용면적', property.exclusiveArea!),
                      if (property.commonArea != null && property.commonArea!.isNotEmpty)
                        _buildInfoRow('공용면적', property.commonArea!),
                      if (property.parkingArea != null && property.parkingArea!.isNotEmpty)
                        _buildInfoRow('주차면적', property.parkingArea!),
                    ],
                  ),
                if (property.buildingName != null ||
                    property.buildingType != null ||
                    property.totalFloors != null ||
                    property.floor != null ||
                    property.structure != null ||
                    property.buildingYear != null ||
                    property.exclusiveArea != null ||
                    property.commonArea != null ||
                    property.parkingArea != null ||
                    property.buildingNumber != null)
                  const SizedBox(height: 16),

                // 토지 정보 카드
                if (property.landPurpose != null ||
                    property.landArea != null ||
                    property.landNumber != null ||
                    property.landRatio != null ||
                    property.landUse != null ||
                    property.landCategory != null)
                  _buildInfoCard(
                    title: '토지 정보',
                    icon: Icons.landscape,
                    color: Colors.green,
                    children: [
                      if (property.landPurpose != null && property.landPurpose!.isNotEmpty)
                        _buildInfoRow('지목', property.landPurpose!),
                      if (property.landArea != null)
                        _buildInfoRow('토지 면적', '${property.landArea!.toStringAsFixed(2)}㎡'),
                      if (property.landNumber != null && property.landNumber!.isNotEmpty)
                        _buildInfoRow('토지번호', property.landNumber!),
                      if (property.landRatio != null && property.landRatio!.isNotEmpty)
                        _buildInfoRow('토지지분', property.landRatio!),
                      if (property.landUse != null && property.landUse!.isNotEmpty)
                        _buildInfoRow('토지용도', property.landUse!),
                      if (property.landCategory != null && property.landCategory!.isNotEmpty)
                        _buildInfoRow('토지분류', property.landCategory!),
                    ],
                  ),
                if (property.landPurpose != null ||
                    property.landArea != null ||
                    property.landNumber != null ||
                    property.landRatio != null ||
                    property.landUse != null ||
                    property.landCategory != null)
                  const SizedBox(height: 16),

                // 매물 설명
                if (property.description.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '매물 설명',
                    icon: Icons.description,
                    color: Colors.orange,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          property.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 주소 상세 정보
                if (property.fullAddrAPIData.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '주소 상세 정보',
                    icon: Icons.location_on,
                    color: Colors.blue,
                    children: [
                      if (property.fullAddrAPIData['roadAddr'] != null &&
                          property.fullAddrAPIData['roadAddr']!.isNotEmpty)
                        _buildInfoRow('도로명주소', property.fullAddrAPIData['roadAddr']!),
                      if (property.fullAddrAPIData['jibunAddr'] != null &&
                          property.fullAddrAPIData['jibunAddr']!.isNotEmpty)
                        _buildInfoRow('지번주소', property.fullAddrAPIData['jibunAddr']!),
                      if (property.fullAddrAPIData['bdNm'] != null &&
                          property.fullAddrAPIData['bdNm']!.isNotEmpty)
                        _buildInfoRow('건물명', property.fullAddrAPIData['bdNm']!),
                      if (property.fullAddrAPIData['siNm'] != null &&
                          property.fullAddrAPIData['siNm']!.isNotEmpty)
                        _buildInfoRow('시도', property.fullAddrAPIData['siNm']!),
                      if (property.fullAddrAPIData['sggNm'] != null &&
                          property.fullAddrAPIData['sggNm']!.isNotEmpty)
                        _buildInfoRow('시군구', property.fullAddrAPIData['sggNm']!),
                      if (property.fullAddrAPIData['emdNm'] != null &&
                          property.fullAddrAPIData['emdNm']!.isNotEmpty)
                        _buildInfoRow('읍면동', property.fullAddrAPIData['emdNm']!),
                      if (property.fullAddrAPIData['rn'] != null &&
                          property.fullAddrAPIData['rn']!.isNotEmpty)
                        _buildInfoRow('도로명', property.fullAddrAPIData['rn']!),
                      if (property.fullAddrAPIData['buldMgtNo'] != null &&
                          property.fullAddrAPIData['buldMgtNo']!.isNotEmpty)
                        _buildInfoRow('건물관리번호', property.fullAddrAPIData['buldMgtNo']!),
                      if (property.fullAddrAPIData['roadAddrNo'] != null &&
                          property.fullAddrAPIData['roadAddrNo']!.isNotEmpty)
                        _buildInfoRow('건물번호', property.fullAddrAPIData['roadAddrNo']!),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 공인중개사 정보
                if (property.brokerInfo != null) ...[
                  _buildInfoCard(
                    title: '공인중개사 정보',
                    icon: Icons.business,
                    color: Colors.indigo,
                    children: [
                      if (property.brokerInfo!['brokerName'] != null)
                        _buildInfoRow('공인중개사명', property.brokerInfo!['brokerName']),
                      if (property.brokerInfo!['broker_office_name'] != null)
                        _buildInfoRow('사무소명', property.brokerInfo!['broker_office_name']),
                      if (property.brokerInfo!['broker_license_number'] != null)
                        _buildInfoRow('등록번호', property.brokerInfo!['broker_license_number']),
                      if (property.brokerInfo!['broker_phone'] != null)
                        _buildInfoRow('연락처', property.brokerInfo!['broker_phone']),
                      if (property.brokerInfo!['broker_office_address'] != null)
                        _buildInfoRow('사무소 주소', property.brokerInfo!['broker_office_address']),
                      if (property.brokerInfo!['broker_introduction'] != null)
                        _buildInfoRow('소개', property.brokerInfo!['broker_introduction']),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 등록자 정보
                if (property.registeredByName != null || property.mainContractor != null) ...[
                  _buildInfoCard(
                    title: '등록 정보',
                    icon: Icons.person,
                    color: Colors.teal,
                    children: [
                      if (property.registeredByName != null && property.registeredByName!.isNotEmpty)
                        _buildInfoRow('등록자', property.registeredByName!),
                      if (property.mainContractor != null && property.mainContractor!.isNotEmpty)
                        _buildInfoRow('대표 계약자', property.mainContractor!),
                      if (property.contractor != null && property.contractor!.isNotEmpty)
                        _buildInfoRow('계약자', property.contractor!),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 시세 정보
                if (property.marketValue != null ||
                    property.estimatedValue != null ||
                    property.recentTransaction != null ||
                    property.nearbyPrices != null)
                  _buildInfoCard(
                    title: '시세 정보',
                    icon: Icons.trending_up,
                    color: Colors.red,
                    children: [
                      if (property.marketValue != null && property.marketValue!.isNotEmpty)
                        _buildInfoRow('시세', property.marketValue!),
                      if (property.estimatedValue != null && property.estimatedValue!.isNotEmpty)
                        _buildInfoRow('감정가', property.estimatedValue!),
                      if (property.recentTransaction != null && property.recentTransaction!.isNotEmpty)
                        _buildInfoRow('최근 거래가', property.recentTransaction!),
                      if (property.nearbyPrices != null && property.nearbyPrices!.isNotEmpty)
                        _buildInfoRow('주변 시세', property.nearbyPrices!),
                    ],
                  ),
                if (property.marketValue != null ||
                    property.estimatedValue != null ||
                    property.recentTransaction != null ||
                    property.nearbyPrices != null)
                  const SizedBox(height: 16),

                // 메모
                if (property.notes != null && property.notes!.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '메모',
                    icon: Icons.note,
                    color: Colors.amber,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          property.notes!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 등기부등본 요약 정보
                if (property.registerSummary != null && property.registerSummary!.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '등기부등본 요약',
                    icon: Icons.description,
                    color: Colors.brown,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          property.registerSummary,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 소유권 정보 (갑구)
                if (property.currentOwners != null && property.currentOwners!.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '소유권 정보 (갑구)',
                    icon: Icons.account_circle,
                    color: Colors.deepPurple,
                    children: [
                      if (property.ownerName != null && property.ownerName!.isNotEmpty)
                        _buildInfoRow('소유자명', property.ownerName!),
                      if (property.ownershipRatio != null && property.ownershipRatio!.isNotEmpty)
                        _buildInfoRow('소유지분', property.ownershipRatio!),
                      if (property.ownerInfo != null && property.ownerInfo!.isNotEmpty)
                        _buildInfoRow('소유자 정보', property.ownerInfo!),
                      ...property.currentOwners!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final owner = entry.value;
                        return _buildInfoRow(
                          '소유자 ${index + 1}',
                          owner.toString(),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 권리사항 정보 (을구)
                if (property.currentLiens != null && property.currentLiens!.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '권리사항 정보 (을구)',
                    icon: Icons.gavel,
                    color: Colors.deepOrange,
                    children: [
                      if (property.totalLienAmount != null && property.totalLienAmount!.isNotEmpty)
                        _buildInfoRow('총 권리금액', property.totalLienAmount!),
                      if (property.liens != null && property.liens!.isNotEmpty)
                        ...property.liens!.map((lien) => _buildInfoRow('권리사항', lien)),
                      ...property.currentLiens!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final lien = entry.value;
                        return _buildInfoRow(
                          '권리사항 ${index + 1}',
                          lien.toString(),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 등기부등본 발급 정보
                if (property.publishDate != null ||
                    property.officeName != null ||
                    property.publishNo != null ||
                    property.uniqueNo != null ||
                    property.issueNo != null)
                  _buildInfoCard(
                    title: '등기부등본 발급 정보',
                    icon: Icons.description,
                    color: Colors.grey,
                    children: [
                      if (property.publishDate != null && property.publishDate!.isNotEmpty)
                        _buildInfoRow('발급일', property.publishDate!),
                      if (property.officeName != null && property.officeName!.isNotEmpty)
                        _buildInfoRow('발급기관', property.officeName!),
                      if (property.publishNo != null && property.publishNo!.isNotEmpty)
                        _buildInfoRow('발급번호', property.publishNo!),
                      if (property.uniqueNo != null && property.uniqueNo!.isNotEmpty)
                        _buildInfoRow('고유번호', property.uniqueNo!),
                      if (property.issueNo != null && property.issueNo!.isNotEmpty)
                        _buildInfoRow('발행번호', property.issueNo!),
                      if (property.receiptDate != null && property.receiptDate!.isNotEmpty)
                        _buildInfoRow('접수일', property.receiptDate!),
                    ],
                  ),
                if (property.publishDate != null ||
                    property.officeName != null ||
                    property.publishNo != null ||
                    property.uniqueNo != null ||
                    property.issueNo != null)
                  const SizedBox(height: 16),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[200],
      ),
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? const Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

