import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property/constants/apple_design_system.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/api_request/log_service.dart';
import 'package:property/utils/logger.dart';
import 'login_page.dart';
import 'auth/auth_landing_page.dart';
import 'broker/mls_broker_dashboard_page.dart';
import 'seller/mls_seller_dashboard_page.dart';
import 'seller/mls_quick_registration_page.dart';
import 'notification/notification_page.dart';

class MainPage extends StatefulWidget {
  final String userId;
  final String userName;
  final int initialTabIndex;

  const MainPage({
    required this.userId,
    required this.userName,
    this.initialTabIndex = -1, // -1 = 컨텍스트 기반 자동 결정
    super.key,
  });

  @override
  State<MainPage> createState() => MainPageState();
}

// LandingPage에서 접근할 수 있도록 public으로 변경
class MainPageState extends State<MainPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final LogService _logService = LogService();
  int _currentIndex = 0; // 현재 선택된 탭 인덱스

  bool _isBroker = false;
  Map<String, dynamic>? _brokerData;

  // 알림 배지용 읽지 않은 알림 개수
  int _unreadNotificationCount = 0;
  StreamSubscription<int>? _notificationSubscription;

  // AppBar 캐싱을 위한 변수
  PreferredSizeWidget? _cachedAppBar;
  bool? _lastIsMobile;
  bool? _lastIsBroker;
  bool? _lastHasUserId;
  int? _lastUnreadCount;

  // 로드된 페이지 캐시 (상태 유지)
  final Map<int, Widget> _pageCache = {};

  @override
  void initState() {
    super.initState();
    // 컨텍스트 기반 초기 탭 설정
    _currentIndex = _getContextBasedInitialTab();
    // 사용자 정보는 백그라운드에서 로드 (UI 블로킹 없음)
    _loadUserData();
    _checkBrokerRole();
    // 알림 배지 업데이트를 위한 스트림 구독
    _subscribeToNotifications();
  }

  /// 알림 개수 스트림 구독
  void _subscribeToNotifications() {
    if (widget.userId.isEmpty) return;
    _notificationSubscription = _firebaseService
        .getUnreadNotificationCount(widget.userId)
        .listen((count) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    });
  }

  /// 컨텍스트 기반 초기 탭 결정
  /// 항상 "등록" 탭(0)으로 시작 - 헤이딜러 스타일
  int _getContextBasedInitialTab() {
    // 명시적 initialTabIndex가 있으면 우선 사용 (0 또는 1)
    if (widget.initialTabIndex >= 0 && widget.initialTabIndex < 2) {
      return widget.initialTabIndex;
    }
    // 기본: 등록 탭 (Tab 0) - 메인 CTA
    return 0;
  }

  /// 외부에서 탭 전환을 위한 메서드
  void setCurrentTab(int index) {
    if (index >= 0 && index < 2) {
      // AppBar 캐시 무효화하여 탭 변경 반영
      _cachedAppBar = null;
      setState(() {
        _currentIndex = index;
      });
    }
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

    // 페이지 생성 및 캐싱 (2탭 구조: 등록 / 내 매물) - 헤이딜러 스타일
    Widget page;
    switch (index) {
      case 0:
        // 빠른 등록 (30초 등록) - 메인 CTA
        page = MLSQuickRegistrationPage(
          key: const ValueKey('mls_quick_registration'),
          onRegistrationComplete: () {
            // 등록 완료 후 "내 매물" 탭으로 이동
            setCurrentTab(1);
          },
        );
        break;
      case 1:
        // 내 매물 (등록한 매물 관리)
        page = const MLSSellerDashboardPage(
          key: ValueKey('mls_seller_dashboard'),
        );
        break;
      default:
        page = MLSQuickRegistrationPage(
          key: const ValueKey('mls_quick_registration'),
          onRegistrationComplete: () {
            setCurrentTab(1);
          },
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
      backgroundColor: AppleColors.systemGroupedBackground,
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
        _lastHasUserId == hasUserId &&
        _lastUnreadCount == _unreadNotificationCount) {
      return _cachedAppBar!;
    }

    _lastIsMobile = isMobile;
    _lastIsBroker = _isBroker;
    _lastHasUserId = hasUserId;
    _lastUnreadCount = _unreadNotificationCount;

    _cachedAppBar = AppBar(
      backgroundColor: AppleColors.systemBackground,
      foregroundColor: AppleColors.label,
      elevation: 0,
      toolbarHeight: isMobile ? 56 : 64,
      shadowColor: AppleColors.separator.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      title: isMobile ? _buildMobileHeader() : _buildDesktopHeader(),
      actions: isMobile ? _buildMobileActions() : null,
    );

    return _cachedAppBar!;
  }

  List<Widget> _buildMobileActions() {
    return [
      // 알림 (뱃지 포함)
      if (widget.userId.isNotEmpty)
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 24),
              color: AppleColors.label,
              tooltip: '알림',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationPage(userId: widget.userId),
                  ),
                );
              },
            ),
            if (_unreadNotificationCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppleColors.systemRed,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                    style: AppleTypography.caption2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      // 중개사 대시보드 (중개사만)
      if (_isBroker)
        IconButton(
          icon: const Icon(Icons.business_rounded, size: 24),
          color: AppleColors.systemBlue,
          tooltip: '중개사 대시보드',
          onPressed: () {
            final brokerId = _brokerData?['brokerId'] as String? ?? widget.userId;
            final brokerName = _brokerData?['ownerName'] as String? ??
                _brokerData?['businessName'] as String? ?? widget.userName;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => MLSBrokerDashboardPage(
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
        ),
      // 프로필/설정 (1클릭 접근)
      IconButton(
        icon: const Icon(Icons.person_outline, size: 24),
        color: AppleColors.label,
        tooltip: '프로필',
        onPressed: () => _showProfileSheet(),
      ),
      const SizedBox(width: 4),
    ];
  }

  /// 프로필/설정 바텀시트
  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildProfileSheet(),
    );
  }

  Widget _buildProfileSheet() {
    final isLoggedIn = widget.userId.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: AppleColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들바
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppleColors.separator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // 프로필 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppleColors.systemBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(
                    isLoggedIn ? Icons.person : Icons.person_outline,
                    color: AppleColors.systemBlue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoggedIn ? widget.userName : '로그인이 필요합니다',
                        style: AppleTypography.title3.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isLoggedIn && _isBroker)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppleColors.systemBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '공인중개사',
                            style: AppleTypography.caption1.copyWith(
                              color: AppleColors.systemBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppleColors.secondaryLabel),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 메뉴 아이템
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (isLoggedIn) ...[
                  _buildProfileMenuItem(
                    icon: Icons.person_outline,
                    label: '내 정보',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/personal-info');
                    },
                  ),
                  if (_isBroker)
                    _buildProfileMenuItem(
                      icon: Icons.store_outlined,
                      label: '중개사 프로필 관리',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/broker-settings');
                      },
                    ),
                  _buildProfileMenuItem(
                    icon: Icons.history,
                    label: '활동 내역',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/quote-history');
                    },
                  ),
                  const Divider(indent: 56),
                  _buildProfileMenuItem(
                    icon: Icons.help_outline,
                    label: '도움말',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: 도움말 페이지
                    },
                  ),
                  _buildProfileMenuItem(
                    icon: Icons.logout,
                    label: '로그아웃',
                    color: AppleColors.systemRed,
                    onTap: () async {
                      Navigator.pop(context);
                      await _firebaseService.signOut();
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const AuthLandingPage()),
                        );
                      }
                    },
                  ),
                ] else ...[
                  _buildProfileMenuItem(
                    icon: Icons.login,
                    label: '로그인',
                    onTap: () {
                      Navigator.pop(context);
                      _login();
                    },
                  ),
                  _buildProfileMenuItem(
                    icon: Icons.person_add_outlined,
                    label: '회원가입',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/signup');
                    },
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppleColors.label, size: 22),
      title: Text(
        label,
        style: AppleTypography.body.copyWith(
          color: color ?? AppleColors.label,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppleColors.tertiaryLabel, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildMobileHeader() {
    return Row(
      children: [
        // 로고
        GestureDetector(
          onTap: () => setState(() => _currentIndex = 0),
          child: Text(
            'MyHome',
            style: AppleTypography.title2.copyWith(
              fontWeight: FontWeight.w700,
              color: AppleColors.systemBlue,
            ),
          ),
        ),
        // 중앙 탭 버튼 (헤이딜러 스타일)
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCompactNavButton('등록', 0, Icons.sell_outlined),
              const SizedBox(width: 8),
              _buildCompactNavButton('내 매물', 1, Icons.home_outlined),
            ],
          ),
        ),
        // 우측 여백 (actions와 균형)
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildCompactNavButton(String label, int index, IconData icon) {
    final isSelected = _currentIndex == index;
    final isLoggedIn = widget.userName.isNotEmpty;
    // 모든 탭이 로그인 필요 (2탭 구조: 등록, 내 매물)
    const requiresLogin = true;
    // "내 매물" 탭(index 1)에 배지 표시
    final showBadge = index == 1 && _unreadNotificationCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isLoggedIn && requiresLogin) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('로그인이 필요합니다.', style: AppleTypography.body.copyWith(color: Colors.white)),
                backgroundColor: AppleColors.systemOrange,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _login(targetIndex: index);
            return;
          }
          // AppBar 캐시 무효화하여 탭 변경 반영
          _cachedAppBar = null;
          setState(() => _currentIndex = index);
          final screenNames = ['MLSQuickRegistrationPage', 'MLSSellerDashboardPage'];
          _logService.logScreenView(screenNames[index], screenClass: 'MainPageTab');
        },
        borderRadius: BorderRadius.circular(AppleRadius.sm),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                // 선택됨: 파란 배경 / 미선택: 투명
                color: isSelected ? AppleColors.systemBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                // 미선택 시 테두리 표시
                border: isSelected ? null : Border.all(
                  color: AppleColors.separator,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppleColors.secondaryLabel,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: AppleTypography.subheadline.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppleColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            // 배지 (읽지 않은 알림 개수)
            if (showBadge)
              Positioned(
                right: -4,
                top: -4,
                child: _buildBadge(_unreadNotificationCount),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    final isLoggedIn = widget.userName.isNotEmpty;

    // Stack으로 진짜 중앙 배치
    return Stack(
      alignment: Alignment.center,
      children: [
        // 중앙 탭 버튼 (절대 중앙)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNavButton('빠른 등록', 0, Icons.sell_outlined),
            const SizedBox(width: 12),
            _buildNavButton('내 매물', 1, Icons.home_outlined),
          ],
        ),

        // 좌우 요소들 (Row로 양쪽 배치)
        Row(
          children: [
            // 왼쪽: 로고
            GestureDetector(
              onTap: () => setState(() => _currentIndex = 0),
              child: Text(
                'MyHome',
                style: AppleTypography.title2.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppleColors.systemBlue,
                ),
              ),
            ),

            const Spacer(),

            // 오른쪽 액션 버튼들
            // 순서: [알림] [설정] [모드전환(primary)] [로그아웃]
            // 1. 알림 버튼
            if (widget.userId.isNotEmpty)
              _buildHeaderActionButton(
                icon: Icons.notifications_outlined,
                tooltip: '알림',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationPage(userId: widget.userId),
                    ),
                  );
                },
              ),

            // 2. 설정 버튼
            if (widget.userId.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildHeaderActionButton(
                icon: Icons.settings_outlined,
                tooltip: '설정',
                onPressed: _showProfileSheet,
              ),
            ],

            // 3. 중개사 대시보드 버튼 (모드 전환 - primary)
            if (_isBroker) ...[
              const SizedBox(width: 8),
              _buildHeaderActionButton(
                icon: Icons.business_rounded,
                tooltip: '중개사 대시보드',
                isPrimary: true,
                onPressed: () {
                  final brokerId = _brokerData?['brokerId'] as String? ?? widget.userId;
                  final brokerName = _brokerData?['ownerName'] as String? ??
                      _brokerData?['businessName'] as String? ?? widget.userName;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => MLSBrokerDashboardPage(
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
              ),
            ],

            const SizedBox(width: 8),

            // 4. 로그인/로그아웃 버튼
            _buildHeaderActionButton(
              icon: isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
              tooltip: isLoggedIn ? '로그아웃' : '로그인',
              onPressed: () {
                if (isLoggedIn) {
                  _logout();
                } else {
                  _login();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 통일된 헤더 액션 버튼
  Widget _buildHeaderActionButton({
    required IconData icon,
    String? label,
    String? tooltip,
    bool isPrimary = false,
    required VoidCallback onPressed,
  }) {
    final hasLabel = label != null && label.isNotEmpty;

    return Tooltip(
      message: tooltip ?? label ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(
              horizontal: hasLabel ? 14 : 10,
            ),
            decoration: BoxDecoration(
              color: isPrimary ? AppleColors.systemBlue.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPrimary ? AppleColors.systemBlue.withValues(alpha: 0.3) : AppleColors.separator,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isPrimary ? AppleColors.systemBlue : AppleColors.secondaryLabel,
                ),
                if (hasLabel) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppleTypography.subheadline.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isPrimary ? AppleColors.systemBlue : AppleColors.label,
                    ),
                  ),
                ],
              ],
            ),
          ),
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

      // 공인중개사 로그인인 경우 MLSBrokerDashboardPage로 이동
      if (result['userType'] == 'broker' && result['brokerData'] != null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MLSBrokerDashboardPage(
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
              // 로그인 후 등록 탭으로 (Tab 0) - 헤이딜러 스타일
              initialTabIndex: targetIndex ?? 0,
            ),
          ),
        );
      }
    } else {
      // 로그인 실패 (result가 있지만 유효한 데이터가 없는 경우)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인에 실패했습니다. 이메일/전화번호를 확인해주세요.', style: AppleTypography.body.copyWith(color: Colors.white)),
            backgroundColor: AppleColors.systemRed,
          ),
        );
      }
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Firebase 로그아웃
              await FirebaseService().signOut();
              // 로그인 랜딩 페이지로 이동
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const AuthLandingPage(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String label, int index, IconData icon) {
    final isSelected = _currentIndex == index;
    final isLoggedIn = widget.userName.isNotEmpty;
    // 모든 탭이 로그인 필요 (2탭 구조: 등록, 내 매물)
    const requiresLogin = true;
    // "내 매물" 탭(index 1)에 배지 표시
    final showBadge = index == 1 && _unreadNotificationCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!isLoggedIn && requiresLogin) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('로그인이 필요합니다.', style: AppleTypography.body.copyWith(color: Colors.white)),
                backgroundColor: AppleColors.systemOrange,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _login(targetIndex: index);
            return;
          }
          // AppBar 캐시 무효화하여 탭 변경 반영
          _cachedAppBar = null;
          setState(() => _currentIndex = index);
          final screenNames = ['MLSQuickRegistrationPage', 'MLSSellerDashboardPage'];
          _logService.logScreenView(screenNames[index], screenClass: 'MainPageTab');
        },
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                // 선택됨: 파란 배경 / 미선택: 투명
                color: isSelected ? AppleColors.systemBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                // 미선택 시 테두리 표시
                border: isSelected ? null : Border.all(
                  color: AppleColors.separator,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? Colors.white : AppleColors.secondaryLabel,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppleTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppleColors.label,
                    ),
                  ),
                ],
              ),
            ),
            // 배지 (읽지 않은 알림 개수)
            if (showBadge)
              Positioned(
                right: -4,
                top: -4,
                child: _buildBadge(_unreadNotificationCount),
              ),
          ],
        ),
      ),
    );
  }

  /// 알림 배지 위젯
  Widget _buildBadge(int count) {
    final displayCount = count > 99 ? '99+' : count.toString();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppleColors.systemRed,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppleColors.systemRed.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(
        minWidth: 18,
        minHeight: 18,
      ),
      child: Text(
        displayCount,
        style: AppleTypography.caption2.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  @override
  void dispose() {
    // 알림 스트림 구독 취소
    _notificationSubscription?.cancel();
    // 페이지 캐시 정리
    _pageCache.clear();
    super.dispose();
  }
}
