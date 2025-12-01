import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/property.dart';
import 'package:intl/intl.dart';

/// 관리자 - 부동산 목록 조회 페이지
class AdminPropertyManagement extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminPropertyManagement({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminPropertyManagement> createState() => _AdminPropertyManagementState();
}

class _AdminPropertyManagementState extends State<AdminPropertyManagement> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _error;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'all'; // all, 매매, 전세, 월세

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final properties = await _firebaseService.getAllPropertiesList();
      
      if (mounted) {
        setState(() {
          _properties = properties;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '부동산 목록을 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  List<Property> get _filteredProperties {
    var filtered = _properties;
    
    // 거래 유형 필터
    if (_filterType != 'all') {
      filtered = filtered.where((p) => p.transactionType == _filterType).toList();
    }
    
    // 검색 키워드 필터
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      filtered = filtered.where((p) {
        final address = p.address.toLowerCase();
        final buildingName = (p.buildingName ?? '').toLowerCase();
        final mainContractor = (p.mainContractor ?? '').toLowerCase();
        
        return address.contains(keyword) ||
               buildingName.contains(keyword) ||
               mainContractor.contains(keyword);
      }).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kBackground,
      body: Column(
        children: [
          // 검색 및 필터 바
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '주소, 건물명, 계약자명으로 검색',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchKeyword.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchKeyword = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.kPrimary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchKeyword = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // 거래 유형 필터
                Row(
                  children: [
                    _buildFilterChip('all', '전체'),
                    const SizedBox(width: 8),
                    _buildFilterChip('매매', '매매'),
                    const SizedBox(width: 8),
                    _buildFilterChip('전세', '전세'),
                    const SizedBox(width: 8),
                    _buildFilterChip('월세', '월세'),
                  ],
                ),
              ],
            ),
          ),

          // 통계 카드
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '전체',
                    _properties.length.toString(),
                    AppColors.kPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '검색 결과',
                    _filteredProperties.length.toString(),
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // 목록
          Expanded(
            child: _buildPropertyList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filterType == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      selectedColor: AppColors.kPrimary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.kPrimary,
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadProperties,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredProperties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              _searchKeyword.isEmpty && _filterType == 'all'
                  ? '등록된 부동산이 없습니다'
                  : '검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProperties.length,
      itemBuilder: (context, index) {
        return _buildPropertyCard(_filteredProperties[index]);
      },
    );
  }

  Widget _buildPropertyCard(Property property) {
    final priceFormat = NumberFormat('#,###');
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    String priceText = '';
    if (property.transactionType == '매매') {
      priceText = '${priceFormat.format(property.price)}만원';
    } else if (property.transactionType == '전세') {
      priceText = '전세 ${priceFormat.format(property.price)}만원';
    } else {
      priceText = '월세 ${priceFormat.format(property.price)}만원';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.home,
                    color: AppColors.kPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.buildingName ?? property.address,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on, '주소', property.address),
            if (property.mainContractor != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, '계약자', property.mainContractor!),
            ],
            if (property.buildingType != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.business, '건물유형', property.buildingType!),
            ],
            if (property.area != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.square_foot, '면적', '${property.area}㎡'),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              '등록일',
              dateFormat.format(property.createdAt),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.info_outline,
              '계약상태',
              property.contractStatus,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ],
    );
  }
}

