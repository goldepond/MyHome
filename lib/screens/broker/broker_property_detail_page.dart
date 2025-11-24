import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/property.dart';
import 'package:property/screens/broker/property_edit_form_page.dart';
import 'package:intl/intl.dart';

/// 공인중개사가 등록한 매물 상세보기 페이지
class BrokerPropertyDetailPage extends StatelessWidget {
  final Property property;
  final Map<String, dynamic> brokerData;

  const BrokerPropertyDetailPage({
    required this.property,
    required this.brokerData,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 반응형 레이아웃
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 800;
    final maxWidth = isWeb ? 1200.0 : screenWidth;
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

    return Scaffold(
      backgroundColor: AppColors.kBackground,
      appBar: AppBar(
        title: const Text('매물 상세보기'),
        backgroundColor: AppColors.kPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '수정',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PropertyEditFormPage(
                    property: property,
                    brokerData: brokerData,
                  ),
                ),
              );
            },
          ),
        ],
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
                  children: [
                    _buildInfoRow('주소', property.address),
                    _buildInfoRow('거래 유형', property.transactionType),
                    _buildInfoRow('가격', priceText),
                    if (property.area != null)
                      _buildInfoRow('면적', '${property.area!.toStringAsFixed(2)}㎡'),
                    _buildInfoRow('계약 상태', property.contractStatus),
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
                    property.buildingYear != null)
                  _buildInfoCard(
                    title: '건물 정보',
                    icon: Icons.apartment,
                    children: [
                      if (property.buildingName != null && property.buildingName!.isNotEmpty)
                        _buildInfoRow('단지명', property.buildingName!),
                      if (property.buildingType != null && property.buildingType!.isNotEmpty)
                        _buildInfoRow('건물 유형', property.buildingType!),
                      if (property.totalFloors != null)
                        _buildInfoRow('전체 층수', '${property.totalFloors}층'),
                      if (property.floor != null)
                        _buildInfoRow('해당 층', '${property.floor}층'),
                      if (property.structure != null && property.structure!.isNotEmpty)
                        _buildInfoRow('구조', property.structure!),
                      if (property.buildingYear != null && property.buildingYear!.isNotEmpty)
                        _buildInfoRow('건축년도', property.buildingYear!),
                    ],
                  ),
                if (property.buildingName != null ||
                    property.buildingType != null ||
                    property.totalFloors != null ||
                    property.floor != null ||
                    property.structure != null ||
                    property.buildingYear != null)
                  const SizedBox(height: 16),

                // 매물 설명
                if (property.description.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '매물 설명',
                    icon: Icons.description,
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

                // 참조 정보 (주소 상세 정보)
                if (property.fullAddrAPIData.isNotEmpty) ...[
                  _buildInfoCard(
                    title: '주소 상세 정보',
                    icon: Icons.location_on,
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
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // 등록자 정보
                _buildInfoCard(
                  title: '등록 정보',
                  icon: Icons.person,
                  children: [
                    if (property.registeredByName != null && property.registeredByName!.isNotEmpty)
                      _buildInfoRow('등록자', property.registeredByName!),
                    if (property.brokerInfo != null && property.brokerInfo!['brokerName'] != null)
                      _buildInfoRow('공인중개사', property.brokerInfo!['brokerName']),
                    if (property.brokerInfo != null &&
                        property.brokerInfo!['broker_office_name'] != null)
                      _buildInfoRow('사무소명', property.brokerInfo!['broker_office_name']),
                  ],
                ),
                const SizedBox(height: 24),

                // 수정 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PropertyEditFormPage(
                            property: property,
                            brokerData: brokerData,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text(
                      '매물 수정하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
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
      height: 300,
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
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              Icon(icon, color: AppColors.kPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

