import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/log_service.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:property/utils/logger.dart';
import 'home_page.dart';
import 'userInfo/personal_info_page.dart';
import 'propertyMgmt/house_management_page.dart';
import 'propertySale/house_market_page.dart';
import 'login_page.dart';
import 'broker/broker_dashboard_page.dart';
import 'notification/notification_page.dart';

class MainPage extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTabIndex;

  const MainPage({
    required this.userId,
    required this.userName,
    this.initialTabIndex = 0,
    super.key,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final LogService _logService = LogService();
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  bool _isBroker = false;
  Map<String, dynamic>? _brokerData;

  // AppBar 캐싱을 위한 변수
  PreferredSizeWidget? _cachedAppBar;
  bool? _lastIsMobile;
  bool? _lastIsBroker;
  bool? _lastHasUserId;

  // 로드된 페이지 캐시 (상태 유지)
  final Map<int, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTabIndex;
    if (initialIndex >= 0 && initialIndex < 4) {
      _currentIndex = initialIndex;
    } else {
      _currentIndex = 0;
    }
    // 사용자 정보는 백그라운드에서 로드 (UI 블로킹 없음)
    _loadUserData();
    _checkBrokerRole();
  }

  Future<void> _checkBrokerRole() async {
    if (widget.userId.isEmpty) return;
    try {
      final data = await _firebaseService.getBroker(widget.userId);
      if (!mounted) return;
      if (data != null) {
        setState(() {
          _isBroker = true;
          _brokerData = data;
        });
      }
    } catch (e) {
      // 브로커 확인 중 오류 발생 시 로깅
      Logger.warning(
        '브로커 정보 확인 중 오류 발생',
        metadata: {'error': e.toString()},
      );
    }
  }

  /// 지연 로딩: 탭을 선택할 때만 페이지 생성
  /// 메모리 사용량을 크게 줄이고 초기 로딩 시간 단축
  Widget _getPage(int index) {
    // 캐시에 있으면 재사용
    if (_pageCache.containsKey(index)) {
      return _pageCache[index]!;
    }

    // 페이지 생성 및 캐싱
    Widget page;
    switch (index) {
      case 0:
        page = HomePage(
          key: ValueKey('home_${widget.userId}_${widget.userName}'),
          userId: widget.userId,
          userName: widget.userName,
        );
        break;
      case 1:
        page = HouseMarketPage(
          key: ValueKey('market_${widget.userName}'),
          userName: widget.userName,
        );
        break;
      case 2:
        page = HouseManagementPage(
          key: ValueKey('management_${widget.userId}_${widget.userName}'),
          userId: widget.userId,
          userName: widget.userName,
        );
        break;
      case 3:
        page = PersonalInfoPage(
          key: ValueKey('info_${widget.userId}_${widget.userName}'),
          userId: widget.userId,
          userName: widget.userName,
        );
        break;
      default:
        page = HomePage(
          key: ValueKey('home_${widget.userId}_${widget.userName}'),
          userId: widget.userId,
          userName: widget.userName,
        );
    }

    _pageCache[index] = page;
    return page;
  }

  /// 사용자 정보를 백그라운드에서 비동기로 로드
  /// UI를 블로킹하지 않고 즉시 표시
  Future<void> _loadUserData() async {
    // userId가 없으면 로드할 필요 없음
    if (widget.userId.isEmpty) {
      return;
    }
    
    try {
      // 백그라운드에서 사용자 정보 로드 (에러는 무시)
      await _firebaseService.getUser(widget.userId);
    } catch (e) {
      // 사용자 정보 로드 실패는 무시하고 계속 진행
      // UI는 이미 표시되었으므로 문제없음
      Logger.warning(
        '사용자 정보 로드 실패',
        metadata: {'error': e.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI를 즉시 표시 (사용자 정보 로드는 백그라운드에서 처리)
    return Scaffold(
      backgroundColor: AirbnbColors.background,
      appBar: _buildTopNavigationBar(),
      // 지연 로딩: 현재 탭만 렌더링 (메모리 최적화)
      body: _getPage(_currentIndex),
    );
  }

  PreferredSizeWidget _buildTopNavigationBar() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final hasUserId = widget.userId.isNotEmpty;
    
    // AppBar 캐싱: 조건이 같으면 재사용
    if (_cachedAppBar != null &&
        _lastIsMobile == isMobile &&
        _lastIsBroker == _isBroker &&
        _lastHasUserId == hasUserId) {
      return _cachedAppBar!;
    }

    _lastIsMobile = isMobile;
    _lastIsBroker = _isBroker;
    _lastHasUserId = hasUserId;

    _cachedAppBar = AppBar(
      backgroundColor: AirbnbColors.background,
      foregroundColor: AirbnbColors.textPrimary,
      elevation: 0,
      toolbarHeight: 70,
      shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      title: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
      actions: [
        if (widget.userId.isNotEmpty)
          AccessibleWidget.iconButton(
            icon: Icons.notifications_outlined,
            color: AirbnbColors.textPrimary,
            tooltip: '알림',
            semanticLabel: '알림 보기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPage(userId: widget.userId),
                ),
              );
            },
          ),
        if (_isBroker)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {
                final brokerId = _brokerData?['brokerId'] as String? ??
                    widget.userId;
                final brokerName =
                    _brokerData?['ownerName'] as String? ??
                        _brokerData?['businessName'] as String? ??
                        widget.userName;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => BrokerDashboardPage(
                      brokerId: brokerId,
                      brokerName: brokerName,
                      brokerData: {
                        ...?_brokerData,
                        'uid': widget.userId,
                        'brokerId': brokerId,
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.business, size: 20, color: AirbnbColors.primary),
              label: Text(
                '중개사 대시보드',
                style: AppTypography.withColor(
                  AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  AirbnbColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
    
    return _cachedAppBar!;
  }

  Widget _buildMobileHeader() {
    // 모바일 화면 최적화
    // ResponsiveHelper는 이미 _buildTopNavigationBar에서 호출됨
    const horizontalGap = AppSpacing.xs;

    // 모바일에서는 항상 화면 폭 안에 4개의 탭이 모두 보이도록
    // 가로 스크롤을 없애고 Expanded 로 균등 분배한다.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildNavButton(
              '집 내놓기',
              0,
              Icons.add_home_rounded,
              isMobile: true,
              showLabelOnly: true,
            ),
          ),
          const SizedBox(width: horizontalGap),
          Expanded(
            child: _buildNavButton(
              '집 구하기',
              1,
              Icons.search_rounded,
              isMobile: true,
              showLabelOnly: true,
            ),
          ),
          const SizedBox(width: horizontalGap),
          Expanded(
            child: _buildNavButton(
              '내집관리',
              2,
              Icons.home_work_rounded,
              isMobile: true,
              showLabelOnly: true,
            ),
          ),
          const SizedBox(width: horizontalGap),
          Expanded(
            child: _buildNavButton(
              '내 정보',
              3,
              Icons.person_rounded,
              isMobile: true,
              showLabelOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader() {
    final isLoggedIn = widget.userName.isNotEmpty;

    return Row(
      children: [
        // 로고
        LogoWithText(
          fontSize: AppTypography.h2.fontSize!,
          logoHeight: 60,
          textColor: AirbnbColors.primary,
          onTap: () {
            // 첫 번째 탭(홈)으로 이동
            setState(() {
              _currentIndex = 0;
            });
          },
        ),
        const SizedBox(width: 24),

        // 네비게이션 메뉴
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _buildNavButton('집 내놓기', 0, Icons.add_home_rounded),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildNavButton('집 구하기', 1, Icons.search_rounded),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildNavButton('내집관리', 2, Icons.home_work_rounded),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: _buildNavButton('내 정보', 3, Icons.person_rounded),
              ),
            ],
          ),
        ),

        // 로그인/로그아웃 버튼
        _buildAuthButton(isLoggedIn),
      ],
    );
  }

  Widget _buildAuthButton(bool isLoggedIn) {
    return InkWell(
      onTap: () {
        if (isLoggedIn) {
          _logout();
        } else {
          _login();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AirbnbColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AirbnbColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLoggedIn ? Icons.logout : Icons.login,
              color: AirbnbColors.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              isLoggedIn ? '로그아웃' : '로그인',
              style: AppTypography.withColor(
                AppTypography.buttonSmall.copyWith(fontWeight: FontWeight.w600),
                AirbnbColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login({int? targetIndex}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );

    // 사용자가 뒤로가기로 취소한 경우 (result가 null)
    if (result == null) {
      // 취소한 경우는 아무 메시지도 표시하지 않음
      return;
    }

    // 로그인 성공 시 사용자 정보를 받아서 페이지 새로고침
    if (result is Map &&
        ((result['userId'] is String &&
                (result['userId'] as String).isNotEmpty) ||
            (result['userName'] is String &&
                (result['userName'] as String).isNotEmpty))) {
      final String userId =
          (result['userId'] is String &&
              (result['userId'] as String).isNotEmpty)
          ? result['userId']
          : result['userName'];
      final String userName =
          (result['userName'] is String &&
              (result['userName'] as String).isNotEmpty)
          ? result['userName']
          : result['userId'];

      // 공인중개사 로그인인 경우 BrokerDashboardPage로 이동
      if (result['userType'] == 'broker' && result['brokerData'] != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => BrokerDashboardPage(
                brokerId: userId,
                brokerName: userName,
                brokerData: result['brokerData'],
              ),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MainPage(
              userId: userId,
              userName: userName,
              initialTabIndex: targetIndex ?? 0,
            ),
          ),
        );
      }
    } else {
      // 로그인 실패 (result가 있지만 유효한 데이터가 없는 경우)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인에 실패했습니다. 이메일/전화번호를 확인해주세요.', style: AppTypography.body),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const MainPage(userId: '', userName: ''),
                ),
              );
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(
    String label,
    int index,
    IconData icon, {
    bool isMobile = false,
    bool showLabelOnly = true,
  }) {
    final isSelected = _currentIndex == index;
    final isLoggedIn = widget.userName.isNotEmpty;

    return InkWell(
      onTap: () {
        // 로그인이 필요한 페이지 (현재 탭 구성: 0=집 내놓기, 1=집 구하기, 2=내집관리, 3=내 정보)
        // 집 구하기(1번 탭)는 비로그인도 사용 가능, 내집관리/내 정보(2,3)는 로그인 필요
        if (!isLoggedIn && index >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 필요한 서비스입니다.'),
              backgroundColor: AirbnbColors.warning,
              duration: Duration(seconds: 2),
            ),
          );
          _login(targetIndex: index);
          return;
        }

        setState(() {
          _currentIndex = index;
        });
        
        // 탭 전환 로깅
        String tabName = '';
        switch (index) {
          case 0: tabName = 'HomePage'; break;
          case 1: tabName = 'HouseMarketPage'; break;
          case 2: tabName = 'HouseManagementPage'; break;
          case 3: tabName = 'PersonalInfoPage'; break;
        }
        _logService.logScreenView(tabName, screenClass: 'MainPageTab');
      },
      borderRadius: BorderRadius.circular(8),
      child: Builder(
        builder: (context) {
          // MediaQuery를 한 번만 호출하여 최적화
          final screenWidth = MediaQuery.of(context).size.width;
          final isSmallScreen = screenWidth < 600;
          
          final fontSize = isSmallScreen 
              ? AppTypography.caption.fontSize! 
              : (isMobile ? AppTypography.bodySmall.fontSize! : AppTypography.buttonSmall.fontSize!);
          final iconSize = isSmallScreen ? 18.0 : (isMobile ? 22.0 : 20.0);
          final horizontalPadding = isSmallScreen ? 1.0 : (isMobile ? 4.0 : 16.0);
          final iconTextGap = isSmallScreen ? 2.0 : (isMobile ? 4.0 : 6.0);
          
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isMobile ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AirbnbColors.primaryDark.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AirbnbColors.primaryDark : Colors.transparent,
                width: isSelected ? 1.5 : 0,
              ),
            ),
            child: Row(
              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? AirbnbColors.primaryDark : AirbnbColors.textSecondary,
                  size: iconSize,
                ),
                if (showLabelOnly) ...[
                  SizedBox(width: iconTextGap),
                  Flexible(
                    child: Text(
                      label,
                      style: AppTypography.withColor(
                        (isMobile ? AppTypography.bodySmall : AppTypography.buttonSmall).copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: fontSize,
                          letterSpacing: isSmallScreen ? -0.3 : 0,
                        ),
                        isSelected ? AirbnbColors.primaryDark : AirbnbColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    // 페이지 캐시 정리
    _pageCache.clear();
    super.dispose();
  }
}
