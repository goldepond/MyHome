import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/mls_property_service.dart';
import 'package:property/models/mls_property.dart';
import 'package:intl/intl.dart';
import 'admin_proxy_registration_page.dart';

/// 관리자 - MLS 매물 관리 페이지
class AdminPropertyManagement extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminPropertyManagement({
    required this.userId, required this.userName, super.key,
  });

  @override
  State<AdminPropertyManagement> createState() => _AdminPropertyManagementState();
}

class _AdminPropertyManagementState extends State<AdminPropertyManagement> {
  final FirebaseService _firebaseService = FirebaseService();
  final MLSPropertyService _mlsService = MLSPropertyService();
  List<MLSProperty> _properties = [];
  bool _isLoading = true;
  String? _error;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all'; // all, pending, active, negotiating, contracted
  StreamSubscription<List<MLSProperty>>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _loadProperties() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _subscription?.cancel();
    _subscription = _mlsService.getAllPropertiesForAdmin(limit: 500).listen(
      (properties) {
        if (mounted) {
          setState(() {
            _properties = properties;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _error = '매물 목록을 불러오는데 실패했습니다: $e';
            _isLoading = false;
          });
        }
      },
    );
  }

  /// 대리 등록 페이지 열기
  Future<void> _openProxyRegistration() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminProxyRegistrationPage(),
      ),
    );

    if (result == true) {
      // 등록 성공 시 목록 새로고침
      _loadProperties();
    }
  }

  /// 매물 수정 페이지 열기
  Future<void> _editProperty(MLSProperty property) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AdminProxyRegistrationPage(
          existingProperty: property,
        ),
      ),
    );

    if (result == true) {
      // 수정 성공 시 목록 새로고침
      _loadProperties();
    }
  }

  List<MLSProperty> get _filteredProperties {
    List<MLSProperty> filtered = _properties;

    // 상태 필터
    if (_statusFilter != 'all') {
      filtered = filtered.where((p) => p.status.name == _statusFilter).toList();
    }

    // 검색 키워드 필터
    if (_searchKeyword.isNotEmpty) {
      final keyword = _searchKeyword.toLowerCase();
      filtered = filtered.where((p) {
        final address = p.roadAddress.toLowerCase();
        final region = p.region.toLowerCase();
        final id = p.id.toLowerCase();

        return address.contains(keyword) ||
               region.contains(keyword) ||
               id.contains(keyword);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AirbnbColors.surface,
        resizeToAvoidBottomInset: true,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openProxyRegistration,
          backgroundColor: AirbnbColors.primary,
          foregroundColor: AirbnbColors.background,
          icon: const Icon(Icons.add),
          label: const Text('대리 등록'),
        ),
        body: SafeArea(
          child: Column(
            children: [
          // 검색 및 필터 바
          Container(
            padding: const EdgeInsets.all(16),
            color: AirbnbColors.background,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '주소, 지역, 매물ID로 검색',
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
                      borderSide: const BorderSide(color: AirbnbColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AirbnbColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchKeyword = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                // 상태 필터
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', '전체'),
                      const SizedBox(width: 8),
                      _buildFilterChip('pending', '대기중'),
                      const SizedBox(width: 8),
                      _buildFilterChip('active', '배포중'),
                      const SizedBox(width: 8),
                      _buildFilterChip('underOffer', '협의중'),
                      const SizedBox(width: 8),
                      _buildFilterChip('sold', '거래완료'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 통계 카드
          Container(
            padding: const EdgeInsets.all(16),
            color: AirbnbColors.background,
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    '전체',
                    _properties.length.toString(),
                    AirbnbColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '검색 결과',
                    _filteredProperties.length.toString(),
                    AirbnbColors.primary,
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
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
      selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AirbnbColors.primary,
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
            Icon(Icons.error_outline, size: 64, color: AirbnbColors.error.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 16,
                color: AirbnbColors.textSecondary,
              ),
              textAlign: TextAlign.center,
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
            const Icon(
              Icons.home_outlined,
              size: 80,
              color: AirbnbColors.border,
            ),
            const SizedBox(height: 24),
            Text(
              _searchKeyword.isEmpty && _statusFilter == 'all'
                  ? '등록된 매물이 없습니다'
                  : '검색 결과가 없습니다',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AirbnbColors.textSecondary,
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

  Widget _buildPropertyCard(MLSProperty property) {
    final priceFormat = NumberFormat('#,###');
    final dateFormat = DateFormat('yyyy-MM-dd');

    String priceText = '${priceFormat.format(property.desiredPrice)}만원';

    // 상태 색상
    Color statusColor;
    String statusText;
    switch (property.status) {
      case PropertyStatus.draft:
        statusColor = AirbnbColors.textSecondary;
        statusText = '임시저장';
        break;
      case PropertyStatus.pending:
        statusColor = AirbnbColors.warning;
        statusText = '검증대기';
        break;
      case PropertyStatus.rejected:
        statusColor = AirbnbColors.error;
        statusText = '검증거절';
        break;
      case PropertyStatus.active:
        statusColor = AirbnbColors.success;
        statusText = '배포중';
        break;
      case PropertyStatus.inquiry:
        statusColor = Colors.blue;
        statusText = '문의중';
        break;
      case PropertyStatus.underOffer:
        statusColor = AirbnbColors.primary;
        statusText = '협의중';
        break;
      case PropertyStatus.depositTaken:
        statusColor = Colors.purple;
        statusText = '가계약';
        break;
      case PropertyStatus.sold:
        statusColor = AirbnbColors.textSecondary;
        statusText = '거래완료';
        break;
      case PropertyStatus.cancelled:
        statusColor = AirbnbColors.error;
        statusText = '취소됨';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
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
                    color: AirbnbColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.home,
                    color: AirbnbColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        property.roadAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        priceText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AirbnbColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 상태 배지
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.tag, '매물ID', property.id),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_city, '지역', property.region),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person, '등록자ID', property.userId),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              '등록일',
              dateFormat.format(property.createdAt),
            ),
            if (property.targetBrokerIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.people,
                '배포 중개사',
                '${property.targetBrokerIds.length}명',
              ),
            ],
            // 대리 등록 표시
            if (property.toMap()['isProxyRegistration'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AirbnbColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AirbnbColors.info.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.admin_panel_settings, size: 14, color: AirbnbColors.info),
                    SizedBox(width: 4),
                    Text(
                      '관리자 대리 등록',
                      style: TextStyle(fontSize: 11, color: AirbnbColors.info, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // 수정/삭제 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _editProperty(property),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('수정'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AirbnbColors.primary,
                    side: const BorderSide(color: AirbnbColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showDeleteConfirmDialog(property),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('삭제'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AirbnbColors.error,
                    foregroundColor: AirbnbColors.background,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
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
        Icon(icon, size: 16, color: AirbnbColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AirbnbColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AirbnbColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// 매물 삭제 확인 다이얼로그 (사유 입력 포함)
  Future<void> _showDeleteConfirmDialog(MLSProperty property) async {
    final propertyName = property.roadAddress;
    final reasonController = TextEditingController();
    String selectedReason = '허위 정보';

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('매물 삭제'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('정말로 "$propertyName" 매물을 삭제하시겠습니까?'),
                const SizedBox(height: 16),
                const Text(
                  '삭제 사유 선택',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                // 사유 선택 드롭다운
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: '허위 정보', child: Text('허위 정보')),
                    DropdownMenuItem(value: '중복 등록', child: Text('중복 등록')),
                    DropdownMenuItem(value: '부적절한 내용', child: Text('부적절한 내용')),
                    DropdownMenuItem(value: '연락 불가', child: Text('연락 불가')),
                    DropdownMenuItem(value: '기타', child: Text('기타 (직접 입력)')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => selectedReason = value ?? '허위 정보');
                  },
                ),
                // 기타 선택 시 직접 입력
                if (selectedReason == '기타') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: '삭제 사유를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 2,
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AirbnbColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AirbnbColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AirbnbColors.warning, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '삭제 시 매물 등록자에게 알림이 전송됩니다.',
                          style: TextStyle(fontSize: 13, color: AirbnbColors.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = selectedReason == '기타'
                    ? (reasonController.text.trim().isEmpty ? '기타' : reasonController.text.trim())
                    : selectedReason;
                Navigator.pop(context, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbColors.error,
                foregroundColor: AirbnbColors.background,
              ),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _deleteProperty(property, result);
    }
  }

  /// 매물 삭제 (알림 전송 포함)
  Future<void> _deleteProperty(MLSProperty property, String reason) async {
    try {
      final propertyId = property.id;
      if (propertyId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('매물 ID를 찾을 수 없습니다.'),
              backgroundColor: AirbnbColors.error,
            ),
          );
        }
        return;
      }

      // 삭제 전에 소유자 정보 저장
      final ownerId = property.userId;
      final propertyName = property.roadAddress;

      // MLS 매물 삭제 (소프트 삭제)
      await _mlsService.updateProperty(propertyId, {
        'isDeleted': true,
        'isActive': false,
        'deletedAt': DateTime.now().toIso8601String(),
        'deletedReason': reason,
      });

      if (mounted) {
        // 소유자에게 알림 전송
        if (ownerId.isNotEmpty) {
          await _firebaseService.sendNotification(
            userId: ownerId,
            title: '매물 삭제 알림',
            message: '등록하신 매물 "$propertyName"이(가) 관리자에 의해 삭제되었습니다.\n\n사유: $reason',
            type: 'property_deleted',
            relatedId: propertyId,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('매물이 삭제되고 알림이 전송되었습니다.'),
            backgroundColor: AirbnbColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }
}
