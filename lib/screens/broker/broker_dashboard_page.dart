import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/constants/status_constants.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:intl/intl.dart';
import '../main_page.dart';
import 'broker_quote_detail_page.dart';
import '../login_page.dart';
import 'broker_settings_page.dart';
import 'broker_property_list_page.dart';
import '../notification/notification_page.dart';

/// 공인중개사 대시보드 페이지
class BrokerDashboardPage extends StatefulWidget {
  final String brokerId;
  final String brokerName;
  final Map<String, dynamic> brokerData;

  const BrokerDashboardPage({
    required this.brokerId,
    required this.brokerName,
    required this.brokerData,
    super.key,
  });

  @override
  State<BrokerDashboardPage> createState() => _BrokerDashboardPageState();
}

class _BrokerDashboardPageState extends State<BrokerDashboardPage> with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  List<QuoteRequest> _quotes = [];
  bool _isLoading = true;
  String? _error;
  String _selectedStatus = 'all'; // all, pending, completed, selected
  late TabController _tabController;

  String? _brokerRegistrationNumber;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _brokerRegistrationNumber = widget.brokerData['brokerRegistrationNumber'] as String?;
    _loadQuotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadQuotes() {
    if (_brokerRegistrationNumber == null || _brokerRegistrationNumber!.isEmpty) {
      setState(() {
        _error = '등록번호 정보가 없습니다.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null; // 오류 초기화
    });

    // Stream으로 실시간 데이터 수신
    _firebaseService.getBrokerQuoteRequests(_brokerRegistrationNumber!).listen(
      (quotes) {
        if (mounted) {
          setState(() {
            _quotes = quotes;
            _isLoading = false;
            _error = null; // 정상적으로 데이터를 받았으므로 오류 없음
          });
        }
      },
      onError: (error) {
        // 실제 오류가 발생한 경우에만 오류 메시지 표시
        if (mounted) {
          setState(() {
            _error = '상담 목록을 불러오는 중 문제가 발생했어요.\n잠시 후 다시 시도해주세요.';
            _isLoading = false;
          });
        }
      },
      cancelOnError: false, // 오류 발생 시에도 스트림 계속 유지
    );
  }

  List<QuoteRequest> get _filteredQuotes {
    if (_selectedStatus == 'all') {
      return _quotes;
    } else if (_selectedStatus == 'pending') {
      return _quotes.where((q) => QuoteLifecycleStatus.fromQuote(q) == QuoteLifecycleStatus.requested).toList();
    } else if (_selectedStatus == 'completed') {
      return _quotes.where((q) => QuoteLifecycleStatus.fromQuote(q) == QuoteLifecycleStatus.comparing).toList();
    } else if (_selectedStatus == 'selected') {
      return _quotes.where((q) => QuoteLifecycleStatus.fromQuote(q) == QuoteLifecycleStatus.selected).toList();
    } else {
      return _quotes;
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _firebaseService.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        title: HomeLogoButton(
          fontSize: AppTypography.h4.fontSize!,
          color: AirbnbColors.primary,
        ),
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.primary,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AirbnbColors.primary),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: '알림',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationPage(userId: widget.brokerData['uid'] ?? widget.brokerId),
                ),
              );
            },
          ),
          TextButton.icon(
            onPressed: () {
              // 일반 메인 페이지로 이동 (동일 계정)
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => MainPage(
                      userId: user.uid,
                      userName: widget.brokerName,
                    ),
                  ),
                );
              }
            },
            icon: Icon(Icons.home_outlined, size: 18, color: AirbnbColors.primary),
            label: Text(
              '일반 화면',
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                AirbnbColors.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: _logout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AirbnbColors.border, width: 0.5),
                bottom: BorderSide(color: AirbnbColors.border, width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AirbnbColors.primary,
              indicatorWeight: 3,
              labelColor: AirbnbColors.primary,
              unselectedLabelColor: AirbnbColors.textSecondary,
              tabs: const [
                Tab(
                  icon: Icon(Icons.chat_bubble_outline),
                  text: '상담 요청',
                ),
                Tab(
                  icon: Icon(Icons.home),
                  text: '내 매물',
                ),
                Tab(
                  icon: Icon(Icons.settings),
                  text: '내 정보',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 견적문의 탭
          Column(
            children: [
              // 헤더 (일반 화면 히어로 배너와 동일 그라데이션 사용)
              Builder(
                builder: (context) {
                  final maxWidth = ResponsiveHelper.getMaxWidth(context);
                  final isWeb = ResponsiveHelper.isWeb(context);
                  final horizontalPadding = isWeb ? AppSpacing.lg : AppSpacing.md;
                  final isMobile = ResponsiveHelper.isMobile(context);
                  final isTablet = ResponsiveHelper.isTablet(context);
                  
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: isMobile ? 48.0 : 64.0,
                    ),
                    decoration: const BoxDecoration(
                      color: AirbnbColors.background,
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 매우 큰 헤드라인 (Stripe/Vercel 스타일)
                            Text(
                              '상담 관리 대시보드',
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
                            SizedBox(height: AppSpacing.lg),
                            Text(
                              widget.brokerName,
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
                    ),
                  );
                },
              ),

              // 견적 목록
              Expanded(
                child: _buildQuoteList(),
              ),
            ],
          ),
          // 내 매물 탭
          BrokerPropertyListPage(
            brokerId: widget.brokerId,
            brokerData: widget.brokerData,
          ),
          // 내 정보 탭
          BrokerSettingsPage(
            brokerId: widget.brokerId,
            brokerName: widget.brokerName,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, String statusValue) {
    final isSelected = _selectedStatus == statusValue;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStatus = statusValue;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // 히어로 배경 위에 떠 있는 흰색 카드 느낌으로 통일
            // 선택된 경우 배경색을 약간 강조
            color: isSelected 
                ? AirbnbColors.background 
                : AirbnbColors.background.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              // 선택된 경우 테두리를 해당 상태 색상으로 강조
              color: isSelected 
                  ? color 
                  : AirbnbColors.background.withValues(alpha: 0.6),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected 
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ] 
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTypography.withColor(
                  AppTypography.bodySmall.copyWith(
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  isSelected ? color : AirbnbColors.textPrimary,
                ),
              ),
              SizedBox(height: AppSpacing.xs + AppSpacing.xs / 2),
              Text(
                value,
                style: AppTypography.withColor(
                  AppTypography.h2.copyWith(fontWeight: FontWeight.w800),
                  color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuoteList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AirbnbColors.error.withValues(alpha: 0.3)),
            SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.withColor(
                AppTypography.body,
                AirbnbColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _loadQuotes,
              style: CommonDesignSystem.primaryButtonStyle(),
              child: Text('다시 시도', style: AppTypography.button),
            ),
          ],
        ),
      );
    }

    if (_filteredQuotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: AirbnbColors.border,
            ),
            SizedBox(height: AppSpacing.lg),
            Text(
              _selectedStatus == 'all'
                  ? '아직 받은 상담 요청이 없어요'
                  : '조건에 맞는 상담이 없어요',
              style: AppTypography.withColor(
                AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                AirbnbColors.textSecondary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '소유자/임대인분들로부터 상담 요청이 들어오면\n여기에 표시됩니다',
              textAlign: TextAlign.center,
              style: AppTypography.withColor(
                AppTypography.bodySmall,
                AirbnbColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredQuotes.length,
      itemBuilder: (context, index) {
        return _buildQuoteCard(_filteredQuotes[index]);
      },
    );
  }

  Widget _buildQuoteCard(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final hasAnswer = quote.hasAnswer;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        border: hasAnswer
            ? Border.all(color: AirbnbColors.success.withValues(alpha: 0.3), width: 2)
            : Border.all(color: AirbnbColors.warning.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrokerQuoteDetailPage(
                quote: quote,
                brokerData: widget.brokerData,
              ),
            ),
          ).then((_) => _loadQuotes()); // 답변 후 목록 새로고침
        },
        borderRadius: BorderRadius.circular(16),
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
                      color: hasAnswer
                          ? AirbnbColors.success.withValues(alpha: 0.1)
                          : AirbnbColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasAnswer ? Icons.check_circle : Icons.schedule,
                      color: hasAnswer ? AirbnbColors.success : AirbnbColors.warning,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.userName,
                          style: AppTypography.withColor(
                            AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                            AirbnbColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          dateFormat.format(quote.requestDate),
                          style: AppTypography.withColor(
                            AppTypography.caption,
                            AirbnbColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs, vertical: AppSpacing.xs + AppSpacing.xs / 2),
                    decoration: BoxDecoration(
                      color: hasAnswer ? AirbnbColors.success : AirbnbColors.warning,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasAnswer ? '답변완료' : '대기중',
                      style: AppTypography.withColor(
                        AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                        AirbnbColors.background,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: AppSpacing.md),

              // 매물 정보
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: AirbnbColors.textSecondary),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            quote.propertyAddress ?? '-',
                            style: AppTypography.withColor(
                              AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                              AirbnbColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (quote.propertyArea != null) ...[
                      SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.square_foot, size: 16, color: AirbnbColors.textSecondary),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            '${quote.propertyArea}㎡',
                            style: AppTypography.withColor(
                              AppTypography.bodySmall,
                              AirbnbColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (quote.desiredPrice != null) ...[
                      SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(Icons.attach_money, size: 16, color: AirbnbColors.textSecondary),
                          SizedBox(width: AppSpacing.sm),
                          Text(
                            '희망가: ${quote.desiredPrice}',
                            style: AppTypography.withColor(
                              AppTypography.bodySmall,
                              AirbnbColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: AppSpacing.md + AppSpacing.xs),

              // 액션
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!hasAnswer && quote.status != 'cancelled') ...[
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('이번 건은 보류할까요?'),
                            content: const Text(
                              '이 상담 요청은 이번에는 진행하지 않으시겠습니까?\n'
                              '고객님 화면에서는 \'보류됨\'으로 표시됩니다.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('취소'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('보류하기'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          final success = await _firebaseService
                              .updateQuoteRequestStatus(quote.id, 'cancelled');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? '이번 건은 진행하지 않도록 표시했어요.'
                                    : '처리 중 문제가 발생했어요. 잠시 후 다시 시도해주세요.',
                              ),
                              backgroundColor:
                                  success ? AirbnbColors.primary : AirbnbColors.error,
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AirbnbColors.error,
                        side: const BorderSide(color: AirbnbColors.error),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: Icon(Icons.block, size: 16),
                      label: Text(
                        '보류하기',
                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  ],
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BrokerQuoteDetailPage(
                            quote: quote,
                            brokerData: widget.brokerData,
                          ),
                        ),
                      ).then((_) => _loadQuotes());
                    },
                    icon: Icon(
                      hasAnswer ? Icons.edit : Icons.reply,
                      size: 18,
                    ),
                    label: Text(
                      hasAnswer ? '답변 수정' : '답변하기',
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                      foregroundColor: AirbnbColors.background,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

