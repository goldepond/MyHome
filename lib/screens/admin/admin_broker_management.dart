import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/firebase_service.dart';

/// 관리자 - 전체 공인중개사 관리 페이지
class AdminBrokerManagement extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminBrokerManagement({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminBrokerManagement> createState() => _AdminBrokerManagementState();
}

class _AdminBrokerManagementState extends State<AdminBrokerManagement> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _brokers = [];
  bool _isLoading = true;
  String? _error;
  String _searchKeyword = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBrokers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrokers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      
      // brokers 컬렉션에서 모든 공인중개사 조회
      final snapshot = await _firebaseService.getAllBrokers();
      
      if (mounted) {
        setState(() {
          _brokers = snapshot;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '공인중개사 목록을 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBrokers {
    if (_searchKeyword.isEmpty) {
      return _brokers;
    }
    
    final keyword = _searchKeyword.toLowerCase();
    return _brokers.where((broker) {
      final name = (broker['businessName'] ?? broker['name'] ?? '').toString().toLowerCase();
      final registrationNumber = (broker['brokerRegistrationNumber'] ?? broker['registrationNumber'] ?? '').toString().toLowerCase();
      final ownerName = (broker['ownerName'] ?? '').toString().toLowerCase();
      
      return name.contains(keyword) || 
             registrationNumber.contains(keyword) ||
             ownerName.contains(keyword);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.kBackground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
          // 검색 바
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '공인중개사명, 등록번호, 대표자명으로 검색',
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
                    _brokers.length.toString(),
                    AppColors.kPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    '검색 결과',
                    _filteredBrokers.length.toString(),
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          // 목록
          Expanded(
            child: _buildBrokerList(),
          ),
            ],
          ),
        ),
      ),
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

  Widget _buildBrokerList() {
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
              onPressed: _loadBrokers,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredBrokers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.business_outlined,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              _searchKeyword.isEmpty
                  ? '등록된 공인중개사가 없습니다'
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
      itemCount: _filteredBrokers.length,
      itemBuilder: (context, index) {
        return _buildBrokerCard(_filteredBrokers[index]);
      },
    );
  }

  Widget _buildBrokerCard(Map<String, dynamic> broker) {
    final businessName = broker['businessName'] ?? broker['name'] ?? '정보 없음';
    final ownerName = broker['ownerName'] ?? '정보 없음';
    final registrationNumber = broker['brokerRegistrationNumber'] ?? broker['registrationNumber'] ?? '정보 없음';
    final phone = broker['phone'] ?? broker['phoneNumber'] ?? '정보 없음';
    final address = broker['roadAddress'] ?? broker['address'] ?? '정보 없음';

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
                    Icons.business,
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
                        businessName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '중개업자명: $ownerName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.badge, '등록번호', registrationNumber),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.phone, '전화번호', phone),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on, '주소', address),
            const SizedBox(height: 16),
            // 수정/삭제 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(broker),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('수정'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showDeleteConfirmDialog(broker),
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('삭제'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  /// 중개사 정보 수정 다이얼로그
  Future<void> _showEditDialog(Map<String, dynamic> broker) async {
    final businessNameController = TextEditingController(
      text: broker['businessName'] ?? broker['name'] ?? '',
    );
    final ownerNameController = TextEditingController(
      text: broker['ownerName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: broker['phone'] ?? broker['phoneNumber'] ?? '',
    );
    final addressController = TextEditingController(
      text: broker['roadAddress'] ?? broker['address'] ?? '',
    );
    final introductionController = TextEditingController(
      text: broker['introduction'] ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('중개사 정보 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: businessNameController,
                decoration: const InputDecoration(
                  labelText: '사업자명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerNameController,
                decoration: const InputDecoration(
                  labelText: '중개업자명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: '주소',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: introductionController,
                decoration: const InputDecoration(
                  labelText: '소개',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.kPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateBroker(
        broker,
        businessNameController.text.trim(),
        ownerNameController.text.trim(),
        phoneController.text.trim(),
        addressController.text.trim(),
        introductionController.text.trim(),
      );
    }

    businessNameController.dispose();
    ownerNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    introductionController.dispose();
  }

  /// 중개사 정보 업데이트
  Future<void> _updateBroker(
    Map<String, dynamic> broker,
    String businessName,
    String ownerName,
    String phone,
    String address,
    String introduction,
  ) async {
    try {
      final brokerId = broker['id'] ?? broker['brokerId'] ?? '';
      if (brokerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('중개사 ID를 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final brokerInfo = {
        'broker_office_name': businessName,
        'broker_name': ownerName,
        'broker_phone': phone,
        'broker_office_address': address,
        'broker_introduction': introduction,
      };

      final success = await _firebaseService.updateBrokerInfo(brokerId, brokerInfo);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('중개사 정보가 수정되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          // 목록 다시 로드
          _loadBrokers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('정보 수정에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 중개사 삭제 확인 다이얼로그
  Future<void> _showDeleteConfirmDialog(Map<String, dynamic> broker) async {
    final businessName = broker['businessName'] ?? broker['name'] ?? '정보 없음';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('중개사 삭제'),
        content: Text('정말로 "$businessName"을(를) 삭제하시겠습니까?\n\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteBroker(broker);
    }
  }

  /// 중개사 삭제
  Future<void> _deleteBroker(Map<String, dynamic> broker) async {
    try {
      final brokerId = broker['id'] ?? broker['brokerId'] ?? '';
      if (brokerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('중개사 ID를 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final success = await _firebaseService.deleteBroker(brokerId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('중개사가 삭제되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );
          // 목록 다시 로드
          _loadBrokers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('중개사 삭제에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

