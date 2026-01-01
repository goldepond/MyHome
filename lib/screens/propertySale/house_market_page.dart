import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/models/property.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/widgets/empty_state.dart';
import 'package:property/widgets/loading_overlay.dart';
import 'package:property/constants/status_constants.dart';
import 'package:property/utils/call_utils.dart';
import 'category_property_list_page.dart';
import 'buyer_property_detail_page.dart';

class HouseMarketPage extends StatefulWidget {
  final String userName;

  const HouseMarketPage({
    required this.userName,
    super.key,
  });

  @override
  State<HouseMarketPage> createState() => _HouseMarketPageState();
}

class _HouseMarketPageState extends State<HouseMarketPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Property> _allProperties = [];
  List<Property> _properties = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedTransactionType; // 거래 유형 필터 (null = 전체)

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allProperties = await _firebaseService.getAllPropertiesList();

      // 예약/보류 상태 제외만 먼저 적용
      List<Property> baseProperties = allProperties.where((property) {
        if (property.contractStatus == '예약' || property.contractStatus == '보류') {
          return false;
        }
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _allProperties = baseProperties;
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '매물을 불러오는 중 오류가 발생했습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 필터 및 정렬 적용
  void _applyFiltersAndSort() {
    List<Property> filtered = List<Property>.from(_allProperties);

    // 거래 유형 필터
    if (_selectedTransactionType != null && _selectedTransactionType!.isNotEmpty) {
      filtered = filtered.where((p) => p.transactionType == _selectedTransactionType).toList();
    }

    // 정렬
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _properties = filtered;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: '매물 정보를 불러오는 중...',
      child: Scaffold(
        backgroundColor: AirbnbColors.background,
        body: SafeArea(
          child: _errorMessage != null
              ? Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: _buildErrorWidget(),
                  ),
                )
              : _buildMainContent(),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final maxContentWidth = ResponsiveHelper.getMaxWidth(context);
    // 배너 높이는 반응형으로 계산 (메인페이지 스타일: 모바일 480px, 태블릿 560px, 데스크톱 640px)
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final bannerHeight = isMobile ? 320.0 : (isTablet ? 360.0 : 400.0); // 콘텐츠 고려하여 약간 줄임
    const double overlapHeight = 80; // 배너와 겹치는 높이

    return SingleChildScrollView(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 히어로 배너
          _buildBuyHeroBanner(),

          // 메인 컨텐츠
          Padding(
            padding: EdgeInsets.only(top: bannerHeight - overlapHeight),
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.getHorizontalPadding(context)),
                child: Column(
                  children: [
                    // 거래 유형 필터
                    _buildTransactionTypeFilter(),

                    const SizedBox(height: AppSpacing.lg),
                    
                    // 매물 카테고리 카드들
                    _buildCategoryCards(),

                    const SizedBox(height: AppSpacing.lg),
                    
                    // 매물 목록
                    _buildPropertyList(),
                    
                    const SizedBox(height: AppSpacing.lg),
                    
                    // 웹 전용 푸터 여백 (영상 촬영용)
                    if (kIsWeb) const SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md * 0.75),
      decoration: CommonDesignSystem.cardDecoration(),
      child: Row(
        children: [
          Text(
            '거래 유형:',
            style: AppTypography.withColor(
              AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
              AirbnbColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md * 0.75),
          Expanded(
            child: SegmentedButton<String?>(
              segments: const [
                ButtonSegment(value: null, label: Text('전체')),
                ButtonSegment(value: '매매', label: Text('매매')),
                ButtonSegment(value: '전세', label: Text('전세')),
                ButtonSegment(value: '월세', label: Text('월세')),
              ],
              selected: {_selectedTransactionType},
              onSelectionChanged: (Set<String?> newSelection) {
                setState(() {
                  _selectedTransactionType = newSelection.first;
                  _applyFiltersAndSort();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyHeroBanner() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xxxl * 0.75 : AppSpacing.xxxl,
        horizontal: isMobile ? AppSpacing.lg : AppSpacing.xxxl * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AirbnbColors.background,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 매우 큰 헤드라인 (Stripe/Vercel 스타일)
            Text(
              '검증된 실매물을\n한눈에 확인하세요',
              textAlign: TextAlign.center,
              style: AppTypography.withColor(
                AppTypography.display.copyWith(
                  fontSize: isMobile ? AppTypography.display.fontSize! : (isTablet ? AppTypography.display.fontSize! * 1.3 : AppTypography.display.fontSize! * 1.6),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.1,
                ),
                AirbnbColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // 큰 서브헤드
            Text(
              '원하는 조건의 매물을 쉽고 빠르게 찾을 수 있습니다',
              textAlign: TextAlign.center,
              style: AppTypography.withColor(
                AppTypography.bodyLarge.copyWith(
                  fontSize: isMobile ? AppTypography.bodyLarge.fontSize! : AppTypography.h4.fontSize!,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                ),
                AirbnbColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCards() {
    final categories = [
      {
        'title': '아파트',
        'icon': Icons.apartment_outlined,
        'buildingTypes': ['아파트', 'APT', '아파트형공장'],
      },
      {
        'title': '빌라 · 투룸+',
        'icon': Icons.home_work_outlined,
        'buildingTypes': ['빌라', '투룸+', '쓰리룸', '포룸'],
      },
      {
        'title': '원룸',
        'icon': Icons.home_outlined,
        'buildingTypes': ['원룸', '투룸', '원룸텔', '고시원'],
      },
      {
        'title': '오피스텔',
        'icon': Icons.business_outlined,
        'buildingTypes': ['오피스텔', '상가', '사무실'],
      },
      {
        'title': '상가 · 사무실',
        'icon': Icons.storefront_outlined,
        'buildingTypes': ['상가', '사무실', '상업시설'],
      },
      {
        'title': '쉐어하우스',
        'icon': Icons.people_outline,
        'buildingTypes': ['쉐어하우스', '코리빙', '하우스쉐어'],
      },
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 화면 너비가 좁을 경우 (예: 600px 미만) 2줄로 배치
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      Expanded(
                        child: _CategoryButton(
                          title: categories[i]['title'] as String,
                          icon: categories[i]['icon'] as IconData,
                          onTap: () => _navigateToCategoryPage(categories[i]),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 4),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (int i = 3; i < 6; i++) ...[
                      Expanded(
                        child: _CategoryButton(
                          title: categories[i]['title'] as String,
                          icon: categories[i]['icon'] as IconData,
                          onTap: () => _navigateToCategoryPage(categories[i]),
                        ),
                      ),
                      if (i < 5) const SizedBox(width: 4),
                    ],
                  ],
                ),
              ],
            );
          }
          
          // 화면이 충분히 넓으면 기존대로 1줄 배치
          return Row(
            children: [
              for (int i = 0; i < categories.length; i++) ...[
                Expanded(
                  child: _CategoryButton(
                    title: categories[i]['title'] as String,
                    icon: categories[i]['icon'] as IconData,
                    onTap: () => _navigateToCategoryPage(categories[i]),
                  ),
                ),
                if (i != categories.length - 1) const SizedBox(width: 4),
              ],
            ],
          );
        },
      ),
    );
  }

  void _navigateToCategoryPage(Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPropertyListPage(
          categoryTitle: category['title'],
          buildingTypes: List<String>.from(category['buildingTypes']),
          userName: widget.userName,
          selectedRegion: null, // 지역 선택 기능이 사라졌으므로 null 전달
        ),
      ),
    );
  }

  Widget _buildPropertyList() {
    if (_properties.isEmpty) {
      return const EmptyState(
        icon: Icons.home_outlined,
        title: '등록된 매물이 없습니다',
        message: '아직 판매 중인 매물이 없습니다.\n매물이 등록되면 여기에 표시됩니다.',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '등록된 매물',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AirbnbColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _properties.length,
            itemBuilder: (context, index) {
              final property = _properties[index];
              return _buildPropertyCard(property);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyCard(Property property) {
    final lifecycle = PropertyLifecycleStatus.fromProperty(property);
    final lifecycleColor = PropertyLifecycleStatus.color(lifecycle);
    final lifecycleLabel = PropertyLifecycleStatus.label(lifecycle);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BuyerPropertyDetailPage(
                  property: property,
                  currentUserId: widget.userName,
                  currentUserName: widget.userName,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        property.address,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: lifecycleColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        lifecycleLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: lifecycleColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      size: 16,
                      color: AirbnbColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${property.price.toStringAsFixed(0)}원',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AirbnbColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      property.mainContractor,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (property.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    property.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AirbnbColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // 공인중개사 정보 (항상 표시, 접을 수 없음)
                if (property.brokerInfo != null) ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      // 공인중개사명 찾기 (여러 필드명 확인 - 기존/신규 매물 모두 지원)
                      final brokerName = property.brokerInfo!['brokerName']?.toString() ?? 
                                        property.brokerInfo!['broker_office_name']?.toString() ??
                                        property.brokerInfo!['ownerName']?.toString() ??
                                        property.brokerInfo!['businessName']?.toString() ??
                                        property.brokerInfo!['name']?.toString() ??
                                        property.registeredByName ??
                                        '공인중개사';
                      
                      // 전화번호 찾기 (여러 필드명 확인)
                      final phoneNumber = property.brokerInfo!['broker_phone']?.toString() ?? 
                                         property.brokerInfo!['phoneNumber']?.toString() ??
                                         property.brokerInfo!['phone']?.toString() ??
                                         '';
                      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
                      final hasPhoneNumber = cleanPhoneNumber.isNotEmpty && cleanPhoneNumber != '-';

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AirbnbColors.blue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AirbnbColors.blue.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.business,
                              size: 18,
                              color: AirbnbColors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    brokerName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AirbnbColors.textPrimary,
                                    ),
                                  ),
                                  if (hasPhoneNumber) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      phoneNumber,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AirbnbColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (hasPhoneNumber) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () async {
                                  try {
                                    await CallUtils.makeCall(
                                      cleanPhoneNumber,
                                      relatedId: property.firestoreId,
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
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AirbnbColors.success,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.call,
                                        size: 16,
                                        color: AirbnbColors.background,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '전화',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AirbnbColors.background,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AirbnbColors.error.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AirbnbColors.error.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(
              fontSize: 14,
              color: AirbnbColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadProperties,
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
              foregroundColor: AirbnbColors.background,
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: AirbnbColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AirbnbColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
