import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/mls_property.dart';
import '../../api_request/mls_property_service.dart';
import '../../constants/apple_design_system.dart';
import '../../utils/logger.dart';
import 'mls_quick_registration_page.dart';
import 'mls_property_detail_page.dart';
import '../login_page.dart';

/// MLS 매물 마켓플레이스
///
/// Apple 디자인 철학 적용:
/// - Clarity: 콘텐츠 중심 설계, 충분한 여백, 명확한 타이포그래피
/// - Deference: UI가 콘텐츠를 가리지 않음, 미니멀한 인터페이스
/// - Depth: 레이어 구조, 시각적 계층으로 네비게이션 명확화
///
/// 모든 활성 매물을 공개적으로 조회할 수 있는 메인 화면
/// - 로그인 불필요 (게스트 모드 지원)
/// - 반응형 그리드 레이아웃 (1-4 컬럼)
/// - 미니멀한 필터링 및 정렬
/// - "매물 등록" 버튼 (로그인 필요)
class MLSMarketplacePage extends StatefulWidget {
  const MLSMarketplacePage({super.key});

  @override
  State<MLSMarketplacePage> createState() => _MLSMarketplacePageState();
}

class _MLSMarketplacePageState extends State<MLSMarketplacePage> {
  final _mlsService = MLSPropertyService();

  List<MLSProperty> _properties = [];
  bool _isLoading = true;
  String? _selectedRegion;
  String? _selectedPriceRange;
  String? _selectedStatus;

  // 스트림 구독 관리
  StreamSubscription<List<MLSProperty>>? _subscription;

  // 지역 목록
  final List<Map<String, String>> _regions = [
    {'value': '', 'label': '전체 지역'},
    {'value': 'SEOUL', 'label': '서울'},
    {'value': 'GYEONGGI', 'label': '경기'},
    {'value': 'INCHEON', 'label': '인천'},
    {'value': 'BUSAN', 'label': '부산'},
    {'value': 'DAEGU', 'label': '대구'},
    {'value': 'DAEJEON', 'label': '대전'},
    {'value': 'GWANGJU', 'label': '광주'},
    {'value': 'ULSAN', 'label': '울산'},
  ];

  // 가격대 목록
  final List<Map<String, String>> _priceRanges = [
    {'value': '', 'label': '전체 가격'},
    {'value': '0-10000', 'label': '1억 이하'},
    {'value': '10000-30000', 'label': '1억~3억'},
    {'value': '30000-50000', 'label': '3억~5억'},
    {'value': '50000-100000', 'label': '5억~10억'},
    {'value': '100000-', 'label': '10억 이상'},
  ];

  @override
  void initState() {
    super.initState();
    // 빠른 초기 로딩: Future로 먼저 데이터 가져온 후 스트림 구독
    _loadInitialDataFast();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  /// 빠른 초기 데이터 로딩 (Future 사용)
  Future<void> _loadInitialDataFast() async {
    // Future로 빠르게 초기 데이터 로드
    final properties = await _mlsService.getAllActivePropertiesFast();

    if (!mounted) return;

    setState(() {
      _properties = properties;
      _isLoading = false;
    });

    // 초기 데이터 로드 후 스트림 구독 (실시간 업데이트용)
    _subscribeToProperties();
  }

  /// 실시간 업데이트를 위한 스트림 구독
  void _subscribeToProperties() {
    _subscription?.cancel();
    _subscription = _mlsService.getAllActiveProperties(limit: 100).listen(
      (properties) {
        if (mounted && _shouldUpdate(properties)) {
          setState(() {
            _properties = properties;
          });
        }
      },
      onError: (error) {
        Logger.error('Failed to load marketplace properties', error: error);
      },
    );
  }

  /// 리스트가 실제로 변경되었는지 확인
  bool _shouldUpdate(List<MLSProperty> newList) {
    if (_properties.length != newList.length) return true;
    for (int i = 0; i < _properties.length; i++) {
      if (_properties[i].id != newList[i].id ||
          _properties[i].updatedAt != newList[i].updatedAt) {
        return true;
      }
    }
    return false;
  }

  List<MLSProperty> get _filteredProperties {
    var result = _properties;

    // 지역 필터
    if (_selectedRegion != null && _selectedRegion!.isNotEmpty) {
      result = result.where((p) => p.region == _selectedRegion).toList();
    }

    // 가격대 필터
    if (_selectedPriceRange != null && _selectedPriceRange!.isNotEmpty) {
      final parts = _selectedPriceRange!.split('-');
      final minPrice = double.tryParse(parts[0]) ?? 0;
      final maxPrice = parts.length > 1 && parts[1].isNotEmpty ? double.tryParse(parts[1]) : null;

      result = result.where((p) {
        if (maxPrice != null) {
          return p.desiredPrice >= minPrice && p.desiredPrice < maxPrice;
        } else {
          return p.desiredPrice >= minPrice;
        }
      }).toList();
    }

    // 상태 필터
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      result = result.where((p) => p.status.toString().split('.').last == _selectedStatus).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isMobile = AppleResponsive.isMobile(context);

    return Scaffold(
      backgroundColor: AppleColors.systemGroupedBackground,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppleColors.systemBlue),
                ),
              )
            : _properties.isEmpty
                ? _buildEmptyState(isLoggedIn)
                : _buildPropertyGrid(isMobile),
      ),
      // 빠른 등록 FAB (3-클릭 룰 준수: 1클릭으로 등록 시작)
      floatingActionButton: _buildQuickRegistrationFAB(context, isLoggedIn),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// 빠른 등록 FAB
  /// 로그인 상태와 무관하게 항상 표시
  /// 비로그인 시: 로그인 → 즉시 등록
  /// 로그인 시: 즉시 등록
  Widget _buildQuickRegistrationFAB(BuildContext context, bool isLoggedIn) {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToQuickRegistration(context, isLoggedIn),
      backgroundColor: AppleColors.systemBlue,
      elevation: 4,
      icon: const Icon(Icons.add_circle_outline, color: Colors.white),
      label: Text(
        '빠른 등록',
        style: AppleTypography.body.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 빠른 등록으로 이동
  void _navigateToQuickRegistration(BuildContext context, bool isLoggedIn) async {
    if (!isLoggedIn) {
      // 비로그인 시: 로그인 안내 후 로그인 페이지로
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppleColors.secondarySystemGroupedBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppleRadius.lg),
          ),
          title: Text(
            '로그인이 필요합니다',
            style: AppleTypography.headline.copyWith(
              color: AppleColors.label,
            ),
          ),
          content: Text(
            '매물을 등록하려면 로그인이 필요합니다.\n지금 로그인하시겠습니까?',
            style: AppleTypography.body.copyWith(
              color: AppleColors.secondaryLabel,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                '취소',
                style: AppleTypography.body.copyWith(
                  color: AppleColors.secondaryLabel,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                '로그인',
                style: AppleTypography.body.copyWith(
                  color: AppleColors.systemBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

      if (shouldLogin == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
        // 로그인 후 다시 시도
        if (context.mounted && FirebaseAuth.instance.currentUser != null) {
          _navigateToQuickRegistration(context, true);
        }
      }
      return;
    }

    // 로그인 시: 빠른 등록 페이지로 이동
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MLSQuickRegistrationPage(),
      ),
    );

    // 등록 완료 시 목록 새로고침
    if (result == true && context.mounted) {
      _loadInitialDataFast();
    }
  }

  Widget _buildEmptyState(bool isLoggedIn) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppleSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 아이콘 (SF Symbols 스타일)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppleColors.secondarySystemFill,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.home_work_outlined,
                size: 64,
                color: AppleColors.tertiaryLabel,
              ),
            ),
            const SizedBox(height: AppleSpacing.xl),

            // 타이틀 (Clarity: 명확한 메시지)
            Text(
              '등록된 매물이 없습니다',
              style: AppleTypography.title2.copyWith(
                fontWeight: FontWeight.w600,
                color: AppleColors.label,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppleSpacing.sm),

            // 서브타이틀
            Text(
              '첫 번째 매물을 등록해보세요',
              style: AppleTypography.body.copyWith(
                color: AppleColors.secondaryLabel,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: AppleSpacing.xxl),
            AppleButton(
              text: '빠른 등록',
              icon: Icons.add_circle_outline,
              onPressed: () => _navigateToQuickRegistration(context, isLoggedIn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertyGrid(bool isMobile) {
    return CustomScrollView(
      slivers: [
        // 헤더
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? AppleSpacing.md : AppleSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 타이틀
                Text(
                  '매물 마켓',
                  style: isMobile
                      ? AppleTypography.largeTitle
                      : AppleTypography.largeTitle.copyWith(fontSize: 48),
                ),
                const SizedBox(height: AppleSpacing.xs),

                // 서브타이틀 (매물 개수)
                Text(
                  '${_filteredProperties.length}개의 매물',
                  style: AppleTypography.title3.copyWith(
                    color: AppleColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: AppleSpacing.md),

                // 필터 섹션
                _buildFilterSection(isMobile),
              ],
            ),
          ),
        ),

        // 게스트 CTA 배너 (비로그인 시에만 표시)
        if (FirebaseAuth.instance.currentUser == null)
          SliverToBoxAdapter(
            child: _buildGuestCTABanner(isMobile),
          ),

        // 매물 그리드 (Depth: 레이어 구조로 계층 표현)
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? AppleSpacing.md : AppleSpacing.lg,
            vertical: AppleSpacing.sm,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: AppleResponsive.getGridColumns(
                MediaQuery.of(context).size.width,
              ),
              mainAxisSpacing: AppleSpacing.md,
              crossAxisSpacing: AppleSpacing.md,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final property = _filteredProperties[index];
                return _buildPropertyCard(property);
              },
              childCount: _filteredProperties.length,
            ),
          ),
        ),

        // 하단 여백
        const SliverToBoxAdapter(
          child: SizedBox(height: AppleSpacing.xxl),
        ),
      ],
    );
  }

  Widget _buildPropertyCard(MLSProperty property) {
    return AppleCard(
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MLSPropertyDetailPage(property: property),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 매물 이미지 (3:2 비율)
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppleRadius.lg),
              ),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppleColors.tertiarySystemFill,
                ),
                child: property.thumbnailUrl != null
                    ? Image.network(
                        property.thumbnailUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppleColors.systemBlue,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderImage();
                        },
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
          ),

          // 매물 정보 (Clarity: 명확한 정보 계층)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppleSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 가격 (Primary)
                  Text(
                    '${_formatPrice(property.desiredPrice)}만원',
                    style: AppleTypography.title3.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppleColors.label,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppleSpacing.xxs),

                  // 주소 (Secondary)
                  Text(
                    property.roadAddress,
                    style: AppleTypography.subheadline.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // 상태 배지
                  _buildStatusBadge(property.status),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return const Center(
      child: Icon(
        Icons.home_outlined,
        size: 48,
        color: AppleColors.tertiaryLabel,
      ),
    );
  }

  Widget _buildStatusBadge(PropertyStatus status) {
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppleSpacing.xs,
        vertical: AppleSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppleRadius.sm),
      ),
      child: Text(
        statusText,
        style: AppleTypography.caption1.copyWith(
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 10000) {
      return '${(price / 10000).toStringAsFixed(1)}억';
    }
    return price.toStringAsFixed(0);
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
        return '판매중';
      case PropertyStatus.inquiry:
        return '문의중';
      case PropertyStatus.underOffer:
        return '협의중';
      case PropertyStatus.depositTaken:
        return '가계약';
      case PropertyStatus.sold:
        return '거래완료';
      case PropertyStatus.cancelled:
        return '취소';
    }
  }

  Color _getStatusColor(PropertyStatus status) {
    switch (status) {
      case PropertyStatus.draft:
        return AppleColors.secondaryLabel;
      case PropertyStatus.pending:
        return AppleColors.systemYellow;
      case PropertyStatus.rejected:
        return AppleColors.systemRed;
      case PropertyStatus.active:
        return AppleColors.systemGreen;
      case PropertyStatus.inquiry:
        return AppleColors.systemBlue;
      case PropertyStatus.underOffer:
        return AppleColors.systemOrange;
      case PropertyStatus.depositTaken:
        return AppleColors.systemPurple;
      case PropertyStatus.sold:
        return AppleColors.tertiaryLabel;
      case PropertyStatus.cancelled:
        return AppleColors.systemRed;
    }
  }

  /// 필터 섹션
  Widget _buildFilterSection(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 지역 필터
          _buildFilterChip(
            label: _regions.firstWhere(
              (r) => r['value'] == (_selectedRegion ?? ''),
              orElse: () => _regions.first,
            )['label']!,
            isActive: _selectedRegion != null && _selectedRegion!.isNotEmpty,
            onTap: () => _showFilterBottomSheet('지역', _regions, _selectedRegion, (value) {
              setState(() => _selectedRegion = value);
            }),
          ),
          const SizedBox(width: 8),

          // 가격대 필터
          _buildFilterChip(
            label: _priceRanges.firstWhere(
              (r) => r['value'] == (_selectedPriceRange ?? ''),
              orElse: () => _priceRanges.first,
            )['label']!,
            isActive: _selectedPriceRange != null && _selectedPriceRange!.isNotEmpty,
            onTap: () => _showFilterBottomSheet('가격대', _priceRanges, _selectedPriceRange, (value) {
              setState(() => _selectedPriceRange = value);
            }),
          ),
          const SizedBox(width: 8),

          // 필터 초기화 버튼
          if ((_selectedRegion != null && _selectedRegion!.isNotEmpty) ||
              (_selectedPriceRange != null && _selectedPriceRange!.isNotEmpty))
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedRegion = null;
                  _selectedPriceRange = null;
                  _selectedStatus = null;
                });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('초기화'),
              style: TextButton.styleFrom(
                foregroundColor: AppleColors.systemRed,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppleRadius.full),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppleColors.systemBlue.withValues(alpha: 0.1) : AppleColors.tertiarySystemFill,
            borderRadius: BorderRadius.circular(AppleRadius.full),
            border: Border.all(
              color: isActive ? AppleColors.systemBlue : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppleTypography.subheadline.copyWith(
                  color: isActive ? AppleColors.systemBlue : AppleColors.label,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isActive ? AppleColors.systemBlue : AppleColors.secondaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet(
    String title,
    List<Map<String, String>> options,
    String? currentValue,
    void Function(String?) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppleColors.secondarySystemGroupedBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppleRadius.lg)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 헤더
              Padding(
                padding: const EdgeInsets.all(AppleSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: AppleTypography.headline.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // 옵션 목록
              ...options.map((option) {
                final isSelected = option['value'] == (currentValue ?? '');
                return ListTile(
                  title: Text(
                    option['label']!,
                    style: AppleTypography.body.copyWith(
                      color: isSelected ? AppleColors.systemBlue : AppleColors.label,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: AppleColors.systemBlue)
                      : null,
                  onTap: () {
                    onSelect(option['value']!.isEmpty ? null : option['value']);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: AppleSpacing.md),
            ],
          ),
        );
      },
    );
  }

  /// 게스트 CTA 배너 (등록 유도)
  Widget _buildGuestCTABanner(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppleSpacing.md : AppleSpacing.lg,
        vertical: AppleSpacing.sm,
      ),
      child: AppleCard(
        padding: EdgeInsets.all(isMobile ? AppleSpacing.md : AppleSpacing.lg),
        onTap: () => _navigateToQuickRegistration(context, false),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppleColors.systemBlue,
                    AppleColors.systemBlue.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.add_home_work_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: AppleSpacing.md),

            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내 매물도 올려보세요',
                    style: AppleTypography.headline.copyWith(
                      color: AppleColors.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppleSpacing.xxs),
                  Text(
                    '간편 등록으로 지역 중개사에게 자동 배포',
                    style: AppleTypography.subheadline.copyWith(
                      color: AppleColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),

            // 화살표 아이콘
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppleColors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}
