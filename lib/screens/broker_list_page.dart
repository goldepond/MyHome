import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:property/widgets/retry_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/screens/login_page.dart';
import 'package:property/screens/broker/broker_detail_page.dart';
import 'package:property/screens/policy/privacy_policy_page.dart';
import 'package:property/screens/policy/terms_of_service_page.dart';
import 'package:property/screens/common/submit_success_page.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/utils/transaction_type_helper.dart';
import 'package:property/utils/logger.dart';
import 'package:property/utils/validation_utils.dart';

/// 부동산 상담을 위한 공인중개사 찾기 페이지
class BrokerListPage extends StatefulWidget {
  final String address;
  final double latitude;
  final double longitude;
  final String userName;
  final String? propertyArea;
  final String? userId;
  final String? transactionType; // 거래 유형 (매매/전세/월세)

  const BrokerListPage({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.userName = '',
    this.propertyArea,
    this.userId,
    this.transactionType,
    super.key,
  });

  @override
  State<BrokerListPage> createState() => _BrokerListPageState();
}

class _BrokerListPageState extends State<BrokerListPage> {
  List<Broker> propertyBrokers = [];
  List<Broker> brokers = [];
  List<Broker> filteredBrokers = [];
  int _lastSearchRadiusMeters = 1000;
  bool _searchRadiusExpanded = false;
  bool isLoading = true;
  String? error;
  final FirebaseService _firebaseService = FirebaseService();
  bool get _isLoggedIn => (widget.userId != null && widget.userId!.isNotEmpty);

  /// 사용자 이메일 가져오기
  Future<String> _getUserEmail() async {
    // 1. Firebase Auth에서 현재 사용자 이메일 가져오기
    final currentUser = _firebaseService.currentUser;
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      return currentUser.email!;
    }

    // 2. userId가 있으면 Firestore에서 사용자 정보 조회
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      final userData = await _firebaseService.getUser(widget.userId!);
      if (userData != null && userData['email'] != null) {
        final email = userData['email'] as String;
        if (email.isNotEmpty) {
          return email;
        }
      }
    }

    // 3. 기본값: userName 기반 이메일 (fallback)
    return '${widget.userName}@example.com';
  }

  final int _pageSize = 10;
  int _currentPage = 0;
  
  // ===================== 테스트 전용 설정 =====================
  // 특정 테스트 중개사(김이택)를 항상 목록에 포함시키기 위한 플래그입니다.
  // 실제 운영 시에는 이 값을 false 로 바꾸거나, 아래 블록 전체를 삭제하면 됩니다.
  static const bool _enableTestBroker = false;
  static const String _testBrokerRegistrationNumber = '22222222222222222';
  // ==========================================================
  
  String searchKeyword = '';
  bool showOnlyWithPhone = false;
  bool showOnlyGlobalBroker = false;
  final TextEditingController _searchController = TextEditingController();
  
  String _sortOption = 'distance';
  
  bool _isSelectionMode = false;
  final Set<String> _selectedBrokerIds = {};
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedBrokerIds.clear();
      }
    });
  }

  Widget _buildHeroSection(BuildContext context, double maxWidth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AirbnbColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          AirbnbColors.cardShadowLarge,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 주소 정보 영역
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AirbnbColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on, color: AirbnbColors.primary, size: 24),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '선택한 주소 주변',
                      style: AppTypography.withColor(
                        AppTypography.bodySmall,
                        AirbnbColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.address,
                      style: AppTypography.withColor(
                        AppTypography.h4,
                        AirbnbColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      '검색 반경 ${(_lastSearchRadiusMeters / 1000).toStringAsFixed(1)}km'
                      '${_searchRadiusExpanded ? ' · 자동 확장됨' : ''}',
                      style: AppTypography.withColor(
                        AppTypography.caption,
                        AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          // 액션 버튼 영역
          _buildBulkActionButtons(maxWidth),
        ],
      ),
    );
  }

  Widget _buildBulkActionButtons(double maxWidth) {
    // 반응형 디자인: ResponsiveHelper 사용
    final bool isWide = !ResponsiveHelper.isMobile(context);
    // 🔥 로그인 체크 제거 - 게스트 모드도 가능
    final bool canBulkTop10 = filteredBrokers.isNotEmpty;
    final bool canManual = true;
    // 반응형 카드 높이
    final double cardHeight = ResponsiveHelper.isMobile(context) ? 160.0 : 180.0;

    Widget buildActionCard({
      required String title,
      required String description,
      required IconData icon,
      required bool enabled,
      required List<Color> gradient,
      required String badge,
      required VoidCallback? onTap,
      VoidCallback? onTapDisabled,
      required bool requiresLogin,
    }) {
      return _ActionCard(
        title: title,
        description: description,
        icon: icon,
        enabled: enabled,
        gradient: gradient,
        badge: badge,
        cardHeight: cardHeight,
        onTap: onTap,
        onTapDisabled: onTapDisabled,
        requiresLogin: requiresLogin,
      );
    }

    final top10Card = buildActionCard(
      title: '상위 10곳 요청',
      description: canBulkTop10
          ? '정렬 기준 Top10 중개사에게\n원클릭으로 견적을 보냅니다'
          : '먼저 주소 주변 중개사를\n불러온 뒤 사용 가능합니다',
      icon: Icons.flash_on_rounded,
      enabled: canBulkTop10,
      badge: 'AI 추천',
      gradient: const [AirbnbColors.primary, AirbnbColors.primary],
      onTap: _requestQuoteToTop10,
      requiresLogin: false, // 🔥 게스트 모드도 가능
    );

    final manualCard = buildActionCard(
      title: _isSelectionMode ? '선택 모드 종료' : '다중 선택 요청',
      description: '원하는 중개사를 체크하고\n한 번에 요청서를 전송하세요',
      icon: Icons.playlist_add_check_rounded,
      enabled: canManual,
      badge: _isSelectionMode ? '선택 중' : '맞춤 요청',
      gradient: const [AirbnbColors.teal, AirbnbColors.teal],
      onTap: _toggleSelectionMode,
      requiresLogin: false, // 🔥 게스트 모드도 가능
    );

    // 반응형 레이아웃: 가로 배치 vs 세로 배치
    if (isWide) {
      return SizedBox(
        height: cardHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: top10Card),
            SizedBox(width: ResponsiveHelper.getCardSpacing(context)),
            Expanded(child: manualCard),
          ],
        ),
      );
    }

    // 모바일: 세로 배치
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: cardHeight, child: top10Card),
        SizedBox(height: ResponsiveHelper.getCardSpacing(context)),
        SizedBox(height: cardHeight, child: manualCard),
      ],
    );
  }

  
  // ============================================
  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.brokerListOpened,
      params: {
        'address': widget.address,
        'latitude': widget.latitude,
        'longitude': widget.longitude,
        'hasUser': _isLoggedIn,
      },
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.brokerDiscovery,
    );
    _searchBrokers();
  }

  Widget _buildLoadingSkeleton() {
    return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: 120, color: Colors.grey.withValues(alpha: 0.2)),
                    SizedBox(height: AppSpacing.sm),
                    Container(height: 10, width: 80, color: Colors.grey.withValues(alpha: 0.15)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }


  /// 공인중개사 검색
  Future<void> _searchBrokers() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // 1단계: VWorld API 결과 먼저 가져오기
      final response = await BrokerService.searchNearbyBrokers(
        latitude: widget.latitude,
        longitude: widget.longitude,
        radiusMeters: 1000, // 1km 반경
      );

      // 기본 결과 복사
      List<Broker> mergedBrokers = List<Broker>.from(response.brokers);

      // ===================== 테스트 전용 중개사 주입 =====================
      if (_enableTestBroker) {
        try {
          final testData = await _firebaseService
              .getBrokerByRegistrationNumber(_testBrokerRegistrationNumber);
          if (testData != null) {
            final alreadyExists = mergedBrokers.any(
              (b) => b.registrationNumber == _testBrokerRegistrationNumber,
            );
            if (!alreadyExists) {
              final String name = (testData['businessName'] as String?) ??
                  (testData['ownerName'] as String?) ??
                  '김이택 공인중개사';
              final String address =
                  (testData['address'] as String?) ?? widget.address;
              final String? phone =
                  (testData['phoneNumber'] as String?) ?? '';

              mergedBrokers.insert(
                0,
                Broker(
                  name: name,
                  roadAddress: address,
                  jibunAddress: address,
                  registrationNumber: _testBrokerRegistrationNumber,
                  etcAddress: '',
                  employeeCount: '-',
                  registrationDate: '',
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  distance: 0,
                  systemRegNo: '0000000000', // 정렬 시 상단 배치
                  ownerName: testData['ownerName'] as String?,
                  businessName: testData['businessName'] as String?,
                  phoneNumber: phone,
                  businessStatus: testData['businessStatus'] as String?,
                  seoulAddress: address,
                  district: null,
                  legalDong: null,
                  sggCode: null,
                  stdgCode: null,
                  lotnoSe: null,
                  mno: null,
                  sno: null,
                  roadCode: null,
                  bldg: null,
                  bmno: null,
                  bsno: null,
                  penaltyStartDate: null,
                  penaltyEndDate: null,
                  inqCount: null,
                  introduction: testData['introduction'] as String?,
                ),
              );
            }
          }
        } catch (e) {
          // 테스트 중개사 주입 실패는 전체 플로우에 영향 주지 않음
          Logger.warning(
            '테스트 중개사 주입 실패',
            metadata: {'error': e.toString()},
          );
        }
      }
      // ================================================================

      // 2단계: 즉시 UI에 표시 (Firestore 보강 전)
      if (!mounted) return;

      setState(() {
        propertyBrokers = mergedBrokers;
        _lastSearchRadiusMeters = response.radiusMetersUsed;
        _searchRadiusExpanded =
            response.wasExpanded || response.radiusMetersUsed > 1000;
        _sortBySystemRegNo(propertyBrokers);
        brokers = List<Broker>.from(propertyBrokers);
        isLoading = false; // 즉시 로딩 종료
        _resetPagination();
        _applyFilters(); // 필터링 및 정렬 적용
      });

      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.brokerListLoaded,
        params: {
          'address': widget.address,
          'resultCount': response.brokers.length,
          'radiusMeters': response.radiusMetersUsed,
          'radiusExpanded':
              response.wasExpanded || response.radiusMetersUsed > 1000,
        },
        userId: widget.userId,
        userName: widget.userName,
        stage: FunnelStage.brokerDiscovery,
      );

      // 3단계: 백그라운드에서 Firestore 데이터로 보강 (비동기)
      _enhanceWithFirestoreData(mergedBrokers);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = '공인중개사 정보를 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.brokerListLoadFailed,
        params: {
          'address': widget.address,
          'message': e.toString(),
        },
        userId: widget.userId,
        userName: widget.userName,
        stage: FunnelStage.brokerDiscovery,
      );
    }
  }

  /// Firestore 데이터로 백그라운드 보강
  /// VWorld API 결과를 먼저 표시한 후, Firestore에 저장된 추가 정보로 보강
  Future<void> _enhanceWithFirestoreData(List<Broker> brokers) async {
    try {
      // 등록번호 목록 수집
      final registrationNumbers = brokers
          .where((b) => b.registrationNumber.isNotEmpty)
          .map((b) => b.registrationNumber)
          .toSet()
          .toList();

      if (registrationNumbers.isEmpty) return;

      // 배치로 Firestore에서 조회 (성능 최적화)
      final firestoreDataMap = await _firebaseService
          .getBrokersByRegistrationNumbers(registrationNumbers)
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              return <String, Map<String, dynamic>>{};
            },
          );

      // Firestore 데이터로 보강
      final enhancedBrokers = brokers.map((broker) {
        if (broker.registrationNumber.isEmpty) {
          return broker; // 등록번호 없으면 그대로
        }

        final firestoreData = firestoreDataMap[broker.registrationNumber];
        if (firestoreData == null) {
          return broker; // Firestore에 없으면 그대로
        }

        // Firestore에 저장된 정보로 보강 (우선순위: Firestore > VWorld API)
        return Broker(
          name: (firestoreData['businessName'] as String?) ??
              (firestoreData['ownerName'] as String?) ??
              broker.name,
          roadAddress: (firestoreData['roadAddress'] as String?) ??
              (firestoreData['address'] as String?) ??
              broker.roadAddress,
          jibunAddress: broker.jibunAddress,
          registrationNumber: broker.registrationNumber,
          etcAddress: broker.etcAddress,
          employeeCount: broker.employeeCount,
          registrationDate: broker.registrationDate,
          latitude: broker.latitude,
          longitude: broker.longitude,
          distance: broker.distance,
          systemRegNo: broker.systemRegNo,
          ownerName: (firestoreData['ownerName'] as String?) ?? broker.ownerName,
          businessName:
              (firestoreData['businessName'] as String?) ?? broker.businessName,
          phoneNumber: (firestoreData['phoneNumber'] as String?) ??
              (firestoreData['phone'] as String?) ??
              broker.phoneNumber, // Firestore 우선
          businessStatus: (firestoreData['businessStatus'] as String?) ??
              broker.businessStatus,
          seoulAddress: broker.seoulAddress,
          district: broker.district,
          legalDong: broker.legalDong,
          sggCode: broker.sggCode,
          stdgCode: broker.stdgCode,
          lotnoSe: broker.lotnoSe,
          mno: broker.mno,
          sno: broker.sno,
          roadCode: broker.roadCode,
          bldg: broker.bldg,
          bmno: broker.bmno,
          bsno: broker.bsno,
          penaltyStartDate: broker.penaltyStartDate,
          penaltyEndDate: broker.penaltyEndDate,
          inqCount: broker.inqCount,
          introduction: (firestoreData['introduction'] as String?) ??
              broker.introduction, // Firestore 우선
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        propertyBrokers = enhancedBrokers;
        _sortBySystemRegNo(propertyBrokers);
        brokers = List<Broker>.from(propertyBrokers);
        _applyFilters(); // 필터링 및 정렬 재적용
      });
    } catch (e) {
      // Firestore 보강 실패 시 원본 데이터 유지 (이미 표시됨)
    }
  }
  
  /// 필터링 적용
  void _applyFilters() {
    setState(() {
      filteredBrokers = brokers.where((broker) {
        // 검색어 필터
        if (searchKeyword.isNotEmpty) {
          final keyword = searchKeyword.toLowerCase();
          final name = broker.name.toLowerCase();
          final road = broker.roadAddress.toLowerCase();
          final jibun = broker.jibunAddress.toLowerCase();
          
          if (!name.contains(keyword) && 
              !road.contains(keyword) && 
              !jibun.contains(keyword)) {
            return false;
          }
        }
        
        // 전화번호 필터
        if (showOnlyWithPhone) {
          if (broker.phoneNumber == null || 
              broker.phoneNumber!.isEmpty || 
              broker.phoneNumber == '-') {
            return false;
          }
        }
        
        
        // 글로벌공인중개사 필터
        if (showOnlyGlobalBroker) {
          if (broker.globalBrokerLanguage == null || 
              broker.globalBrokerLanguage!.isEmpty) {
            return false;
          }
        }
        
        return true;
      }).toList();
      
      _applySorting(filteredBrokers);
      _resetPagination();
    });

    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.brokerListFilterApplied,
      params: {
        'searchKeyword': searchKeyword,
        'showOnlyWithPhone': showOnlyWithPhone,
        'showOnlyGlobalBroker': showOnlyGlobalBroker,
        'sortOption': _sortOption,
        'resultCount': filteredBrokers.length,
      },
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.brokerDiscovery,
    );
  }

  // 정렬 적용
  void _applySorting(List<Broker> list) {
    switch (_sortOption) {
      case 'distance':
        _sortByDistance(list);
        break;
      case 'name':
        _sortByName(list);
        break;
      case 'registrationDate':
        _sortByRegistrationDate(list);
        break;
      case 'globalBroker':
        _sortByGlobalBroker(list);
        break;
      case 'systemRegNo':
      default:
        _sortBySystemRegNo(list);
        break;
    }
  }

  void _sortByDistance(List<Broker> list) {
    list.sort((a, b) {
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });
  }

  void _sortByName(List<Broker> list) {
    list.sort((a, b) {
      final nameA = a.name.trim();
      final nameB = b.name.trim();
      if (nameA.isEmpty && nameB.isEmpty) return 0;
      if (nameA.isEmpty) return 1;
      if (nameB.isEmpty) return -1;
      return nameA.compareTo(nameB);
    });
  }

  void _sortBySystemRegNo(List<Broker> list) {
    int? toNumeric(String? s) {
      if (s == null) return null;
      final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return null;
      return int.tryParse(digits);
    }
    list.sort((a, b) {
      final an = toNumeric(a.systemRegNo);
      final bn = toNumeric(b.systemRegNo);
      if (an == null && bn == null) return 1;
      if (an == null) return 1;
      if (bn == null) return -1;
      return an.compareTo(bn);
    });
  }

  void _sortByRegistrationDate(List<Broker> list) {
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      
      // YYYYMMDD 형식 처리
      if (dateStr.length == 8 && RegExp(r'^\d{8}$').hasMatch(dateStr)) {
        final year = int.tryParse(dateStr.substring(0, 4));
        final month = int.tryParse(dateStr.substring(4, 6));
        final day = int.tryParse(dateStr.substring(6, 8));
        if (year != null && month != null && day != null) {
          try {
            return DateTime(year, month, day);
          } catch (e) {
            return null;
          }
        }
      }
      
      // YYYY-MM-DD 등 표준 형식 처리
      return DateTime.tryParse(dateStr);
    }
    
    list.sort((a, b) {
      final dateA = parseDate(a.registrationDate);
      final dateB = parseDate(b.registrationDate);
      
      // 날짜가 없는 항목은 뒤로
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      
      // 최신순 (내림차순)
      return dateB.compareTo(dateA);
    });
  }

  void _sortByGlobalBroker(List<Broker> list) {
    list.sort((a, b) {
      final aIsGlobal = a.globalBrokerLanguage != null && a.globalBrokerLanguage!.isNotEmpty;
      final bIsGlobal = b.globalBrokerLanguage != null && b.globalBrokerLanguage!.isNotEmpty;
      
      // 글로벌공인중개사가 있는 것을 먼저
      if (aIsGlobal && !bIsGlobal) return -1;
      if (!aIsGlobal && bIsGlobal) return 1;
      
      // 둘 다 글로벌이거나 둘 다 일반인 경우, 거리순으로 정렬
      if (a.distance == null && b.distance == null) return 0;
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });
  }

  List<Broker> _visiblePage() {
    final start = _currentPage * _pageSize;
    if (start >= filteredBrokers.length) return const [];
    final end = start + _pageSize;
    return filteredBrokers.sublist(start, end > filteredBrokers.length ? filteredBrokers.length : end);
  }

  int get _totalPages {
    if (filteredBrokers.isEmpty) return 1;
    return ((filteredBrokers.length + _pageSize - 1) ~/ _pageSize);
  }

  void _resetPagination() {
    _currentPage = 0;
  }

  @override
  Widget build(BuildContext context) {
    // 웹 최적화: 최대 너비 제한
    // 반응형 디자인: ResponsiveHelper 사용
    final maxWidth = ResponsiveHelper.getMaxWidth(context);

    return Scaffold(
      backgroundColor: AirbnbColors.background,
      // 선택 모드일 때 하단 고정 버튼
      floatingActionButton: _isSelectionMode && widget.userName.isNotEmpty && _selectedBrokerIds.isNotEmpty
          ? Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AirbnbColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _requestQuoteToMultiple,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                  foregroundColor: AirbnbColors.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send, size: 28),
                ),
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AirbnbColors.textWhite.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedBrokerIds.length}',
                        style: AppTypography.withColor(
                          AppTypography.h3,
                          AirbnbColors.textWhite,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(
                      '곳에 일괄 견적 요청하기',
                      style: AppTypography.withColor(
                        AppTypography.h3,
                        AirbnbColors.textWhite,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: CustomScrollView(
        slivers: [
          // 깔끔한 헤더 (메인페이지 스타일)
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AirbnbColors.background,
            foregroundColor: AirbnbColors.primary,
            elevation: 0,
            shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.08),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AirbnbColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (widget.userName.isEmpty)
                IconButton(
                  icon: const Icon(Icons.login, color: AirbnbColors.primary),
                  tooltip: '로그인',
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                    );
                    
                    if (result == null) {
                      return;
                    }
                    
                    if (mounted && result is Map &&
                        ((result['userName'] is String && (result['userName'] as String).isNotEmpty) ||
                         (result['userId'] is String && (result['userId'] as String).isNotEmpty))) {
                      final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
                          ? result['userName']
                          : result['userId'];
                      final String userId = (result['userId'] is String) ? result['userId'] as String : '';
                      
                      
                      Navigator.pop(context);
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrokerListPage(
                            address: widget.address,
                            latitude: widget.latitude,
                            longitude: widget.longitude,
                            userName: userName,
                            userId: userId.isNotEmpty ? userId : null,
                            propertyArea: widget.propertyArea,
                            transactionType: widget.transactionType,
                          ),
                        ),
                      );
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('로그인에 실패했습니다. 이메일/전화번호를 확인해주세요.'),
                            backgroundColor: AirbnbColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              SizedBox(width: AppSpacing.sm),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                '공인중개사 찾기',
                style: AppTypography.withColor(
                  AppTypography.h3,
                  AirbnbColors.textPrimary,
                ),
              ),
              background: Container(
                width: double.infinity,
                color: AirbnbColors.background,
              ),
            ),
          ),

          // 1. 히어로 섹션 및 필터 UI (SliverToBoxAdapter)
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg, bottom: 0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroSection(context, maxWidth),
                      SizedBox(height: AppSpacing.xl),

                      // 공인중개사 목록 헤더 - 웹 스타일
                      if (!isLoading && brokers.isNotEmpty) ...[
                        // 검색 및 필터 UI (메인페이지 스타일)
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: CommonDesignSystem.cardDecoration(
                            borderRadius: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 헤더
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AirbnbColors.primaryDark,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.business, color: Colors.white, size: 20),
                                        SizedBox(width: AppSpacing.sm),
                                        Text(
                                          '공인중개사 ${filteredBrokers.length}곳',
                                          style: AppTypography.withColor(
                                            AppTypography.h4,
                                            AirbnbColors.textWhite,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (filteredBrokers.length < brokers.length) ...[
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      '/ 전체 ${brokers.length}곳',
                                      style: AppTypography.withColor(
                                        AppTypography.bodySmall,
                                        AirbnbColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              
                              SizedBox(height: AppSpacing.md),
                              
                              // 검색창
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: '중개사명, 주소로 검색',
                                  prefixIcon: const Icon(Icons.search, color: AirbnbColors.primary),
                                  suffixIcon: searchKeyword.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 20),
                                          onPressed: () {
                                            _searchController.clear();
                                            searchKeyword = '';
                                            _applyFilters();
                                          },
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: AirbnbColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                onChanged: (value) {
                                  searchKeyword = value;
                                  _applyFilters();
                                },
                              ),
                              
                              SizedBox(height: AppSpacing.md),
                              
                              // 정렬 옵션
                              Row(
                                children: [
                                  Text(
                                    '정렬:',
                                    style: AppTypography.withColor(
                                      AppTypography.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      AirbnbColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.numbers, size: 16),
                                              SizedBox(width: 4),
                                              Text('등록번호순'),
                                            ],
                                          ),
                                          selected: _sortOption == 'systemRegNo',
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _sortOption = 'systemRegNo';
                                                _applyFilters();
                                              });
                                            }
                                          },
                                          selectedColor: AirbnbColors.primary.withValues(alpha: 0.15),
                                          checkmarkColor: AirbnbColors.primary,
                                          backgroundColor: AirbnbColors.background,
                                          side: BorderSide(
                                            color: _sortOption == 'systemRegNo' 
                                                ? AirbnbColors.primary 
                                                : AirbnbColors.border,
                                            width: _sortOption == 'systemRegNo' ? 1.5 : 1,
                                          ),
                                          labelStyle: AppTypography.withColor(
                                            AppTypography.caption.copyWith(
                                              fontWeight: _sortOption == 'systemRegNo' ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                            _sortOption == 'systemRegNo' ? AirbnbColors.primary : AirbnbColors.textSecondary,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.near_me, size: 16),
                                              SizedBox(width: 4),
                                              Text('거리순'),
                                            ],
                                          ),
                                          selected: _sortOption == 'distance',
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _sortOption = 'distance';
                                                _applyFilters();
                                              });
                                            }
                                          },
                                          selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
                                          checkmarkColor: AirbnbColors.primary,
                                          backgroundColor: AirbnbColors.background,
                                          labelStyle: TextStyle(
                                            color: _sortOption == 'distance' ? AirbnbColors.primary : AirbnbColors.textSecondary,
                                            fontWeight: _sortOption == 'distance' ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.sort_by_alpha, size: 16),
                                              SizedBox(width: 4),
                                              Text('이름순'),
                                            ],
                                          ),
                                          selected: _sortOption == 'name',
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _sortOption = 'name';
                                                _applyFilters();
                                              });
                                            }
                                          },
                                          selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
                                          checkmarkColor: AirbnbColors.primary,
                                          backgroundColor: AirbnbColors.background,
                                          labelStyle: TextStyle(
                                            color: _sortOption == 'name' ? AirbnbColors.primary : AirbnbColors.textSecondary,
                                            fontWeight: _sortOption == 'name' ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.calendar_today, size: 16),
                                              SizedBox(width: 4),
                                              Text('등록일순'),
                                            ],
                                          ),
                                          selected: _sortOption == 'registrationDate',
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _sortOption = 'registrationDate';
                                                _applyFilters();
                                              });
                                            }
                                          },
                                          selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
                                          checkmarkColor: AirbnbColors.primary,
                                          backgroundColor: AirbnbColors.background,
                                          labelStyle: TextStyle(
                                            color: _sortOption == 'registrationDate' ? AirbnbColors.primary : AirbnbColors.textSecondary,
                                            fontWeight: _sortOption == 'registrationDate' ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.language, size: 16),
                                              SizedBox(width: 4),
                                              Text('글로벌 우선'),
                                            ],
                                          ),
                                          selected: _sortOption == 'globalBroker',
                                          onSelected: (selected) {
                                            if (selected) {
                                              setState(() {
                                                _sortOption = 'globalBroker';
                                                _applyFilters();
                                              });
                                            }
                                          },
                                          selectedColor: AirbnbColors.primary.withValues(alpha: 0.2),
                                          checkmarkColor: AirbnbColors.primary,
                                          backgroundColor: AirbnbColors.background,
                                          labelStyle: TextStyle(
                                            color: _sortOption == 'globalBroker' ? AirbnbColors.primary : AirbnbColors.textSecondary,
                                            fontWeight: _sortOption == 'globalBroker' ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: AppSpacing.sm),
                              
                              // 필터 버튼들
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    label: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.phone, size: 16),
                                        SizedBox(width: 4),
                                        Text('전화번호 있음'),
                                      ],
                                    ),
                                    selected: showOnlyWithPhone,
                                    onSelected: (selected) {
                                      setState(() {
                                        showOnlyWithPhone = selected;
                                        _applyFilters();
                                      });
                                    },
                                    selectedColor: AirbnbColors.primary.withValues(alpha: 0.15),
                                    checkmarkColor: AirbnbColors.primary,
                                    backgroundColor: AirbnbColors.background,
                                    side: BorderSide(
                                      color: showOnlyWithPhone 
                                          ? AirbnbColors.primary 
                                          : AirbnbColors.border,
                                      width: showOnlyWithPhone ? 1.5 : 1,
                                    ),
                                    labelStyle: AppTypography.withColor(
                                      AppTypography.caption.copyWith(
                                        fontWeight: showOnlyWithPhone ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                      showOnlyWithPhone ? AirbnbColors.primary : AirbnbColors.textSecondary,
                                    ),
                                  ),
                                  FilterChip(
                                    label: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.language, size: 16),
                                        SizedBox(width: 4),
                                        Text('글로벌공인중개사'),
                                      ],
                                    ),
                                    selected: showOnlyGlobalBroker,
                                    onSelected: (selected) {
                                      setState(() {
                                        showOnlyGlobalBroker = selected;
                                        _applyFilters();
                                      });
                                    },
                                    selectedColor: AirbnbColors.teal.withValues(alpha: 0.15),
                                    checkmarkColor: AirbnbColors.teal,
                                    backgroundColor: AirbnbColors.background,
                                    side: BorderSide(
                                      color: showOnlyGlobalBroker 
                                          ? AirbnbColors.teal 
                                          : AirbnbColors.border,
                                      width: showOnlyGlobalBroker ? 1.5 : 1,
                                    ),
                                    labelStyle: AppTypography.withColor(
                                      AppTypography.caption.copyWith(
                                        fontWeight: showOnlyGlobalBroker ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                      showOnlyGlobalBroker ? AirbnbColors.teal : AirbnbColors.textSecondary,
                                    ),
                                  ),
                                  if (showOnlyWithPhone || showOnlyGlobalBroker || searchKeyword.isNotEmpty)
                                    ActionChip(
                                      label: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.refresh, size: 16),
                                          SizedBox(width: 4),
                                          Text('초기화'),
                                        ],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          showOnlyWithPhone = false;
                                          showOnlyGlobalBroker = false;
                                          searchKeyword = '';
                                          _searchController.clear();
                                          _applyFilters();
                                        });
                                      },
                                      backgroundColor: AirbnbColors.background,
                                      side: BorderSide(
                                        color: AirbnbColors.border,
                                        width: 1,
                                      ),
                                      labelStyle: AppTypography.withColor(
                                        AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        AirbnbColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSpacing.lg),
                      ],

                      if (!isLoading && _searchRadiusExpanded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildRadiusInfoBanner(),
                        ),

                      // 로딩 / 에러 / 결과 표시 (리스트 제외)
                      if (isLoading)
                        SizedBox(height: AppSpacing.xxxl * 5, child: _buildLoadingSkeleton())
                      else if (error != null)
                        RetryView(
                          message: error!,
                          onRetry: () {
                            setState(() {
                              isLoading = true;
                              error = null;
                            });
                            _searchBrokers();
                          },
                        )
                      else if (brokers.isEmpty)
                        _buildNoResultsCard()
                      else if (filteredBrokers.isEmpty)
                        _buildNoFilterResultsCard()
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),

          // 2. 리스트 (SliverMasonryGrid) - Lazy Loading 적용
          if (!isLoading && error == null && brokers.isNotEmpty && filteredBrokers.isNotEmpty)
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.getMaxWidth(context) < double.infinity && ResponsiveHelper.getMaxWidth(context) < MediaQuery.of(context).size.width
                    ? (MediaQuery.of(context).size.width - ResponsiveHelper.getMaxWidth(context)) / 2 + AppSpacing.lg
                    : AppSpacing.lg,
                vertical: 0,
              ),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: ResponsiveHelper.isWeb(context) ? 2 : 1,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childCount: _visiblePage().length,
                itemBuilder: (context, index) {
                  final pageItems = _visiblePage();
                  return _buildBrokerCard(pageItems[index]);
                },
              ),
            ),

          // 3. 하단 여백 및 페이지네이션
          if (!isLoading && error == null && brokers.isNotEmpty && filteredBrokers.isNotEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        SizedBox(height: AppSpacing.md),
                        _buildPaginationControls(),
                        SizedBox(height: AppSpacing.xxxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildPaginationControls() {
    if (filteredBrokers.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage -= 1)
              : null,
          style: CommonDesignSystem.secondaryButtonStyle(),
          child: const Text('이전'),
        ),
        SizedBox(width: AppSpacing.sm),
        Text(
          '${_currentPage + 1} / $_totalPages',
          style: AppTypography.withColor(
            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
            AirbnbColors.textSecondary,
          ),
        ),
        SizedBox(width: AppSpacing.sm),
        OutlinedButton(
          onPressed: (_currentPage < _totalPages - 1)
              ? () => setState(() => _currentPage += 1)
              : null,
          style: CommonDesignSystem.secondaryButtonStyle(),
          child: const Text('다음'),
        ),
      ],
    );
  }
  
  String _formatRadius(int meters) {
    if (meters >= 1000) {
      final double km = meters / 1000;
      return km == km.roundToDouble() ? '${km.toStringAsFixed(0)}km' : '${km.toStringAsFixed(1)}km';
    }
    return '${meters}m';
  }

  Widget _buildRadiusInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AirbnbColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.radar, color: AirbnbColors.blue, size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '주변 중개사가 부족하여 검색 반경을 ${_formatRadius(_lastSearchRadiusMeters)}까지 확장했습니다.',
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                AirbnbColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 공인중개사 카드 (리뉴얼)
  Widget _buildBrokerCard(Broker broker) {
    final hasPhone = broker.phoneNumber != null && 
                     broker.phoneNumber!.isNotEmpty && 
                     broker.phoneNumber != '-';
    final isOpen = broker.businessStatus == '영업중';
    
    return Container(
      decoration: CommonDesignSystem.cardDecoration(
        borderRadius: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 - 핵심 정보 한눈에 (에어비엔비 스타일 단색)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AirbnbColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 첫 번째 줄: 선택 체크박스 + 사업자명
                Row(
                  children: [
                    // 선택 모드일 때 체크박스
                    if (_isSelectionMode && widget.userName.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _selectedBrokerIds.contains(broker.systemRegNo)
                              ? AirbnbColors.textWhite
                              : AirbnbColors.textWhite.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AirbnbColors.textWhite,
                            width: 2,
                          ),
                        ),
                        child: Checkbox(
                          value: _selectedBrokerIds.contains(broker.systemRegNo),
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedBrokerIds.add(broker.systemRegNo ?? '');
                              } else {
                                _selectedBrokerIds.remove(broker.systemRegNo);
                              }
                            });
                          },
                          checkColor: AirbnbColors.primary,
                          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AirbnbColors.textWhite;
                            }
                            return Colors.transparent;
                          }),
                          side: const BorderSide(color: AirbnbColors.textWhite, width: 2),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Text(
                        broker.name,
                        style: AppTypography.withColor(
                          AppTypography.h2.copyWith(
                            letterSpacing: -0.5,
                          ),
                          AirbnbColors.textWhite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                // 두 번째 줄: 핵심 배지들 (거리, 전화번호, 영업상태)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    // 거리 배지
                    if (broker.distance != null)
                      _buildHeaderBadge(
                        icon: Icons.near_me,
                        text: broker.distanceText,
                        color: AirbnbColors.textWhite.withValues(alpha: 0.25),
                        textColor: AirbnbColors.textWhite,
                      ),
                    // 전화번호 배지
                    if (hasPhone)
                      _buildHeaderBadge(
                        icon: Icons.phone,
                        text: '전화번호 있음',
                        color: AirbnbColors.success.withValues(alpha: 0.3),
                        textColor: AirbnbColors.textWhite,
                      )
                    else
                      _buildHeaderBadge(
                        icon: Icons.phone_disabled,
                        text: '전화번호 없음',
                        color: AirbnbColors.textSecondary.withValues(alpha: 0.3),
                        textColor: AirbnbColors.textWhite.withValues(alpha: 0.8),
                      ),
                    // 영업상태 배지
                    _buildHeaderBadge(
                      icon: isOpen ? Icons.check_circle : Icons.pause_circle,
                      text: broker.businessStatus ?? '정보 없음',
                      color: isOpen 
                          ? AirbnbColors.success.withValues(alpha: 0.3)
                          : AirbnbColors.warning.withValues(alpha: 0.3),
                      textColor: AirbnbColors.textWhite,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 상세 정보 - 리뉴얼
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 핵심 정보 그리드 (비교하기 쉽게)
                Row(
                  children: [
                    // 전화번호 (있는 경우만)
                    if (hasPhone)
                      Expanded(
                        child: _buildQuickInfoCard(
                          icon: Icons.phone,
                          label: '전화번호',
                          value: broker.phoneNumber ?? '',
                          color: AirbnbColors.success,
                        ),
                      ),
                    if (hasPhone) SizedBox(width: AppSpacing.sm),
                    // 중개업자명
                    Expanded(
                      child: _buildQuickInfoCard(
                        icon: Icons.person,
                        label: '중개업자명',
                        value: broker.ownerName ?? '-',
                        color: AirbnbColors.primary,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppSpacing.sm),
                
                // 주소 정보
                if (broker.roadAddress.isNotEmpty || broker.jibunAddress.isNotEmpty)
                  _buildAddressCard(
                    broker.roadAddress.isNotEmpty
                        ? broker.fullAddress
                        : broker.jibunAddress,
                  ),
                
                SizedBox(height: AppSpacing.sm),
                
                // 추가 정보 (등록번호, 고용인원)
                Row(
                  children: [
                    if (broker.registrationNumber.isNotEmpty)
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.badge,
                          label: '등록번호',
                          value: broker.registrationNumber,
                        ),
                      ),
                    if (broker.registrationNumber.isNotEmpty && 
                        broker.employeeCount.isNotEmpty && 
                        broker.employeeCount != '-' && 
                        broker.employeeCount != '0')
                      SizedBox(width: AppSpacing.sm),
                    if (broker.employeeCount.isNotEmpty && 
                        broker.employeeCount != '-' && 
                        broker.employeeCount != '0')
                      Expanded(
                        child: _buildInfoChip(
                          icon: Icons.people,
                          label: '고용인원',
                          value: '${broker.employeeCount}명',
                        ),
                      ),
                  ],
                ),
                
                // 행정처분 정보 (있는 경우만 표시)
                if ((broker.penaltyStartDate != null && broker.penaltyStartDate!.isNotEmpty) ||
                    (broker.penaltyEndDate != null && broker.penaltyEndDate!.isNotEmpty)) ...[
                  SizedBox(height: AppSpacing.sm),
                  Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AirbnbColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AirbnbColors.warning.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: AirbnbColors.warning, size: 16),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '행정처분 이력',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AirbnbColors.warning,
                                ),
                              ),
                              if (broker.penaltyStartDate != null && broker.penaltyStartDate!.isNotEmpty) ...[
                                SizedBox(height: AppSpacing.xs),
                                Text(
                                  '시작: ${broker.penaltyStartDate!}',
                                  style: TextStyle(
                                    color: AirbnbColors.textSecondary,
                                  ),
                                ),
                              ],
                              if (broker.penaltyEndDate != null && broker.penaltyEndDate!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '종료: ${broker.penaltyEndDate!}',
                                  style: TextStyle(
                                    color: AirbnbColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // 소개란 (있는 경우만 표시 - 간략하게)
                if (broker.introduction != null && broker.introduction!.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.sm),
                  Container(
                          padding: const EdgeInsets.all(AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description, color: AirbnbColors.textSecondary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '중개사 소개',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          broker.introduction!.length > 80
                              ? '${broker.introduction!.substring(0, 80)}...'
                              : broker.introduction!,
                          style: TextStyle(
                            color: AirbnbColors.textSecondary,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 액션 버튼들 - 리뉴얼 (선택 모드가 아닐 때만 표시)
          if (!_isSelectionMode || widget.userName.isEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AirbnbColors.background,
                border: Border(
                  top: BorderSide(
                    color: AirbnbColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // 주요 액션 버튼들 (2x2 그리드)
                  Row(
                    children: [
                      // 전화문의 (있는 경우만 활성화)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: hasPhone ? () => _makePhoneCall(broker) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasPhone ? AirbnbColors.success : AirbnbColors.border,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: hasPhone ? 2 : 0,
                          ),
                          icon: Icon(Icons.phone, size: 18),
                          label: Text(
                            '전화문의',
                            style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      // 비대면문의
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (widget.userName.isEmpty) {
                              _showLoginRequiredDialog(broker);
                              return;
                            }
                            _requestQuote(broker);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                            foregroundColor: AirbnbColors.textWhite,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.chat_bubble, size: 18),
                          label: Text(
                            '비대면문의',
                            style: AppTypography.withColor(
                              AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                              AirbnbColors.textWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                        SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      // 길찾기
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _findRoute(broker.roadAddress),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AirbnbColors.primary,
                            side: BorderSide(color: AirbnbColors.primary.withValues(alpha: 0.5), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.map, size: 18),
                          label: Text(
                            '길찾기',
                            style: AppTypography.withColor(
                              AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                              AirbnbColors.primary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      // 상세보기
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BrokerDetailPage(
                                  broker: broker,
                                  currentUserId: widget.userId,
                                  currentUserName: widget.userName,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AirbnbColors.primary,
                            side: BorderSide(color: AirbnbColors.primary.withValues(alpha: 0.5), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: Text(
                            '상세보기',
                            style: AppTypography.withColor(
                              AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                              AirbnbColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// 헤더 배지
  Widget _buildHeaderBadge({
    required IconData icon,
    required String text,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: AppTypography.withColor(
              AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
              textColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 빠른 정보 카드 (전화번호, 중개업자명 등)
  Widget _buildQuickInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AirbnbColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs + AppSpacing.xs / 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 주소 카드
  Widget _buildAddressCard(String address) {
    return Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              address,
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                AirbnbColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 정보 칩 (등록번호, 고용인원 등)
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AirbnbColors.textSecondary),
          SizedBox(width: AppSpacing.xs),
          Text(
            '$label: ',
            style: AppTypography.withColor(
              AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
              AirbnbColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTypography.withColor(
                AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                AirbnbColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  /// 결과 없음 카드 - 웹 스타일
  Widget _buildNoResultsCard({String message = '공인중개사를 찾을 수 없습니다'}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.borderLight, width: 1),
        boxShadow: [
          AirbnbColors.cardShadow,
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AirbnbColors.textSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, size: 64, color: AirbnbColors.textSecondary),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              message,
              style: AppTypography.withColor(
                AppTypography.h3,
                AirbnbColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '주변에 등록된 공인중개사가 없습니다.\n검색 반경을 넓혀보세요.',
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(height: 1.5),
                AirbnbColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 필터 결과 없음 카드
  Widget _buildNoFilterResultsCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.borderLight, width: 1),
        boxShadow: [
          AirbnbColors.cardShadow,
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AirbnbColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.filter_alt_off, size: 64, color: AirbnbColors.warning),
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              '검색 조건에 맞는 중개사가 없습니다',
              style: AppTypography.withColor(
                AppTypography.h3,
                AirbnbColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '필터를 초기화하거나 검색 조건을 변경해보세요.',
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(height: 1.5),
                AirbnbColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  showOnlyWithPhone = false;
                  showOnlyGlobalBroker = false;
                  searchKeyword = '';
                  _searchController.clear();
                  _applyFilters();
                });
              },
              style: CommonDesignSystem.primaryButtonStyle(),
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(
                '필터 초기화',
                style: AppTypography.withColor(
                  AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  AirbnbColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 길찾기 (카카오맵/네이버맵/구글맵 선택)
  void _findRoute(String address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.map, color: AirbnbColors.primary, size: 28),
            SizedBox(width: 12),
            Text('길찾기', style: AppTypography.h4),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '목적지',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.xs),
            Text(
              address,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AirbnbColors.primary,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            const Text(
              '지도 앱을 선택하세요',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.md),
            
            // 카카오맵
            _buildMapButton(
              icon: Icons.map,
              label: '카카오맵',
              color: const Color(0xFFFEE500),
              textColor: Colors.black87,
              onPressed: () {
                Navigator.pop(context);
                _launchKakaoMap(address);
              },
            ),
                        SizedBox(height: AppSpacing.sm),
            
            // 네이버 지도
            _buildMapButton(
              icon: Icons.navigation,
              label: '네이버 지도',
              color: const Color(0xFF03C75A),
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
                _launchNaverMap(address);
              },
            ),
                        SizedBox(height: AppSpacing.sm),
            
            // 구글 지도
            _buildMapButton(
              icon: Icons.place,
              label: '구글 지도',
              color: const Color(0xFF4285F4),
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context);
                _launchGoogleMap(address);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: AppTypography.bodySmall),
          ),
        ],
      ),
    );
  }

  /// 지도 앱 버튼 위젯
  Widget _buildMapButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  /// 카카오맵 열기
  Future<void> _launchKakaoMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final kakaoUrl = Uri.parse('kakaomap://search?q=$encodedAddress');
    final webUrl = Uri.parse('https://map.kakao.com/link/search/$encodedAddress');
    
    try {
      // 앱이 설치되어 있으면 앱 실행
      if (await canLaunchUrl(kakaoUrl)) {
        await launchUrl(kakaoUrl, mode: LaunchMode.externalApplication);
      } else {
        // 앱이 없으면 웹 버전 실행
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('카카오맵 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// 네이버 지도 열기
  Future<void> _launchNaverMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final naverUrl = Uri.parse('nmap://search?query=$encodedAddress');
    final webUrl = Uri.parse('https://map.naver.com/v5/search/$encodedAddress');
    
    try {
      // 앱이 설치되어 있으면 앱 실행
      if (await canLaunchUrl(naverUrl)) {
        await launchUrl(naverUrl, mode: LaunchMode.externalApplication);
      } else {
        // 앱이 없으면 웹 버전 실행
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('네이버 지도 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// 구글 지도 열기
  Future<void> _launchGoogleMap(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
    
    try {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구글 지도 실행 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 전화 문의
  void _makePhoneCall(Broker broker) {
    // 전화번호 확인
    final phoneNumber = broker.phoneNumber?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    
    if (phoneNumber.isEmpty || phoneNumber == '-') {
    showDialog(
      context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('전화번호 없음', style: AppTypography.h4),
            ],
          ),
          content: Text(
            '${broker.name}의 전화번호 정보가 없습니다.\n비대면 문의를 이용해주세요.',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      );
      return;
    }
    
    // 전화 걸기 확인 다이얼로그
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AirbnbColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.phone, color: AirbnbColors.success, size: 24),
            ),
            const SizedBox(width: 12),
            Text('전화 문의', style: AppTypography.h4),
          ],
        ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
              broker.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
                        SizedBox(height: AppSpacing.sm),
            Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AirbnbColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AirbnbColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: AirbnbColors.success, size: 20),
                  SizedBox(width: AppSpacing.sm),
                Text(
                    broker.phoneNumber ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AirbnbColors.success,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            Text(
              '전화를 걸어 직접 문의하시겠습니까?',
              style: TextStyle(fontSize: 14, color: AirbnbColors.textSecondary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
            child: Text('취소', style: AppTypography.bodySmall),
            ),
          ElevatedButton.icon(
              onPressed: () async {
              Navigator.pop(context);
              
              // 전화 걸기
              final telUri = Uri(scheme: 'tel', path: phoneNumber);
              
              try {
                if (await canLaunchUrl(telUri)) {
                  await launchUrl(telUri);
                } else {
                  // 전화 걸기를 지원하지 않는 환경 (웹 등)
                  if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📞 ${broker.phoneNumber}\n\n위 번호로 직접 전화해주세요.'),
                        backgroundColor: AirbnbColors.success,
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: '복사',
                          textColor: AirbnbColors.textWhite,
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: broker.phoneNumber ?? ''));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('전화번호가 클립보드에 복사되었습니다.'),
                                  backgroundColor: AirbnbColors.info,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('전화 걸기 실패: $e'),
                      backgroundColor: AirbnbColors.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('전화 걸기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// 로그인 필요 다이얼로그
  void _showLoginRequiredDialog(Broker broker) async {
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('로그인 필요', style: AppTypography.h4),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '비대면 문의는 로그인 후 이용 가능합니다.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            Text(
              '우측 상단의 로그인 버튼을 눌러주세요.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('취소', style: AppTypography.bodySmall),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
              foregroundColor: AirbnbColors.textWhite,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('로그인하러 가기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    // 로그인하러 가기를 선택한 경우
    if (shouldLogin == true && mounted) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      
      // 사용자가 뒤로가기로 취소한 경우 (result가 null)
      if (result == null) {
        // 취소한 경우는 아무 메시지도 표시하지 않음
        return;
      }
      
      // 로그인 성공 시 - 공인중개사 페이지를 새로운 userName으로 다시 열기
      if (mounted && result is Map &&
          ((result['userName'] is String && (result['userName'] as String).isNotEmpty) ||
           (result['userId'] is String && (result['userId'] as String).isNotEmpty))) {
        // ✅ 안전하게 사용자명 계산
        final String userName = (result['userName'] is String && (result['userName'] as String).isNotEmpty)
            ? result['userName']
            : result['userId'];
        
        
        // 현재 페이지를 닫고
        Navigator.pop(context);

        // 새로운 userName으로 공인중개사 페이지 다시 열기
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BrokerListPage(
              address: widget.address,
              latitude: widget.latitude,
              longitude: widget.longitude,
              userName: userName, // 로그인된 사용자
              userId: result['userId'] as String?, // userId도 전달
              propertyArea: widget.propertyArea,
              transactionType: widget.transactionType,
            ),
          ),
        );
      } else {
        // 로그인 실패 (result가 있지만 유효한 데이터가 없는 경우)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인에 실패했습니다. 이메일/비밀번호를 확인해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 게스트 모드 연락처 입력 다이얼로그
  Future<Map<String, String>?> _showGuestContactDialog() async {
    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _GuestContactDialog(),
    );
  }

  /// 계정 자동 생성 또는 로그인 (게스트 모드용)
  /// 이메일과 전화번호를 받아서 계정이 있으면 로그인, 없으면 생성 후 로그인
  Future<String?> _createOrLoginAccount(String email, String phone) async {
    try {
      // 이메일에서 ID 추출
      final id = email.split('@')[0];
      // 전화번호를 비밀번호로 사용
      final password = phone;
      
      // 계정 존재 여부 확인 (로그인 시도)
      try {
        final userData = await _firebaseService.authenticateUser(email, password);
        if (userData != null) {
          // 로그인 성공 = 계정이 이미 존재
          final uid = userData['uid'] as String?;
          if (uid != null) {
            // Analytics: 기존 계정 로그인
            AnalyticsService.instance.logEvent(
              AnalyticsEventNames.implicitAccountLogin,
              params: {'email': email},
              userId: uid,
              userName: userData['name'] as String? ?? id,
            );
          }
          return uid;
        }
      } catch (e) {
        // 로그인 실패 = 계정이 없거나 비밀번호가 틀림
        // 계정이 없을 가능성이 높으므로 새로 생성 시도
      }
      
      // 새 계정 생성
      final success = await _firebaseService.registerUser(
        id,
        password,
        id, // name
        email: email,
        phone: phone,
        role: 'user',
      );
      
      if (success) {
        // 생성 후 자동 로그인
        final userData = await _firebaseService.authenticateUser(email, password);
        if (userData != null) {
          final uid = userData['uid'] as String?;
          if (uid != null) {
            // Analytics: 새 계정 생성 성공
            AnalyticsService.instance.logEvent(
              AnalyticsEventNames.implicitAccountCreated,
              params: {'email': email},
              userId: uid,
              userName: userData['name'] as String? ?? id,
            );
          }
          return uid;
        }
      } else {
        // 계정 생성 실패 (이미 존재할 수 있음, 다시 로그인 시도)
        try {
          final userData = await _firebaseService.authenticateUser(email, password);
          if (userData != null) {
            final uid = userData['uid'] as String?;
            if (uid != null) {
              // Analytics: 계정 생성 실패 후 재로그인 성공
              AnalyticsService.instance.logEvent(
                AnalyticsEventNames.implicitAccountLogin,
                params: {'email': email, 'retryAfterCreation': true},
                userId: uid,
                userName: userData['name'] as String? ?? id,
              );
            }
            return uid;
          }
        } catch (e) {
          // 재로그인도 실패
          // Analytics: 계정 생성 및 로그인 모두 실패
          AnalyticsService.instance.logEvent(
            AnalyticsEventNames.implicitAccountCreationFailed,
            params: {'email': email, 'reason': 'both_failed'},
          );
        }
      }
      
      return null;
    } catch (e) {
      Logger.error(
        '계정 생성/로그인 실패',
        error: e,
        context: '_createOrLoginAccount',
      );
      return null;
    }
  }

  /// 비대면 견적 문의 (부동산 상담 요청서)
  void _requestQuote(Broker broker) {
    // 🔥 로그인 체크 제거 - 게스트 모드도 가능
    // 게스트 모드일 때는 상담 요청 폼에서 이메일/전화번호 입력받음
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuoteRequestFormPage(
          broker: broker,
          userName: widget.userName,
          userId: widget.userId ?? '',
          propertyAddress: widget.address, // 조회한 주소 전달
          propertyArea: widget.propertyArea, // 토지 면적 전달
          transactionType: widget.transactionType, // 거래 유형 전달
        ),
        fullscreenDialog: true,
      ),
    );
  }
  
  /// 상위 10개 공인중개사에게 원버튼 일괄 견적 요청
  /// 사용자에게 보여진 리스트(filteredBrokers)에서 현재 정렬 기준의 상위 10개를 자동 선택
  Future<void> _requestQuoteToTop10() async {
    // 🔥 로그인 체크 제거 - 게스트 모드도 가능
    if (filteredBrokers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('견적을 요청할 공인중개사가 없습니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 사용자에게 보여진 리스트(filteredBrokers)에서 상위 10개 자동 선택
    // filteredBrokers는 이미 선택된 정렬 옵션에 따라 정렬되어 있음
    final top10Brokers = filteredBrokers.take(10).toList();
    
    // 🔥 게스트 모드일 때 연락처 입력 및 계정 생성
    final isGuestMode = widget.userId == null || widget.userId!.isEmpty;
    String? userEmail;
    String? userPhone;
    String effectiveUserId = widget.userId ?? widget.userName;
    String effectiveUserName = widget.userName;
    
    if (isGuestMode) {
      final contactInfo = await _showGuestContactDialog();
      if (contactInfo == null) return; // 취소됨
      
      userEmail = contactInfo['email'];
      userPhone = contactInfo['phone'];
      
      // 계정 생성/로그인 처리
      if (userEmail == null || userPhone == null) return;
      final createdUserId = await _createOrLoginAccount(userEmail, userPhone);
      if (createdUserId != null) {
        effectiveUserId = createdUserId;
        // 사용자 이름도 업데이트
        final userData = await _firebaseService.getUser(createdUserId);
        effectiveUserName = userData?['name'] ?? userEmail.split('@')[0];
      } else {
        // 계정 생성 실패 - 게스트 모드로 진행
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계정 생성에 실패했습니다. 게스트 모드로 진행합니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // 정식 로그인 사용자
      userEmail = await _getUserEmail();
      final userData = await _firebaseService.getUser(widget.userId!);
      userPhone = userData?['phone'] as String?;
    }
    
    // 일괄 견적 요청 페이지 표시
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => _MultipleQuoteRequestDialog(
          brokerCount: top10Brokers.length,
          address: widget.address,
          propertyArea: widget.propertyArea,
          transactionType: widget.transactionType,
        ),
      ),
    );
    
    if (result == null) {
      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.quoteRequestBulkCancelled,
        params: {
          'mode': 'auto',
          'selectedCount': top10Brokers.length,
        },
        userId: effectiveUserId,
        userName: effectiveUserName,
        stage: FunnelStage.quoteRequest,
      );
      return; // 취소됨
    }
    
    // 상위 10개 중개사에게 동일한 정보로 견적 요청
    int successCount = 0;
    int failCount = 0;
    
    for (final broker in top10Brokers) {
      try {
        final quoteRequest = QuoteRequest(
          id: '',
          userId: effectiveUserId,
          userName: effectiveUserName,
          userEmail: userEmail!,
          userPhone: userPhone,
          brokerName: broker.name,
          brokerRegistrationNumber: broker.registrationNumber,
          brokerRoadAddress: broker.roadAddress,
          brokerJibunAddress: broker.jibunAddress,
          message: '부동산 상담 요청서',
          status: 'pending',
          requestDate: DateTime.now(),
          propertyType: result['propertyType'],
          propertyAddress: widget.address,
          propertyArea: result['propertyArea'],
          hasTenant: result['hasTenant'] as bool?,
          desiredPrice: result['desiredPrice'] as String?,
          targetPeriod: null,
          specialNotes: result['specialNotes'] as String?,
          // 확인할 견적 정보 (선택되지 않은 항목은 null)
          commissionRate: result['requestCommissionRate'] == true ? '' : null,
          recommendedPrice: result['requestRecommendedPrice'] == true ? '' : null,
          promotionMethod: result['requestPromotionMethod'] == true ? '' : null,
          recentCases: result['requestRecentCases'] == true ? '' : null,
        );
        
        final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);
        if (requestId != null) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }
    
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteRequestBulkAuto,
      params: {
        'targetCount': top10Brokers.length,
        'successCount': successCount,
        'failCount': failCount,
        'address': widget.address,
      },
      userId: effectiveUserId,
      userName: effectiveUserName,
      stage: FunnelStage.quoteRequest,
    );

    if (mounted) {
      // 결과 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '상위 ${top10Brokers.length}개 공인중개사에게 견적 요청 완료 (성공: $successCount곳${failCount > 0 ? " / 실패: $failCount곳" : ""})',
          ),
          backgroundColor: failCount > 0 ? Colors.orange : AirbnbColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// 여러 공인중개사에게 일괄 견적 요청 (MVP 핵심 기능)
  Future<void> _requestQuoteToMultiple() async {
    // 🔥 로그인 체크 제거 - 게스트 모드도 가능
    // 선택한 중개사 목록 가져오기
    final selectedBrokers = filteredBrokers.where((broker) {
      return _selectedBrokerIds.contains(broker.systemRegNo);
    }).toList();

    if (selectedBrokers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('견적을 요청할 공인중개사를 선택해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // 🔥 게스트 모드일 때 연락처 입력 및 계정 생성
    final isGuestMode = widget.userId == null || widget.userId!.isEmpty;
    String? userEmail;
    String? userPhone;
    String effectiveUserId = widget.userId ?? widget.userName;
    String effectiveUserName = widget.userName;
    
    if (isGuestMode) {
      final contactInfo = await _showGuestContactDialog();
      if (contactInfo == null) return; // 취소됨
      
      userEmail = contactInfo['email'];
      userPhone = contactInfo['phone'];
      
      // 계정 생성/로그인 처리
      if (userEmail == null || userPhone == null) return;
      final createdUserId = await _createOrLoginAccount(userEmail, userPhone);
      if (createdUserId != null) {
        effectiveUserId = createdUserId;
        // 사용자 이름도 업데이트
        final userData = await _firebaseService.getUser(createdUserId);
        effectiveUserName = userData?['name'] ?? userEmail.split('@')[0];
      } else {
        // 계정 생성 실패 - 게스트 모드로 진행
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('계정 생성에 실패했습니다. 게스트 모드로 진행합니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // 정식 로그인 사용자
      userEmail = await _getUserEmail();
      final userData = await _firebaseService.getUser(widget.userId!);
      userPhone = userData?['phone'] as String?;
    }
    
    // 일괄 견적 요청 페이지 표시
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => _MultipleQuoteRequestDialog(
          brokerCount: selectedBrokers.length,
          address: widget.address,
          propertyArea: widget.propertyArea,
        ),
      ),
    );
    
    if (result == null) {
      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.quoteRequestBulkCancelled,
        params: {
          'mode': 'manual',
          'selectedCount': selectedBrokers.length,
        },
        userId: effectiveUserId,
        userName: effectiveUserName,
        stage: FunnelStage.quoteRequest,
      );
      return; // 취소됨
    }
    
    // 선택한 모든 중개사에게 동일한 정보로 견적 요청
    int successCount = 0;
    int failCount = 0;
    
    for (final broker in selectedBrokers) {
      try {
        
        final quoteRequest = QuoteRequest(
          id: '',
          userId: effectiveUserId,
          userName: effectiveUserName,
          userEmail: userEmail!,
          userPhone: userPhone,
          brokerName: broker.name,
          brokerRegistrationNumber: broker.registrationNumber,
          brokerRoadAddress: broker.roadAddress,
          brokerJibunAddress: broker.jibunAddress,
          message: '부동산 상담 요청서',
          status: 'pending',
          requestDate: DateTime.now(),
          transactionType: result['transactionType'] as String?,
          propertyType: result['propertyType'],
          propertyAddress: widget.address,
          propertyArea: result['propertyArea'],
          hasTenant: result['hasTenant'] as bool?,
          desiredPrice: result['desiredPrice'] as String?,
          targetPeriod: null,
          specialNotes: result['specialNotes'] as String?,
        );
        
        
        final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);
        if (requestId != null) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }
    
    
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteRequestBulkManual,
      params: {
        'selectedCount': selectedBrokers.length,
        'successCount': successCount,
        'failCount': failCount,
        'address': widget.address,
      },
      userId: effectiveUserId,
      userName: effectiveUserName,
      stage: FunnelStage.quoteRequest,
    );

    if (mounted) {
      // 선택 모드 종료
      setState(() {
        _isSelectionMode = false;
        _selectedBrokerIds.clear();
      });

      // 확인 화면으로 이동 (현황 보기 CTA 제공)
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubmitSuccessPage(
            title: '견적 요청이 전송되었습니다',
          description: '선택한 공인중개사에게 요청을 보냈습니다.\n답변이 도착하면 현황에서 확인할 수 있어요.\n'
              '성공: $successCount곳${failCount > 0 ? " / 실패: $failCount곳" : ""}',
            userName: widget.userName,
            userId: widget.userId,
          ),
        ),
      );
    }
  }
}

/// 견적문의 폼 페이지 (부동산 상담 요청서)
class _QuoteRequestFormPage extends StatefulWidget {
  final Broker broker;
  final String userName;
  final String userId;
  final String propertyAddress;
  final String? propertyArea;
  final String? transactionType; // 거래 유형 (매매/전세/월세)
  
  const _QuoteRequestFormPage({
    required this.broker,
    required this.userName,
    required this.userId,
    required this.propertyAddress,
    this.propertyArea,
    this.transactionType,
  });
  
  @override
  State<_QuoteRequestFormPage> createState() => _QuoteRequestFormPageState();
}

class _QuoteRequestFormPageState extends State<_QuoteRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  
  // 1️⃣ 기본정보 (자동)
  String propertyType = '아파트';
  late String propertyAddress;
  late String propertyArea; // 자동 입력됨
  String transactionType = '매매'; // 거래 유형 (매매/전세/월세)
  
  // 3️⃣ 추가 정보 (소유자/임대인 입력)
  bool hasTenant = false;
  final TextEditingController _desiredPriceController = TextEditingController();
  final TextEditingController _targetPeriodController = TextEditingController();
  final TextEditingController _specialNotesController = TextEditingController();
  bool _agreeToConsent = false;
  
  // 확인할 견적 정보 선택 (기본값: 모두 선택)
  bool _requestCommissionRate = true;
  bool _requestRecommendedPrice = true;
  bool _requestPromotionMethod = true;
  bool _requestRecentCases = true;
  bool _isRequestInfoExpanded = true;
  
  @override
  void initState() {
    super.initState();
    propertyAddress = widget.propertyAddress;
    propertyArea = widget.propertyArea ?? '정보 없음';
    transactionType = widget.transactionType ?? '매매'; // 전달받은 거래 유형 또는 기본값
  }

  /// 사용자 이메일 가져오기
  Future<String> _getUserEmail() async {
    // 1. Firebase Auth에서 현재 사용자 이메일 가져오기
    final currentUser = _firebaseService.currentUser;
    if (currentUser?.email != null && currentUser!.email!.isNotEmpty) {
      return currentUser.email!;
    }

    // 2. userId가 있으면 Firestore에서 사용자 정보 조회
    if (widget.userId.isNotEmpty) {
      final userData = await _firebaseService.getUser(widget.userId);
      if (userData != null && userData['email'] != null) {
        final email = userData['email'] as String;
        if (email.isNotEmpty) {
          return email;
        }
      }
    }

    // 3. 기본값: userName 기반 이메일 (fallback)
    return '${widget.userName}@example.com';
  }
  
  @override
  void dispose() {
    _desiredPriceController.dispose();
    _targetPeriodController.dispose();
    _specialNotesController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final maxContentWidth = ResponsiveHelper.getMaxWidth(context);
    
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EAF0), // 배경을 더 진하게
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('부동산 상담 요청서'),
          backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: SafeArea(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: ListView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.all(kIsWeb ? 40.0 : 20.0),
                  children: [
            // 제목
            Text(
              '🏠 부동산 상담 요청서',
              style: AppTypography.withColor(
                AppTypography.h2,
                AirbnbColors.textPrimary,
              ),
            ),
                        SizedBox(height: AppSpacing.sm),
            Text(
              '공인중개사에게 정확한 정보를 전달하여 최적의 제안을 받으세요',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            
            SizedBox(height: AppSpacing.xl),
            
            // ========== 1️⃣ 매물 정보 (자동 입력) ==========
            _buildSectionTitle('매물 정보', '자동 입력됨', Colors.blue),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              _buildInfoRow('주소', propertyAddress),
              if (propertyArea != '정보 없음') ...[
                SizedBox(height: AppSpacing.sm),
                _buildInfoRow('면적', propertyArea),
              ],
            ]),
            
            SizedBox(height: AppSpacing.xl),
            
            // ========== 2️⃣ 매물 유형 (필수 입력) ==========
            _buildSectionTitle('매물 유형', '필수 입력', AirbnbColors.success),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              DropdownButtonFormField<String>(
                initialValue: propertyType,
                decoration: InputDecoration(
                  hintText: '매물 유형을 선택하세요',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AirbnbColors.primary, width: 2.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: '아파트', child: Text('아파트')),
                  DropdownMenuItem(value: '오피스텔', child: Text('오피스텔')),
                  DropdownMenuItem(value: '원룸', child: Text('원룸')),
                  DropdownMenuItem(value: '다세대', child: Text('다세대')),
                  DropdownMenuItem(value: '주택', child: Text('주택')),
                  DropdownMenuItem(value: '상가', child: Text('상가')),
                  DropdownMenuItem(value: '기타', child: Text('기타')),
                ],
                onChanged: (value) {
                  setState(() {
                    propertyType = value ?? '아파트';
                  });
                },
              ),
            ]),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // ========== 2️⃣ 거래 유형 (필수 입력) ==========
            _buildSectionTitle('거래 유형', '필수 입력', AirbnbColors.success),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '매매', label: Text('매매')),
                  ButtonSegment(value: '전세', label: Text('전세')),
                  ButtonSegment(value: '월세', label: Text('월세')),
                ],
                selected: {transactionType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    transactionType = newSelection.first;
                  });
                },
              ),
            ]),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // ========== 3️⃣ 확인할 견적 정보 ==========
            Container(
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AirbnbColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  AirbnbColors.cardShadowSubtle,
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 (클릭 가능)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isRequestInfoExpanded = !_isRequestInfoExpanded;
                      });
                    },
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AirbnbColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: AirbnbColors.textWhite,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  '확인할 견적 정보',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AirbnbColors.primary,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  '선택 입력',
                                  style: TextStyle(
                                    color: AirbnbColors.textSecondary,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _isRequestInfoExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: AirbnbColors.primary,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 내용 (접기/펼치기)
                  AnimatedCrossFade(
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Column(
                        children: [
                          _buildRequestItem(
                            '💰', 
                            '중개 수수료', 
                            '수수료는 얼마인가요?',
                            _requestCommissionRate,
                            (value) => setState(() => _requestCommissionRate = value),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📊', 
                            TransactionTypeHelper.getAppropriatePriceLabel(transactionType), 
                            TransactionTypeHelper.getPriceQuestion(transactionType),
                            _requestRecommendedPrice,
                            (value) => setState(() => _requestRecommendedPrice = value),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📢', 
                            '홍보 방법', 
                            '어떻게 홍보하시나요?',
                            _requestPromotionMethod,
                            (value) => setState(() => _requestPromotionMethod = value),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📋', 
                            '최근 유사 거래 사례', 
                            '유사한 거래 사례가 있나요?',
                            _requestRecentCases,
                            (value) => setState(() => _requestRecentCases = value),
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                    crossFadeState: _isRequestInfoExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // ========== 3️⃣ 추가 요청사항 (선택) ==========
            _buildSectionTitle('궁금한 점이 있으신가요?', '선택사항', AirbnbColors.primary),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '현재 세입자가 있나요? *',
                      style: AppTypography.withColor(
                        AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        AirbnbColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: hasTenant,
                    onChanged: (value) {
                      setState(() {
                        hasTenant = value;
                      });
                    },
                    activeThumbColor: AirbnbColors.primary,
                  ),
                  Text(
                    hasTenant ? '있음' : '없음',
                    style: TextStyle(
                      color: AirbnbColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              _buildTextField(
                label: '희망 거래가',
                controller: _desiredPriceController,
                hint: '예: 11억 / 협의 가능',
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: AppSpacing.md),
              _buildTextField(
                label: '기타 요청사항 (300자 이내)',
                controller: _specialNotesController,
                hint: '추가로 궁금하신 점이나 특별히 확인하고 싶은 사항을 자유롭게 적어주세요',
                maxLines: 8,
                maxLength: 300,
              ),
            ]),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // 제출 버튼
            // 동의 체크
            _buildCard([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreeToConsent,
                    onChanged: (v) => setState(() => _agreeToConsent = v ?? false),
                    activeColor: AirbnbColors.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '개인정보 제3자 제공 동의 (필수)',
                          style: AppTypography.withColor(
                            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            AirbnbColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '선택한 공인중개사에게 문의 처리 목적의 최소한의 정보가 제공됩니다. '
                          '자세한 내용은 내 정보 > 정책 및 도움말에서 확인할 수 있습니다.',
                          style: AppTypography.withColor(
                            AppTypography.caption.copyWith(height: 1.5),
                            AirbnbColors.textSecondary,
                          ),
                        ),
                            SizedBox(height: AppSpacing.xs + AppSpacing.xs / 2),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                        },
                        child: const Text('개인정보 처리방침 보기'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServicePage()));
                        },
                        child: const Text('이용약관 보기'),
                      ),
                    ],
                  ),
                ),

            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6, // 그림자 강화
                  shadowColor: AirbnbColors.primary.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.send, size: 24),
                label: const Text(
                  '견적 요청하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: AppSpacing.lg),
            
            // 웹 전용 푸터 여백 (영상 촬영용)
            if (kIsWeb) const SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // 공통 빌더 메서드 (하위 클래스에서도 사용 가능하도록 공개)
  Widget _buildSectionTitle(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_outline, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AirbnbColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
  
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
                        SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AirbnbColors.primary, width: 2.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                AirbnbColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRequestItem(String emoji, String title, String description, bool value, ValueChanged<bool>? onChanged) {
    return InkWell(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: value 
              ? AirbnbColors.primary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value 
                ? AirbnbColors.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: value ? 3 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onChanged != null) ...[
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value ? AirbnbColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: value ? AirbnbColors.primary : Colors.grey.withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                  ),
                  child: value 
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22, weight: 700)
                    : null,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: value ? const Color(0xFF1A1A1A) : AirbnbColors.primary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(
                      fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                      color: value ? const Color(0xFF2C3E50) : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 제출
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_agreeToConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('개인정보 제3자 제공 동의에 체크해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 견적문의 객체 생성
    final userEmail = await _getUserEmail();
                final quoteRequest = QuoteRequest(
      id: '',
                  userId: widget.userId.isNotEmpty ? widget.userId : widget.userName, // userId가 없으면 userName 사용
                  userName: widget.userName,
      userEmail: userEmail,
      brokerName: widget.broker.name,
      brokerRegistrationNumber: widget.broker.registrationNumber,
      brokerRoadAddress: widget.broker.roadAddress,
      brokerJibunAddress: widget.broker.jibunAddress,
      message: '부동산 상담 요청서',
                  status: 'pending',
                  requestDate: DateTime.now(),
      consentAgreed: true,
      consentAgreedAt: DateTime.now(),
      // 1️⃣ 기본정보
      transactionType: transactionType,
      propertyType: propertyType,
      propertyAddress: propertyAddress,
      propertyArea: propertyArea != '정보 없음' ? propertyArea : null,
      // 3️⃣ 추가 정보
      hasTenant: hasTenant,
      desiredPrice: _desiredPriceController.text.trim().isNotEmpty ? _desiredPriceController.text.trim() : null,
      targetPeriod: null, // 목표기간은 전자계약 이후 단계에서 사용
      specialNotes: _specialNotesController.text.trim().isNotEmpty ? _specialNotesController.text.trim() : null,
      // 확인할 견적 정보 (선택되지 않은 항목은 null)
      commissionRate: _requestCommissionRate ? '' : null,
      recommendedPrice: _requestRecommendedPrice ? '' : null,
      promotionMethod: _requestPromotionMethod ? '' : null,
      recentCases: _requestRecentCases ? '' : null,
    );
    
    // Firebase 저장
                final requestId = await _firebaseService.saveQuoteRequest(quoteRequest);

    if (requestId != null && mounted) {
      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.quoteRequestSubmitted,
        params: {
          'brokerName': widget.broker.name,
          'brokerRegNo': widget.broker.registrationNumber,
          'address': propertyAddress,
          'mode': 'single',
        },
        userId: widget.userId.isNotEmpty ? widget.userId : widget.userName,
        userName: widget.userName,
        stage: FunnelStage.quoteRequest,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubmitSuccessPage(
            title: '제안 요청이 전송되었습니다',
            description: '${widget.broker.name}에게 요청을 보냈습니다.\n답변이 도착하면 현황에서 확인할 수 있어요.',
            userName: widget.userName,
            userId: widget.userId.isNotEmpty ? widget.userId : null,
          ),
        ),
      );
    } else if (mounted) {
      AnalyticsService.instance.logEvent(
        AnalyticsEventNames.quoteRequestSubmitFailed,
        params: {
          'brokerName': widget.broker.name,
          'brokerRegNo': widget.broker.registrationNumber,
          'address': propertyAddress,
          'mode': 'single',
        },
        userId: widget.userId.isNotEmpty ? widget.userId : widget.userName,
        userName: widget.userName,
        stage: FunnelStage.quoteRequest,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제안 요청 전송에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// 여러 공인중개사에게 일괄 견적 요청 다이얼로그 (MVP 핵심 기능)
class _MultipleQuoteRequestDialog extends StatefulWidget {
  final int brokerCount;
  final String address;
  final String? propertyArea;
  final String? transactionType; // 거래 유형 (매매/전세/월세)

  const _MultipleQuoteRequestDialog({
    required this.brokerCount,
    required this.address,
    this.propertyArea,
    this.transactionType,
  });

  @override
  State<_MultipleQuoteRequestDialog> createState() => _MultipleQuoteRequestDialogState();
}

class _MultipleQuoteRequestDialogState extends State<_MultipleQuoteRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // 1️⃣ 기본정보 (자동)
  String propertyType = '아파트';
  String transactionType = '매매'; // 거래 유형 (매매/전세/월세)
  
  // 3️⃣ 추가 정보 (소유자/임대인 입력)
  bool hasTenant = false;
  final TextEditingController _desiredPriceController = TextEditingController();
  final TextEditingController _specialNotesController = TextEditingController();
  bool _agreeToConsent = false;
  bool _isRequestInfoExpanded = true; // 요청 내용 섹션 접기/펼치기 상태
  
  // 확인할 견적 정보 선택 (기본값: 모두 선택)
  bool _requestCommissionRate = true;
  bool _requestRecommendedPrice = true;
  bool _requestPromotionMethod = true;
  bool _requestRecentCases = true;

  @override
  void dispose() {
    _desiredPriceController.dispose();
    _specialNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = ResponsiveHelper.getMaxWidth(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFE8EAF0),
      appBar: AppBar(
        title: Text(widget.brokerCount == 1 
            ? '부동산 상담 요청서'
            : '${widget.brokerCount}곳에 부동산 상담 요청'),
        backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: EdgeInsets.all(kIsWeb ? 40.0 : 20.0),
              children: [
            // 제목
            Text(
              widget.brokerCount == 1 
                  ? '부동산 상담 요청서'
                  : '${widget.brokerCount}곳에 부동산 상담 요청',
              style: AppTypography.withColor(
                AppTypography.h2,
                AirbnbColors.textPrimary,
              ),
            ),
                        SizedBox(height: AppSpacing.sm),
            Text(
              widget.brokerCount == 1
                  ? '공인중개사에게 정확한 정보를 전달하여 최적의 제안을 받으세요'
                  : '선택한 공인중개사에게 일괄 전송됩니다',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            
            SizedBox(height: AppSpacing.xl),
            
            // ========== 1️⃣ 매물 정보 (자동 입력) ==========
            _buildSectionTitle('매물 정보', '자동 입력됨', Colors.blue),
            SizedBox(height: AppSpacing.md),
            _buildCard([
              _buildInfoRow('주소', widget.address),
              if (widget.propertyArea != null && widget.propertyArea != '정보 없음') ...[
                SizedBox(height: AppSpacing.sm),
                _buildInfoRow('면적', widget.propertyArea!),
              ],
            ]),
            
            SizedBox(height: AppSpacing.lg),
            
            // ========== 2️⃣ 매물 유형 (필수 입력) ==========
            _buildSectionTitle('매물 유형', '필수 입력', AirbnbColors.success),
            SizedBox(height: AppSpacing.md),
            _buildCard([
              DropdownButtonFormField<String>(
                initialValue: propertyType,
                decoration: InputDecoration(
                  hintText: '매물 유형을 선택하세요',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AirbnbColors.primary, width: 2.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: '아파트', child: Text('아파트')),
                  DropdownMenuItem(value: '오피스텔', child: Text('오피스텔')),
                  DropdownMenuItem(value: '원룸', child: Text('원룸')),
                  DropdownMenuItem(value: '다세대', child: Text('다세대')),
                  DropdownMenuItem(value: '주택', child: Text('주택')),
                  DropdownMenuItem(value: '상가', child: Text('상가')),
                  DropdownMenuItem(value: '기타', child: Text('기타')),
                ],
                onChanged: (value) {
                  setState(() {
                    propertyType = value ?? '아파트';
                  });
                },
              ),
            ]),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // ========== 2️⃣ 거래 유형 (필수 입력) ==========
            _buildSectionTitle('거래 유형', '필수 입력', AirbnbColors.success),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '매매', label: Text('매매')),
                  ButtonSegment(value: '전세', label: Text('전세')),
                  ButtonSegment(value: '월세', label: Text('월세')),
                ],
                selected: {transactionType},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    transactionType = newSelection.first;
                  });
                },
              ),
            ]),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // 확인할 견적 정보 안내 (접기/펼치기 가능)
            Container(
              decoration: BoxDecoration(
                color: AirbnbColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AirbnbColors.primary.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  AirbnbColors.cardShadowSubtle,
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 (클릭 가능)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isRequestInfoExpanded = !_isRequestInfoExpanded;
                      });
                    },
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AirbnbColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: AirbnbColors.textWhite,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  '확인할 견적 정보',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AirbnbColors.primary,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text(
                                  '선택 입력',
                                  style: TextStyle(
                                    color: AirbnbColors.textSecondary,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _isRequestInfoExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: AirbnbColors.primary,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 내용 (접기/펼치기)
                  AnimatedCrossFade(
                    firstChild: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      child: Column(
                        children: [
                          _buildRequestItem(
                            '💰', 
                            '중개 수수료', 
                            '수수료는 얼마인가요?',
                            _requestCommissionRate,
                            (value) => setState(() => _requestCommissionRate = value),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📊', 
                            TransactionTypeHelper.getAppropriatePriceLabel(transactionType), 
                            TransactionTypeHelper.getPriceQuestion(transactionType),
                            _requestRecommendedPrice,
                            (value) => setState(() => _requestRecommendedPrice = value),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📢', 
                            '홍보 방법', 
                            '어떻게 홍보하시나요?',
                            _requestPromotionMethod,
                            (value) => setState(() => _requestPromotionMethod = value),
                          ),
                          SizedBox(height: AppSpacing.sm),
                          _buildRequestItem(
                            '📋', 
                            '최근 유사 거래 사례', 
                            '유사한 거래 사례가 있나요?',
                            _requestRecentCases,
                            (value) => setState(() => _requestRecentCases = value),
                          ),
                        ],
                      ),
                    ),
                    secondChild: const SizedBox.shrink(),
                    crossFadeState: _isRequestInfoExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // ========== 3️⃣ 추가 요청사항 (선택) ==========
            _buildSectionTitle('궁금한 점이 있으신가요?', '선택사항', AirbnbColors.primary),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            _buildCard([
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '현재 세입자가 있나요? *',
                      style: AppTypography.withColor(
                        AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                        AirbnbColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: hasTenant,
                    onChanged: (value) {
                      setState(() {
                        hasTenant = value;
                      });
                    },
                    activeThumbColor: AirbnbColors.primary,
                  ),
                  Text(
                    hasTenant ? '있음' : '없음',
                    style: TextStyle(
                      color: AirbnbColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              _buildTextField(
                label: '희망 거래가',
                controller: _desiredPriceController,
                hint: '예: 11억 / 협의 가능',
                keyboardType: TextInputType.text,
              ),
              SizedBox(height: AppSpacing.md),
              _buildTextField(
                label: '기타 요청사항 (300자 이내)',
                controller: _specialNotesController,
                hint: '추가로 궁금하신 점이나 특별히 확인하고 싶은 사항을 자유롭게 적어주세요',
                maxLines: 8,
                maxLength: 300,
              ),
            ]),
            
            SizedBox(height: AppSpacing.lg),
            Divider(color: AirbnbColors.borderLight, thickness: 1, height: 1),
            SizedBox(height: AppSpacing.lg),
            
            // 제출 버튼
            // 동의 체크
            _buildCard([
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreeToConsent,
                    onChanged: (v) => setState(() => _agreeToConsent = v ?? false),
                    activeColor: AirbnbColors.primary,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '개인정보 제3자 제공 동의 (필수)',
                          style: AppTypography.withColor(
                            AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            AirbnbColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '선택한 공인중개사에게 문의 처리 목적의 최소한의 정보가 제공됩니다. '
                          '자세한 내용은 내 정보 > 정책 및 도움말에서 확인할 수 있습니다.',
                          style: AppTypography.withColor(
                            AppTypography.caption.copyWith(height: 1.5),
                            AirbnbColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ]),
            SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                    },
                    child: const Text('개인정보 처리방침 보기'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServicePage()));
                    },
                    child: const Text('이용약관 보기'),
                  ),
                ],
              ),
            ),

            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    if (!_agreeToConsent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('개인정보 제3자 제공 동의에 체크해주세요.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'transactionType': transactionType,
                      'propertyType': propertyType,
                      'propertyArea': widget.propertyArea != '정보 없음' ? widget.propertyArea : null,
                      'hasTenant': hasTenant,
                      'desiredPrice': _desiredPriceController.text.trim().isNotEmpty
                          ? _desiredPriceController.text.trim()
                          : null,
                      'specialNotes': _specialNotesController.text.trim().isNotEmpty
                          ? _specialNotesController.text.trim()
                          : null,
                      'consentAgreed': true,
                      // 확인할 견적 정보 선택
                      'requestCommissionRate': _requestCommissionRate,
                      'requestRecommendedPrice': _requestRecommendedPrice,
                      'requestPromotionMethod': _requestPromotionMethod,
                      'requestRecentCases': _requestRecentCases,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  shadowColor: AirbnbColors.primary.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.send, size: 24),
                label: Text(
                  widget.brokerCount == 1 
                      ? '부동산 상담 요청 전송'
                      : '${widget.brokerCount}곳에 부동산 상담 요청 전송',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            
            SizedBox(height: AppSpacing.lg),
            
            // 웹 전용 푸터 여백 (영상 촬영용)
            if (kIsWeb) const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info_outline, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AirbnbColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
                AirbnbColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
                        SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixText: suffix,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AirbnbColors.primary, width: 2.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestItem(String emoji, String title, String description, bool value, ValueChanged<bool>? onChanged) {
    return InkWell(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: value 
              ? AirbnbColors.primary.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value 
                ? AirbnbColors.primary
                : Colors.grey.withValues(alpha: 0.3),
            width: value ? 3 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onChanged != null) ...[
              IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: value ? AirbnbColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: value ? AirbnbColors.primary : Colors.grey.withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                  ),
                  child: value 
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22, weight: 700)
                    : null,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: value ? const Color(0xFF1A1A1A) : AirbnbColors.primary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: TextStyle(
                      fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                      color: value ? const Color(0xFF2C3E50) : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 에어비엔비 스타일 액션 카드 위젯 (호버/클릭 피드백 포함)
class _ActionCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool enabled;
  final List<Color> gradient;
  final String badge;
  final double cardHeight;
  final VoidCallback? onTap;
  final VoidCallback? onTapDisabled;
  final bool requiresLogin; // 로그인 필요 여부 (시각적 구분용)

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.gradient,
    required this.badge,
    required this.cardHeight,
    this.onTap,
    this.onTapDisabled,
    this.requiresLogin = false,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // 에어비엔비 스타일: 비활성화 상태를 명확하게 구분
    // 활성화: 원래 색상, 비활성화: 흰색 배경 + 회색 테두리 (로그인 필요 여부와 관계없이)
    final bool isDisabled = !widget.enabled;
    
    // 활성화 상태: 원래 그라데이션 색상
    // 비활성화 상태: 흰색 배경 + 회색 테두리 (에어비엔비 스타일)
    final Color cardColor = isDisabled 
        ? AirbnbColors.background  // 흰색 배경
        : widget.gradient[0];
    
    final Color borderColor = isDisabled
        ? (widget.requiresLogin 
            ? AirbnbColors.primary.withValues(alpha: 0.3)  // 로그인 필요: 보라색 테두리 (연하게)
            : AirbnbColors.border)  // 일반 비활성화: 회색 테두리
        : (_isHovered 
            ? widget.gradient[0].withValues(alpha: 0.8) 
            : widget.gradient[0].withValues(alpha: 0.3));
    
    final Color textColor = isDisabled
        ? AirbnbColors.textSecondary  // 비활성화: 회색 텍스트
        : AirbnbColors.textWhite;  // 활성화: 흰색 텍스트
    
    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled) {
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.enabled) {
            setState(() => _isPressed = true);
          }
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (widget.enabled && widget.onTap != null) {
            widget.onTap!();
          } else if (widget.onTapDisabled != null) {
            widget.onTapDisabled!();
          }
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: widget.cardHeight,
          transform: Matrix4.identity()
            ..scale(_isPressed ? 0.98 : (_isHovered && widget.enabled ? 1.02 : 1.0)),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isDisabled 
                  ? (widget.requiresLogin ? 2.0 : 1.5)  // 로그인 필요: 더 두꺼운 테두리
                  : (_isHovered && widget.enabled ? 2 : 1.5),
            ),
            boxShadow: widget.enabled
                ? (_isHovered 
                    ? [AirbnbColors.cardShadowHover]
                    : [AirbnbColors.cardShadow])
                : [AirbnbColors.cardShadowSubtle],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.enabled ? widget.onTap : (widget.onTapDisabled ?? () {}),
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 배경 아이콘 (가시성 개선)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: IgnorePointer(
                      child: Icon(
                        widget.icon,
                        size: ResponsiveHelper.isMobile(context) ? 70 : 90,
                        color: isDisabled
                            ? AirbnbColors.textLight.withValues(alpha: 0.15)  // 비활성화: 매우 연한 회색
                            : Colors.white.withValues(alpha: 0.18),  // 활성화: 연한 흰색
                      ),
                    ),
                  ),
                  // 메인 콘텐츠
                  Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 상단
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 배지
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm + 2,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDisabled
                                      ? (widget.requiresLogin 
                                          ? AirbnbColors.primary.withValues(alpha: 0.1)  // 로그인 필요: 연한 보라색
                                          : AirbnbColors.surface)  // 일반 비활성화: 회색 배경
                                      : Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: isDisabled
                                      ? (widget.requiresLogin
                                          ? Border.all(
                                              color: AirbnbColors.primary.withValues(alpha: 0.3),
                                              width: 1,
                                            )
                                          : Border.all(
                                              color: AirbnbColors.border,
                                              width: 1,
                                            ))
                                      : Border.all(
                                          color: Colors.white.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                ),
                                child: Text(
                                  widget.badge,
                                  style: AppTypography.withColor(
                                    AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    isDisabled
                                        ? (widget.requiresLogin 
                                            ? AirbnbColors.primary  // 로그인 필요: 보라색
                                            : AirbnbColors.textSecondary)  // 일반 비활성화: 회색
                                        : AirbnbColors.textWhite,
                                  ),
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.isMobile(context) ? 8 : 12),
                              // 제목
                              Text(
                                widget.title,
                                style: AppTypography.withColor(
                                  AppTypography.h3.copyWith(
                                    fontSize: ResponsiveHelper.isMobile(context) ? 18 : 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    height: 1.2,
                                  ),
                                  textColor,
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.isMobile(context) ? 4 : 6),
                              // 설명
                              Flexible(
                                child: Text(
                                  widget.description,
                                  style: AppTypography.withColor(
                                    AppTypography.caption.copyWith(
                                      fontSize: ResponsiveHelper.isMobile(context) ? 11 : 13,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    isDisabled
                                        ? AirbnbColors.textSecondary  // 비활성화: 회색
                                        : textColor.withValues(alpha: 0.95),  // 활성화: 흰색
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 하단 CTA
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Row(
                            children: [
                              // 로그인 필요 아이콘 표시
                              if (isDisabled && widget.requiresLogin) ...[
                                Icon(
                                  Icons.lock_outline_rounded,
                                  color: AirbnbColors.primary,
                                  size: ResponsiveHelper.isMobile(context) ? 14 : 16,
                                ),
                                const SizedBox(width: 4),
                              ],
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: Matrix4.translationValues(
                                  _isHovered && widget.enabled ? 4.0 : 0.0,
                                  0.0,
                                  0.0,
                                ),
                                child: Icon(
                                  widget.enabled 
                                      ? Icons.arrow_forward_rounded
                                      : (widget.requiresLogin 
                                          ? Icons.login_rounded 
                                          : Icons.info_outline_rounded),
                                  color: isDisabled
                                      ? (widget.requiresLogin 
                                          ? AirbnbColors.primary  // 로그인 필요: 보라색
                                          : AirbnbColors.textSecondary)  // 일반 비활성화: 회색
                                      : textColor,
                                  size: ResponsiveHelper.isMobile(context) ? 15 : 18,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.enabled 
                                    ? '바로 실행' 
                                    : (widget.requiresLogin 
                                        ? '로그인 필요' 
                                        : '사용 불가'),
                                style: AppTypography.withColor(
                                  AppTypography.caption.copyWith(
                                    fontSize: ResponsiveHelper.isMobile(context) ? 12 : 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  isDisabled
                                      ? (widget.requiresLogin 
                                          ? AirbnbColors.primary  // 로그인 필요: 보라색
                                          : AirbnbColors.textSecondary)  // 일반 비활성화: 회색
                                      : textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 게스트 모드 연락처 입력 다이얼로그 (StatefulWidget으로 분리하여 TextEditingController 관리)
class _GuestContactDialog extends StatefulWidget {
  const _GuestContactDialog();

  @override
  State<_GuestContactDialog> createState() => _GuestContactDialogState();
}

class _GuestContactDialogState extends State<_GuestContactDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.contact_mail, color: AirbnbColors.primary, size: 24),
          SizedBox(width: 12),
          Text('연락처 정보', style: AppTypography.h4),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일 *',
                  hintText: '예: user@example.com',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력해주세요';
                  }
                  if (!ValidationUtils.isValidEmail(value)) {
                    return '올바른 이메일 형식을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호 *',
                  hintText: '예: 01012345678',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '전화번호를 입력해주세요';
                  }
                  final cleanPhone = value.replaceAll('-', '').replaceAll(' ', '').trim();
                  if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(cleanPhone)) {
                    return '올바른 전화번호 형식을 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '공인중개사의 상담 응답을 받을 연락처를 적어주세요.\n상담 이후 응답은 내집관리에서 확인 가능합니다.',
                        style: TextStyle(fontSize: 12, color: Colors.blue, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final cleanPhone = _phoneController.text
                  .replaceAll('-', '')
                  .replaceAll(' ', '')
                  .trim();
              Navigator.pop(context, {
                'email': _emailController.text.trim(),
                'phone': cleanPhone,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.textPrimary,
            foregroundColor: AirbnbColors.background,
          ),
          child: const Text('확인'),
        ),
      ],
    );
  }
}


