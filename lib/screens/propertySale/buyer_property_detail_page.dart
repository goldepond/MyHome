import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';
import 'package:property/constants/status_constants.dart';
import 'package:property/utils/call_utils.dart';
import 'package:intl/intl.dart';

/// 내집구매 상세보기 페이지
/// 구매자가 매물의 모든 정보를 확인할 수 있는 페이지
class BuyerPropertyDetailPage extends StatefulWidget {
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
  State<BuyerPropertyDetailPage> createState() => _BuyerPropertyDetailPageState();
}

class _BuyerPropertyDetailPageState extends State<BuyerPropertyDetailPage> {

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
    if (widget.property.transactionType == '매매') {
      if (widget.property.price >= 100000000) {
        priceText = '${(widget.property.price / 100000000).toStringAsFixed(1)}억원';
      } else if (widget.property.price >= 10000) {
        priceText = '${(widget.property.price / 10000).toStringAsFixed(0)}만원';
      } else {
        priceText = '${priceFormat.format(widget.property.price)}원';
      }
    } else if (widget.property.transactionType == '전세') {
      if (widget.property.price >= 100000000) {
        priceText = '전세 ${(widget.property.price / 100000000).toStringAsFixed(1)}억원';
      } else if (widget.property.price >= 10000) {
        priceText = '전세 ${(widget.property.price / 10000).toStringAsFixed(0)}만원';
      } else {
        priceText = '전세 ${priceFormat.format(widget.property.price)}원';
      }
    } else if (widget.property.transactionType == '월세') {
      final deposit = widget.property.deposit ?? 0;
      final monthlyRent = widget.property.monthlyRent ?? 0;
      if (deposit > 0 && monthlyRent > 0) {
        final depositText = deposit >= 100000000 
            ? '${(deposit / 100000000).toStringAsFixed(1)}억'
            : deposit >= 10000 
                ? '${(deposit / 10000).toStringAsFixed(0)}만'
                : priceFormat.format(deposit);
        final monthlyText = monthlyRent >= 10000
            ? '${(monthlyRent / 10000).toStringAsFixed(0)}만'
            : priceFormat.format(monthlyRent);
        priceText = '보증금 $depositText / 월세 $monthlyText원';
      } else if (monthlyRent > 0) {
        final monthlyText = monthlyRent >= 10000
            ? '${(monthlyRent / 10000).toStringAsFixed(0)}만'
            : priceFormat.format(monthlyRent);
        priceText = '월세 $monthlyText원';
      } else {
        priceText = '월세 (상세정보 참조)';
      }
    }

    // 이미지 URL 파싱
    List<String> imageUrls = [];
    if (widget.property.propertyImages != null && widget.property.propertyImages!.isNotEmpty) {
      try {
        final decoded = jsonDecode(widget.property.propertyImages!) as List;
        imageUrls = decoded.map((e) => e.toString()).toList();
      } catch (e) {
        // 파싱 실패 시 무시
      }
    }

    // 라이프사이클 상태
    final lifecycle = PropertyLifecycleStatus.fromProperty(widget.property);
    final lifecycleColor = PropertyLifecycleStatus.color(lifecycle);
    final lifecycleLabel = PropertyLifecycleStatus.label(lifecycle);

    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        title: const Text('매물 상세보기'),
        backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
        foregroundColor: AirbnbColors.background,
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

                // 공인중개사 정보 (기본 표시 - 항상 보임)
                if (widget.property.brokerInfo != null) ...[
                  _buildBrokerInfoCard(),
                  const SizedBox(height: 16),
                ],

                // 기본 정보 카드
                _buildInfoCard(
                  title: '기본 정보',
                  icon: Icons.info_outline,
                  color: AirbnbColors.primary,
                  children: [
                    _buildInfoRow('주소', widget.property.address),
                    if (widget.property.addressCity != null && widget.property.addressCity!.isNotEmpty)
                      _buildInfoRow('시/도', widget.property.addressCity!),
                    _buildInfoRow('거래 유형', widget.property.transactionType),
                    _buildInfoRow('가격', priceText),
                    if (widget.property.area != null)
                      _buildInfoRow('면적', '${widget.property.area!.toStringAsFixed(2)}㎡'),
                    _buildInfoRow('계약 상태', widget.property.contractStatus),
                    _buildInfoRow('매물 상태', lifecycleLabel, valueColor: lifecycleColor),
                    _buildInfoRow('등록일', dateFormat.format(widget.property.createdAt)),
                    if (widget.property.updatedAt != null)
                      _buildInfoRow('수정일', dateFormat.format(widget.property.updatedAt!)),
                  ],
                ),
                const SizedBox(height: 16),

                // 건물 정보 카드
                if (widget.property.buildingName != null ||
                    widget.property.buildingType != null ||
                    widget.property.totalFloors != null ||
                    widget.property.floor != null ||
                    widget.property.structure != null ||
                    widget.property.buildingYear != null ||
                    widget.property.exclusiveArea != null ||
                    widget.property.commonArea != null ||
                    widget.property.parkingArea != null ||
                    widget.property.buildingNumber != null)
                  _buildInfoCard(
                    title: '건물 정보',
                    icon: Icons.apartment,
                    color: AirbnbColors.primary,
                    children: [
                      if (widget.property.buildingName != null && widget.property.buildingName!.isNotEmpty)
                        _buildInfoRow('단지명', widget.property.buildingName!),
                      if (widget.property.buildingType != null && widget.property.buildingType!.isNotEmpty)
                        _buildInfoRow('건물 유형', widget.property.buildingType!),
                      if (widget.property.buildingNumber != null && widget.property.buildingNumber!.isNotEmpty)
                        _buildInfoRow('건물번호', widget.property.buildingNumber!),
                      if (widget.property.totalFloors != null)
                        _buildInfoRow('전체 층수', '${widget.property.totalFloors}층'),
                      if (widget.property.floor != null)
                        _buildInfoRow('해당 층', '${widget.property.floor}층'),
                      if (widget.property.structure != null && widget.property.structure!.isNotEmpty)
                        _buildInfoRow('구조', widget.property.structure!),
                      if (widget.property.buildingYear != null && widget.property.buildingYear!.isNotEmpty)
                        _buildInfoRow('건축년도', widget.property.buildingYear!),
                      if (widget.property.buildingPermit != null && widget.property.buildingPermit!.isNotEmpty)
                        _buildInfoRow('건축허가', widget.property.buildingPermit!),
                      if (widget.property.exclusiveArea != null && widget.property.exclusiveArea!.isNotEmpty)
                        _buildInfoRow('전용면적', widget.property.exclusiveArea!),
                      if (widget.property.commonArea != null && widget.property.commonArea!.isNotEmpty)
                        _buildInfoRow('공용면적', widget.property.commonArea!),
                      if (widget.property.parkingArea != null && widget.property.parkingArea!.isNotEmpty)
                        _buildInfoRow('주차면적', widget.property.parkingArea!),
                    ],
                  ),
                if (widget.property.buildingName != null ||
                    widget.property.buildingType != null ||
                    widget.property.totalFloors != null ||
                    widget.property.floor != null ||
                    widget.property.structure != null ||
                    widget.property.buildingYear != null ||
                    widget.property.exclusiveArea != null ||
                    widget.property.commonArea != null ||
                    widget.property.parkingArea != null ||
                    widget.property.buildingNumber != null)
                  const SizedBox(height: 16),

                // 토지 정보 카드
                if (widget.property.landPurpose != null ||
                    widget.property.landArea != null ||
                    widget.property.landNumber != null ||
                    widget.property.landRatio != null ||
                    widget.property.landUse != null ||
                    widget.property.landCategory != null)
                  _buildInfoCard(
                    title: '토지 정보',
                    icon: Icons.landscape,
                    color: AirbnbColors.success,
                    children: [
                      if (widget.property.landPurpose != null && widget.property.landPurpose!.isNotEmpty)
                        _buildInfoRow('지목', widget.property.landPurpose!),
                      if (widget.property.landArea != null)
                        _buildInfoRow('토지 면적', '${widget.property.landArea!.toStringAsFixed(2)}㎡'),
                      if (widget.property.landNumber != null && widget.property.landNumber!.isNotEmpty)
                        _buildInfoRow('토지번호', widget.property.landNumber!),
                      if (widget.property.landRatio != null && widget.property.landRatio!.isNotEmpty)
                        _buildInfoRow('토지지분', widget.property.landRatio!),
                      if (widget.property.landUse != null && widget.property.landUse!.isNotEmpty)
                        _buildInfoRow('토지용도', widget.property.landUse!),
                      if (widget.property.landCategory != null && widget.property.landCategory!.isNotEmpty)
                        _buildInfoRow('토지분류', widget.property.landCategory!),
                    ],
                  ),
                if (widget.property.landPurpose != null ||
                    widget.property.landArea != null ||
                    widget.property.landNumber != null ||
                    widget.property.landRatio != null ||
                    widget.property.landUse != null ||
                    widget.property.landCategory != null)
                  const SizedBox(height: 16),

                // 매물 설명
                if (widget.property.description.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '매물 설명',
                    icon: Icons.description,
                    color: AirbnbColors.warning,
                    children: [
                      // 작성자 정보 추가
                      if (widget.property.registeredByName != null && widget.property.registeredByName!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0, bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline, size: 14, color: AirbnbColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '작성자: ${widget.property.registeredByName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AirbnbColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ] else if (widget.property.brokerInfo != null && 
                                 (widget.property.brokerInfo!['brokerName'] != null || 
                                  widget.property.brokerInfo!['broker_office_name'] != null)) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0, bottom: 4.0),
                          child: Row(
                            children: [
                              Icon(Icons.business, size: 14, color: AirbnbColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                '작성자: ${widget.property.brokerInfo!['brokerName'] ?? widget.property.brokerInfo!['broker_office_name'] ?? '공인중개사'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AirbnbColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          widget.property.description,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AirbnbColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 주소 상세 정보
                if (widget.property.fullAddrAPIData.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '주소 상세 정보',
                    icon: Icons.location_on,
                    color: AirbnbColors.primary,
                    children: [
                      if (widget.property.fullAddrAPIData['roadAddr'] != null &&
                          widget.property.fullAddrAPIData['roadAddr']!.isNotEmpty)
                        _buildInfoRow('도로명주소', widget.property.fullAddrAPIData['roadAddr']!),
                      if (widget.property.fullAddrAPIData['jibunAddr'] != null &&
                          widget.property.fullAddrAPIData['jibunAddr']!.isNotEmpty)
                        _buildInfoRow('지번주소', widget.property.fullAddrAPIData['jibunAddr']!),
                      if (widget.property.fullAddrAPIData['bdNm'] != null &&
                          widget.property.fullAddrAPIData['bdNm']!.isNotEmpty)
                        _buildInfoRow('건물명', widget.property.fullAddrAPIData['bdNm']!),
                      if (widget.property.fullAddrAPIData['siNm'] != null &&
                          widget.property.fullAddrAPIData['siNm']!.isNotEmpty)
                        _buildInfoRow('시도', widget.property.fullAddrAPIData['siNm']!),
                      if (widget.property.fullAddrAPIData['sggNm'] != null &&
                          widget.property.fullAddrAPIData['sggNm']!.isNotEmpty)
                        _buildInfoRow('시군구', widget.property.fullAddrAPIData['sggNm']!),
                      if (widget.property.fullAddrAPIData['emdNm'] != null &&
                          widget.property.fullAddrAPIData['emdNm']!.isNotEmpty)
                        _buildInfoRow('읍면동', widget.property.fullAddrAPIData['emdNm']!),
                      if (widget.property.fullAddrAPIData['rn'] != null &&
                          widget.property.fullAddrAPIData['rn']!.isNotEmpty)
                        _buildInfoRow('도로명', widget.property.fullAddrAPIData['rn']!),
                      if (widget.property.fullAddrAPIData['buldMgtNo'] != null &&
                          widget.property.fullAddrAPIData['buldMgtNo']!.isNotEmpty)
                        _buildInfoRow('건물관리번호', widget.property.fullAddrAPIData['buldMgtNo']!),
                      if (widget.property.fullAddrAPIData['roadAddrNo'] != null &&
                          widget.property.fullAddrAPIData['roadAddrNo']!.isNotEmpty)
                        _buildInfoRow('건물번호', widget.property.fullAddrAPIData['roadAddrNo']!),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 등록자 정보
                if ((widget.property.registeredByName?.isNotEmpty ?? false) || 
                    widget.property.mainContractor.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '등록 정보',
                    icon: Icons.person,
                    color: AirbnbColors.teal,
                    children: [
                      if (widget.property.registeredByName?.isNotEmpty ?? false)
                        _buildInfoRow('등록자', widget.property.registeredByName!),
                      if (widget.property.mainContractor.isNotEmpty)
                        _buildInfoRow('대표 계약자', widget.property.mainContractor),
                      if (widget.property.contractor.isNotEmpty)
                        _buildInfoRow('계약자', widget.property.contractor),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 시세 정보
                if (widget.property.marketValue != null ||
                    widget.property.estimatedValue != null ||
                    widget.property.recentTransaction != null ||
                    widget.property.nearbyPrices != null)
                  _buildInfoCard(
                    title: '시세 정보',
                    icon: Icons.trending_up,
                    color: AirbnbColors.error,
                    children: [
                      if (widget.property.marketValue != null && widget.property.marketValue!.isNotEmpty)
                        _buildInfoRow('시세', widget.property.marketValue!),
                      if (widget.property.estimatedValue != null && widget.property.estimatedValue!.isNotEmpty)
                        _buildInfoRow('감정가', widget.property.estimatedValue!),
                      if (widget.property.recentTransaction != null && widget.property.recentTransaction!.isNotEmpty)
                        _buildInfoRow('최근 거래가', widget.property.recentTransaction!),
                      if (widget.property.nearbyPrices != null && widget.property.nearbyPrices!.isNotEmpty)
                        _buildInfoRow('주변 시세', widget.property.nearbyPrices!),
                    ],
                  ),
                if (widget.property.marketValue != null ||
                    widget.property.estimatedValue != null ||
                    widget.property.recentTransaction != null ||
                    widget.property.nearbyPrices != null)
                  const SizedBox(height: 16),

                // 메모
                if (widget.property.notes != null && widget.property.notes!.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '메모',
                    icon: Icons.note,
                    color: AirbnbColors.orange,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          widget.property.notes!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AirbnbColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 등기부등본 요약 정보
                if (widget.property.registerSummary.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '등기부등본 요약',
                    icon: Icons.description,
                    color: AirbnbColors.primary,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          widget.property.registerSummary,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AirbnbColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 소유권 정보 (갑구)
                if (widget.property.currentOwners != null && widget.property.currentOwners!.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '소유권 정보 (갑구)',
                    icon: Icons.account_circle,
                    color: Colors.deepPurple,
                    children: [
                      if (widget.property.ownerName != null && widget.property.ownerName!.isNotEmpty)
                        _buildInfoRow('소유자명', widget.property.ownerName!),
                      if (widget.property.ownershipRatio != null && widget.property.ownershipRatio!.isNotEmpty)
                        _buildInfoRow('소유지분', widget.property.ownershipRatio!),
                      if (widget.property.ownerInfo != null && widget.property.ownerInfo!.isNotEmpty)
                        _buildInfoRow('소유자 정보', widget.property.ownerInfo!),
                      ...widget.property.currentOwners!.asMap().entries.map((entry) {
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
                if (widget.property.currentLiens != null && widget.property.currentLiens!.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '권리사항 정보 (을구)',
                    icon: Icons.gavel,
                    color: Colors.deepOrange,
                    children: [
                      if (widget.property.totalLienAmount != null && widget.property.totalLienAmount!.isNotEmpty)
                        _buildInfoRow('총 권리금액', widget.property.totalLienAmount!),
                      if (widget.property.liens != null && widget.property.liens!.isNotEmpty)
                        ...widget.property.liens!.map((lien) => _buildInfoRow('권리사항', lien)),
                      ...widget.property.currentLiens!.asMap().entries.map((entry) {
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
                if (widget.property.publishDate != null ||
                    widget.property.officeName != null ||
                    widget.property.publishNo != null ||
                    widget.property.uniqueNo != null ||
                    widget.property.issueNo != null)
                  _buildInfoCard(
                    title: '등기부등본 발급 정보',
                    icon: Icons.description,
                    color: AirbnbColors.textSecondary,
                    children: [
                      if (widget.property.publishDate != null && widget.property.publishDate!.isNotEmpty)
                        _buildInfoRow('발급일', widget.property.publishDate!),
                      if (widget.property.officeName != null && widget.property.officeName!.isNotEmpty)
                        _buildInfoRow('발급기관', widget.property.officeName!),
                      if (widget.property.publishNo != null && widget.property.publishNo!.isNotEmpty)
                        _buildInfoRow('발급번호', widget.property.publishNo!),
                      if (widget.property.uniqueNo != null && widget.property.uniqueNo!.isNotEmpty)
                        _buildInfoRow('고유번호', widget.property.uniqueNo!),
                      if (widget.property.issueNo != null && widget.property.issueNo!.isNotEmpty)
                        _buildInfoRow('발행번호', widget.property.issueNo!),
                      if (widget.property.receiptDate != null && widget.property.receiptDate!.isNotEmpty)
                        _buildInfoRow('접수일', widget.property.receiptDate!),
                    ],
                  ),
                if (widget.property.publishDate != null ||
                    widget.property.officeName != null ||
                    widget.property.publishNo != null ||
                    widget.property.uniqueNo != null ||
                    widget.property.issueNo != null)
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
        color: AirbnbColors.borderLight,
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
                  color: AirbnbColors.border,
                  child: const Center(
                    child: Icon(Icons.error_outline, size: 48, color: AirbnbColors.textSecondary),
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: AirbnbColors.borderLight,
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
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
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
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AirbnbColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 공인중개사 정보 카드 (항상 표시, 접을 수 없음)
  Widget _buildBrokerInfoCard() {
    final brokerInfo = widget.property.brokerInfo!;
    
    // 공인중개사명 찾기 (여러 필드명 확인 - 기존/신규 매물 모두 지원)
    final brokerName = brokerInfo['brokerName']?.toString() ?? 
                      brokerInfo['broker_office_name']?.toString() ??
                      brokerInfo['ownerName']?.toString() ??
                      brokerInfo['businessName']?.toString() ??
                      brokerInfo['name']?.toString() ??
                      widget.property.registeredByName ??
                      '공인중개사';
    
    // 전화번호 찾기 (여러 필드명 확인)
    final phoneNumber = brokerInfo['broker_phone']?.toString() ?? 
                       brokerInfo['phoneNumber']?.toString() ??
                       brokerInfo['phone']?.toString() ??
                       '';
    final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final hasPhoneNumber = cleanPhoneNumber.isNotEmpty && cleanPhoneNumber != '-';

    // 사무소명 (여러 필드명 확인)
    final officeName = brokerInfo['broker_office_name']?.toString() ?? 
                     brokerInfo['businessName']?.toString() ?? 
                     brokerInfo['name']?.toString();
    
    // 등록번호 (여러 필드명 확인)
    final licenseNumber = brokerInfo['broker_license_number']?.toString() ?? 
                         brokerInfo['brokerRegistrationNumber']?.toString() ??
                         brokerInfo['registrationNumber']?.toString();
    
    // 사무소 주소 (여러 필드명 확인)
    final officeAddress = brokerInfo['broker_office_address']?.toString() ?? 
                         brokerInfo['roadAddress']?.toString() ??
                         brokerInfo['address']?.toString();
    
    // 소개 (여러 필드명 확인)
    final introduction = brokerInfo['broker_introduction']?.toString() ?? 
                        brokerInfo['introduction']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AirbnbColors.blue.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AirbnbColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: AirbnbColors.blue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '담당 공인중개사',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 기본 정보 (항상 보임)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  brokerName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AirbnbColors.textPrimary,
                                  ),
                                ),
                                if (hasPhoneNumber) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, size: 16, color: AirbnbColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Text(
                                        phoneNumber,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: AirbnbColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (hasPhoneNumber) ...[
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  await CallUtils.makeCall(
                                    cleanPhoneNumber,
                                    relatedId: widget.property.firestoreId,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('전화 걸기 실패: $e'),
                                        backgroundColor: AirbnbColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('전화걸기', style: TextStyle(fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AirbnbColors.success,
                                foregroundColor: AirbnbColors.background,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 상세 정보 (항상 표시)
            if (officeName != null && officeName.isNotEmpty && officeName != brokerName) ...[
              const Divider(height: 24),
              _buildInfoRow('사무소명', officeName),
            ],
            if (licenseNumber != null && licenseNumber.isNotEmpty) ...[
              if (officeName == null || officeName.isEmpty || officeName == brokerName)
                const Divider(height: 24),
              _buildInfoRow('등록번호', licenseNumber),
            ],
            if (officeAddress != null && officeAddress.isNotEmpty) ...[
              if ((officeName == null || officeName.isEmpty || officeName == brokerName) && 
                  (licenseNumber == null || licenseNumber.isEmpty))
                const Divider(height: 24),
              _buildInfoRow('사무소 주소', officeAddress),
            ],
            if (introduction != null && introduction.isNotEmpty) ...[
              if ((officeName == null || officeName.isEmpty || officeName == brokerName) && 
                  (licenseNumber == null || licenseNumber.isEmpty) &&
                  (officeAddress == null || officeAddress.isEmpty))
                const Divider(height: 24),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '소개',
                    style: TextStyle(
                      fontSize: 14,
                      color: AirbnbColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    introduction,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AirbnbColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

