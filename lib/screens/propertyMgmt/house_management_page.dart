import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/screens/quote_comparison_page.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/screens/broker_list_page.dart';
import 'package:property/widgets/retry_view.dart';
import 'package:intl/intl.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/screens/login_page.dart';
import 'package:property/screens/broker/broker_detail_page.dart';
import 'package:property/api_request/broker_service.dart';
import 'package:property/models/broker_review.dart';
import 'package:property/utils/transaction_type_helper.dart';

/// 내집관리 (견적 현황) 페이지
class HouseManagementPage extends StatefulWidget {
  final String userName;
  final String? userId; // userId 추가

  const HouseManagementPage({
    required this.userName,
    this.userId, // userId 추가
    super.key,
  });

  @override
  State<HouseManagementPage> createState() => _HouseManagementPageState();
}

class _HouseManagementPageState extends State<HouseManagementPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<QuoteRequest> quotes = [];
  List<QuoteRequest> filteredQuotes = [];
  bool isLoading = true;
  String? error;

  // 필터 상태
  String selectedStatus = 'all'; // all, pending, completed

  // 날짜별 그룹화된 견적 데이터 (요청 날짜 기준)
  Map<String, List<QuoteRequest>> _dateGroupedQuotes = {};

  static const Map<String, List<String>> _statusGroups = {
    'waiting': ['pending'],
    'progress': ['contacted', 'answered'],
    'completed': ['completed'],
    'cancelled': ['cancelled'],
  };

  static const List<Map<String, String>> _statusFilterDefinitions = [
    {'value': 'all', 'label': '전체'},
    {'value': 'waiting', 'label': '미응답'},
    {'value': 'progress', 'label': '진행중'},
    {'value': 'completed', 'label': '완료'},
    {'value': 'cancelled', 'label': '취소됨'},
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteHistoryOpened,
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.quoteResponse,
    );
    _loadQuotes();
  }

  /// 견적문의 목록 로드
  Future<void> _loadQuotes() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // userId가 있으면 userId 사용, 없으면 userName 사용
      final queryId = (widget.userId != null && widget.userId!.isNotEmpty)
          ? widget.userId!
          : widget.userName;

      // Stream으로 실시간 데이터 수신
      _firebaseService.getQuoteRequestsByUser(queryId).listen((loadedQuotes) {
        if (mounted) {
          setState(() {
            quotes = loadedQuotes;
            isLoading = false;
          });
          _applyFilter(source: 'auto_sync');
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = '내집관리 데이터를 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }

  /// 필터 적용
  void _applyFilter({String source = 'auto'}) {
    final List<QuoteRequest> nextFiltered;
    if (selectedStatus == 'all') {
      nextFiltered = List<QuoteRequest>.from(quotes);
    } else {
      final group = _statusGroups[selectedStatus];
      if (group != null) {
        nextFiltered = quotes.where((q) => group.contains(q.status)).toList();
      } else {
        nextFiltered = quotes.where((q) => q.status == selectedStatus).toList();
      }
    }

    // 주소별 그룹화 (기존 로직 유지)
    final Map<String, List<QuoteRequest>> grouped = {};
    for (final quote in nextFiltered) {
      final address = quote.propertyAddress ?? '주소없음';
      grouped.putIfAbsent(address, () => []).add(quote);
    }
    grouped.forEach((key, value) {
      value.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    });

    // 날짜별 그룹화 (새로운 로직)
    final Map<String, List<QuoteRequest>> dateGrouped = {};
    for (final quote in nextFiltered) {
      // 날짜를 "yyyy.MM.dd" 형식으로 변환
      final dateKey = DateFormat('yyyy.MM.dd').format(quote.requestDate);
      dateGrouped.putIfAbsent(dateKey, () => []).add(quote);
    }
    // 각 날짜 그룹 내에서 시간순 정렬 (최신순)
    dateGrouped.forEach((key, value) {
      value.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    });

    setState(() {
      filteredQuotes = nextFiltered;
      _dateGroupedQuotes = dateGrouped;
    });

    final appliedStatuses = selectedStatus == 'all'
        ? null
        : (_statusGroups[selectedStatus] ?? [selectedStatus]);

    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteHistoryFilterApplied,
      params: {
        'status': selectedStatus,
        'source': source,
        'totalQuotes': quotes.length,
        'filteredQuotes': nextFiltered.length,
        'appliedStatuses': appliedStatuses,
      },
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.quoteResponse,
    );
  }

  /// 견적문의 삭제
  /// 공인중개사 재연락 (전화 또는 다시 견적 요청)
  Future<void> _recontactBroker(QuoteRequest quote) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.phone, color: AirbnbColors.primary, size: 28),
            SizedBox(width: 12),
            Text('재연락 방법', style: AppTypography.h4),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이 공인중개사와 재연락하는 방법을 선택하세요:',
              style: AppTypography.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.phone, color: AirbnbColors.success),
              title: const Text(
                '전화 걸기',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('직접 통화하여 문의'),
              onTap: () => Navigator.pop(context, 'phone'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: AirbnbColors.primary),
              title: const Text(
                '다시 견적 요청',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('같은 주소로 새로 견적 요청'),
              onTap: () => Navigator.pop(context, 'resend'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (action == 'phone') {
      // 전화 걸기 (등록번호로 중개사 정보 조회 필요 - 간단히 처리)
      final phoneNumber = quote.brokerRegistrationNumber; // 실제로는 전화번호를 저장해야 함
      if (phoneNumber == null || phoneNumber.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전화번호 정보가 없습니다.'),
            backgroundColor: AirbnbColors.warning,
          ),
        );
        return;
      }

      // 실제로는 QuoteRequest에 brokerPhoneNumber 필드가 있어야 함
      // 현재는 brokerRegistrationNumber만 있으므로, BrokerService로 조회 필요
      // 일단 간단히 안내만 표시
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호 정보는 공인중개사 목록에서 확인할 수 있습니다.'),
          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
          duration: Duration(seconds: 3),
        ),
      );
    } else if (action == 'resend') {
      // 다시 견적 요청
      if (quote.propertyAddress == null || quote.propertyAddress!.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주소 정보가 없어 견적을 다시 요청할 수 없습니다.'),
            backgroundColor: AirbnbColors.warning,
          ),
        );
        return;
      }

      if (!mounted) return;

      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // 주소에서 좌표 조회
        final coord = await VWorldService.getCoordinatesFromAddress(
          quote.propertyAddress!,
        );

        if (coord == null) {
          if (!mounted) return;
          Navigator.pop(context); // 로딩 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('주소 정보를 찾을 수 없습니다.'),
              backgroundColor: AirbnbColors.error,
            ),
          );
          return;
        }

        final lat = double.tryParse('${coord['y']}');
        final lon = double.tryParse('${coord['x']}');

        if (lat == null || lon == null) {
          if (!mounted) return;
          Navigator.pop(context); // 로딩 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('좌표 정보를 가져올 수 없습니다.'),
              backgroundColor: AirbnbColors.error,
            ),
          );
          return;
        }

        if (!mounted) return;
        Navigator.pop(context); // 로딩 닫기

        // BrokerListPage로 이동 (기존 주소 사용)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BrokerListPage(
              address: quote.propertyAddress!,
              latitude: lat,
              longitude: lon,
              userName: widget.userName,
              userId: quote.userId.isNotEmpty ? quote.userId : null,
              propertyArea: quote.propertyArea,
              transactionType: quote.transactionType,
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

  /// 공인중개사 선택 (계속 진행할래요)
  Future<void> _onSelectBroker(QuoteRequest quote) async {
    // 이미 선택된 견적이면 처리하지 않음
    if (quote.isSelectedByUser == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 이 공인중개사와 진행 중입니다.'),
          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
        ),
      );
      return;
    }

    // 로그인 여부 확인
    if (widget.userId == null || widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후에 공인중개사를 선택할 수 있습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공인중개사 선택'),
        content: Text(
          '"${quote.brokerName}" 공인중개사와 계속 진행하시겠습니까?\n\n'
          '확인 버튼을 누르면:\n'
          '• 이 공인중개사에게만 사용자님의 연락처가 전달되고\n'
          '• 이 중개사와의 본격적인 상담이 시작됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
              foregroundColor: AirbnbColors.background,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // 로딩 다이얼로그
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await _firebaseService.assignQuoteToBroker(
        requestId: quote.id,
        userId: widget.userId!,
      );

      if (!mounted) return;

      Navigator.pop(context); // 로딩 닫기

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${quote.brokerName}" 공인중개사에게 매물 판매 의뢰가 전달되었습니다.\n'
              '곧 중개사에게서 연락이 올 거예요.',
            ),
            backgroundColor: AirbnbColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공인중개사 선택에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  /// 견적 카드에서 공인중개사 상세 페이지로 이동
  void _openBrokerDetailFromQuote(QuoteRequest quote) {
    if (quote.brokerRegistrationNumber == null ||
        quote.brokerRegistrationNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('중개사 등록번호 정보가 없어 상세 페이지를 열 수 없습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    final broker = Broker(
      name: quote.brokerName,
      roadAddress: quote.brokerRoadAddress ?? '',
      jibunAddress: quote.brokerJibunAddress ?? '',
      registrationNumber: quote.brokerRegistrationNumber!,
      etcAddress: '',
      employeeCount: '-',
      registrationDate: '',
      latitude: null,
      longitude: null,
      distance: null,
      systemRegNo: null,
      ownerName: null,
      businessName: null,
      phoneNumber: null,
      businessStatus: null,
      seoulAddress: null,
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
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrokerDetailPage(
          broker: broker,
          currentUserId: widget.userId,
          currentUserName: widget.userName,
          quoteRequestId: quote.id,
          quoteStatus: quote.status,
        ),
      ),
    );
  }

  /// 후기 작성 / 수정 바텀시트
  // ignore: unused_element
  Future<void> _openReviewSheet(QuoteRequest quote) async {
    if (widget.userId == null || widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인 후 후기를 작성할 수 있습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }
    if (quote.status != 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('상담이 완료된 견적에만 후기를 남길 수 있습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }
    if (quote.brokerRegistrationNumber == null ||
        quote.brokerRegistrationNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('중개사 정보가 없어 후기를 작성할 수 없습니다.'),
          backgroundColor: AirbnbColors.warning,
        ),
      );
      return;
    }

    final existingReview = await _firebaseService.getUserReviewForQuote(
      userId: widget.userId!,
      brokerRegistrationNumber: quote.brokerRegistrationNumber!,
      quoteRequestId: quote.id,
    );

    bool recommend = existingReview?.recommend ?? true;
    final commentController =
        TextEditingController(text: existingReview?.comment ?? '');

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${quote.brokerName} 후기',
                    style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Text('추천 여부', style: AppTypography.bodySmall),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('추천'),
                        selected: recommend == true,
                        onSelected: (_) {
                          setState(() {
                            recommend = true;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('비추천'),
                        selected: recommend == false,
                        onSelected: (_) {
                          setState(() {
                            recommend = false;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                  TextField(
                    controller: commentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '상담을 받으면서 좋았던 점, 아쉬웠던 점을 자유롭게 작성해주세요.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final trimmed =
                            commentController.text.trim().isEmpty
                                ? null
                                : commentController.text.trim();

                        final now = DateTime.now();
                        final review = BrokerReview(
                          id: existingReview?.id ?? '',
                          brokerRegistrationNumber:
                              quote.brokerRegistrationNumber!,
                          userId: widget.userId!,
                          userName: widget.userName,
                          quoteRequestId: quote.id,
                          rating: recommend ? 5 : 1,
                          recommend: recommend,
                          comment: trimmed,
                          createdAt: existingReview?.createdAt ?? now,
                          updatedAt: now,
                        );

                        final savedId =
                            await _firebaseService.saveBrokerReview(review);

                        if (!mounted) return;
                        Navigator.pop(context);
                        if (mounted) {
                          if (savedId != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('후기가 저장되었습니다.'),
                                backgroundColor: AirbnbColors.success,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('후기 저장에 실패했습니다.'),
                                backgroundColor: AirbnbColors.error,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                        foregroundColor: AirbnbColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        existingReview == null ? '후기 저장' : '후기 수정하기',
                        style: AppTypography.buttonSmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // 사용되지 않는 메서드 (주석 처리된 _buildGuestBanner에서만 사용됨)
  // Future<void> _navigateToLoginAndRefresh() async {
  //   final result = await Navigator.of(context).push<Map<String, dynamic>>(
  //     MaterialPageRoute(builder: (_) => const LoginPage()),
  //   );
  //   if (!mounted) return;
  //   if (result != null) {
  //     Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  //   }
  // }

  /// '답변 대기' 상태인 견적문의 전체 삭제
  Future<void> _deleteWaitingQuotes() async {
    final waitingStatuses = _statusGroups['waiting'] ?? const [];
    final targets = quotes
        .where((q) => waitingStatuses.contains(q.status))
        .toList();

    if (targets.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('삭제할 답변 대기 내역이 없습니다.'),
          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: AirbnbColors.error, size: 28),
            SizedBox(width: 12),
            Text('답변 대기 전체 삭제', style: AppTypography.h3),
          ],
        ),
        content: Text(
          '답변 대기 상태인 견적문의 ${targets.length}건을 모두 삭제하시겠습니까?\n'
          '삭제된 내역은 복구할 수 없습니다.',
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: AppTypography.buttonSmall),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.error,
              foregroundColor: AirbnbColors.background,
            ),
            child: Text(
              '전체 삭제',
              style: AppTypography.buttonSmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    int successCount = 0;
    for (final quote in targets) {
      final success = await _firebaseService.deleteQuoteRequest(quote.id);
      if (success) {
        successCount++;
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('답변 대기 견적문의 $successCount건이 삭제되었습니다.'),
        backgroundColor:
            successCount > 0 ? AirbnbColors.success : AirbnbColors.primary,
      ),
    );
  }

  Future<void> _deleteQuote(String quoteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AirbnbColors.warning, size: 28),
            SizedBox(width: 12),
            Text('삭제 확인', style: AppTypography.h3),
          ],
        ),
        content: Text(
          '이 견적문의를 삭제하시겠습니까?\n삭제된 내역은 복구할 수 없습니다.',
          style: AppTypography.bodySmall.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소', style: AppTypography.buttonSmall),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbColors.error,
              foregroundColor: AirbnbColors.background,
            ),
            child: Text(
              '삭제',
              style: AppTypography.buttonSmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _firebaseService.deleteQuoteRequest(quoteId);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('견적문의가 삭제되었습니다.'),
            backgroundColor: AirbnbColors.success,
          ),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제에 실패했습니다.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    }
  }

  /// 견적문의 전체 상세 정보 표시
  void _showFullQuoteDetails(QuoteRequest quote) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteDetailViewed,
      params: {
        'quoteId': quote.id,
        'status': quote.status,
        'brokerName': quote.brokerName,
        'hasAnswer': quote.hasAnswer,
      },
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.quoteResponse,
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AirbnbColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description,
                      color: AirbnbColors.background,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote.brokerName,
                            style: AppTypography.withColor(
                              AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                              AirbnbColors.background,
                            ),
                          ),
                          if (quote.answerDate != null)
                            Text(
                              '답변일: ${dateFormat.format(quote.answerDate!)}',
                              style: AppTypography.withColor(
                                AppTypography.caption,
                                AirbnbColors.background.withValues(alpha: 0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AirbnbColors.background),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // 내용
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 매물 정보
                      if (quote.propertyAddress != null ||
                          quote.propertyArea != null ||
                          quote.propertyType != null) ...[
                        _buildDetailSection('매물 정보', Icons.home, AirbnbColors.primary, [
                          if (quote.propertyAddress != null)
                            _buildDetailRow('위치', quote.propertyAddress!),
                          if (quote.propertyType != null)
                            _buildDetailRow('유형', quote.propertyType!),
                          if (quote.propertyArea != null)
                            _buildDetailRow('면적', '${quote.propertyArea} ㎡'),
                        ]),
                        const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                      ],

                      // 중개 제안
                      if (quote.recommendedPrice != null ||
                          quote.minimumPrice != null ||
                          quote.expectedDuration != null ||
                          quote.promotionMethod != null ||
                          quote.commissionRate != null ||
                          quote.recentCases != null) ...[
                        _buildDetailSection(
                          '중개 제안',
                          Icons.campaign,
                          AirbnbColors.success,
                          [
                            if (quote.recommendedPrice != null)
                              _buildDetailRow(
                                TransactionTypeHelper.getRecommendedPriceLabel(quote.transactionType ?? '매매'),
                                quote.recommendedPrice!,
                              ),
                            if (quote.minimumPrice != null)
                              _buildDetailRow('최저수락가', quote.minimumPrice!),
                            if (quote.expectedDuration != null)
                              _buildDetailRow(
                                '예상 거래기간',
                                quote.expectedDuration!,
                              ),
                            if (quote.commissionRate != null)
                              _buildDetailRow('중개 수수료', quote.commissionRate!),
                            if (quote.promotionMethod != null)
                              _buildDetailRow('홍보 방법', quote.promotionMethod!),
                            if (quote.recentCases != null)
                              _buildDetailRow(
                                '최근 유사 거래 사례',
                                quote.recentCases!,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg + AppSpacing.xs),
                      ],

                      // 공인중개사 답변
                      if (quote.brokerAnswer != null &&
                          quote.brokerAnswer!.isNotEmpty) ...[
                        _buildDetailSection(
                          '공인중개사 답변',
                          Icons.reply,
                          AirbnbColors.primary,
                          [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AirbnbColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AirbnbColors.border),
                              ),
                              child: Text(
                                quote.brokerAnswer!,
                                style: AppTypography.withColor(
                                  AppTypography.bodySmall.copyWith(height: 1.7),
                                  AirbnbColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 하단 버튼
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AirbnbColors.surface,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _recontactBroker(quote);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.primary,
                          side: const BorderSide(
                            color: AirbnbColors.primary,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text(
                          '재연락',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deleteQuote(quote.id);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.error,
                          side: const BorderSide(color: AirbnbColors.error, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text(
                          '삭제',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상세 정보 섹션 위젯
  Widget _buildDetailSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.withColor(
                  AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                  color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }

  /// 상세 정보 행 위젯
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.withColor(
                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                AirbnbColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AirbnbColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    // 모바일/데스크톱에 따른 값 설정 (메인페이지 스타일)
    final isTablet = ResponsiveHelper.isTablet(context);
    final bannerHeight = isMobile ? AppSpacing.xxxl * 5 : (isTablet ? AppSpacing.xxxl * 5.625 : AppSpacing.xxxl * 6.25);
    final bannerPadding = isMobile 
        ? const EdgeInsets.symmetric(vertical: AppSpacing.xxxl * 0.75, horizontal: AppSpacing.lg)
        : const EdgeInsets.symmetric(vertical: AppSpacing.xxxl, horizontal: AppSpacing.xxxl * 0.75);
    final bannerTitleSize = isMobile ? AppTypography.display.fontSize! : (isTablet ? AppTypography.display.fontSize! * 1.3 : AppTypography.display.fontSize! * 1.6);
    final bannerSubtitleSize = isMobile ? AppTypography.bodyLarge.fontSize! : AppTypography.h4.fontSize!;
    final contentTopPadding = isMobile ? AppSpacing.xxxl * 3.75 : AppSpacing.xxxl * 5; // 배너 높이 - 겹침
    final contentHorizontalPadding = isMobile ? AppSpacing.md : AppSpacing.lg;
    final cardPadding = isMobile ? AppSpacing.md : AppSpacing.lg;
    final cardMargin = isMobile ? AppSpacing.md : AppSpacing.lg;
    final cardBorderRadius = isMobile ? AppSpacing.md : AppSpacing.lg;
    final titleFontSize = isMobile ? AppTypography.body.fontSize! : AppTypography.bodyLarge.fontSize!;
    final subtitleFontSize = isMobile ? AppTypography.caption.fontSize! : AppTypography.bodySmall.fontSize!;
    final buttonHeight = isMobile ? AppSpacing.xxxl * 0.75 : AppSpacing.xxxl * 0.8125;
    final buttonFontSize = isMobile ? AppTypography.bodySmall.fontSize! : AppTypography.body.fontSize!;
    final filterPadding = isMobile 
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md + AppSpacing.xs)
        : const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md);
    final filterChipPadding = isMobile
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xs, vertical: AppSpacing.sm)
        : const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md + AppSpacing.xs);
    final filterChipFontSize = isMobile ? AppTypography.caption.fontSize! : AppTypography.bodySmall.fontSize!;
    
    return Scaffold(
      backgroundColor: AirbnbColors.background,
      body: SingleChildScrollView(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // 1. 히어로 배너 (메인페이지 스타일)
            Container(
              height: bannerHeight,
              width: double.infinity,
              padding: bannerPadding,
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
                      '내집관리',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: bannerTitleSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1.1,
                        color: AirbnbColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: isMobile ? 24 : 24), // 24px
                    // 큰 서브헤드
                    Text(
                      '견적 요청 내역을 확인하고\n최적의 조건을 비교해보세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: bannerSubtitleSize,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. 메인 컨텐츠 (배너와 겹치게 배치)
            Padding(
              padding: EdgeInsets.only(top: contentTopPadding),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900),
                  padding: EdgeInsets.symmetric(horizontal: contentHorizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // (1) 대시보드 카드 (비교 버튼 + 요약)
                      if (!isLoading && quotes.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(bottom: cardMargin),
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background,
                            borderRadius: BorderRadius.circular(cardBorderRadius),
                            boxShadow: [
                              BoxShadow(
                                color: AirbnbColors.textPrimary.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                                    decoration: BoxDecoration(
                                      color: AirbnbColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.analytics_outlined, 
                                      color: AirbnbColors.primary, 
                                      size: isMobile ? 20 : 24
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 12 : 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '받은 견적 현황',
                                          style: TextStyle(
                                            fontSize: titleFontSize,
                                            fontWeight: FontWeight.bold,
                                            color: AirbnbColors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(height: isMobile ? 2 : 4),
                                        Text(
                                          '총 ${quotes.length}건의 요청 중 ${quotes.where((q) => q.hasAnswer).length}건의 답변을 받았습니다.',
                                          style: TextStyle(
                                            fontSize: subtitleFontSize,
                                            color: AirbnbColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isMobile ? 16 : 20),
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // 답변 완료된 견적만 필터
                                    final respondedQuotes = quotes.where((q) {
                                      return (q.recommendedPrice != null && q.recommendedPrice!.isNotEmpty) ||
                                          (q.minimumPrice != null && q.minimumPrice!.isNotEmpty);
                                    }).toList();

                                    if (respondedQuotes.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('받은 견적이 없습니다. 공인중개사로부터 답변을 받으면 확인할 수 있습니다.'),
                                          backgroundColor: AirbnbColors.warning,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuoteComparisonPage(
                                          quotes: quotes,
                                          userName: widget.userName,
                                          userId: quotes.isNotEmpty && quotes.first.userId.isNotEmpty ? quotes.first.userId : null,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                                    foregroundColor: AirbnbColors.background,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.compare_arrows_rounded,
                                    size: isMobile ? 18 : 20,
                                  ),
                                  label: Text(
                                    '받은 견적 한눈에 비교하기',
                                    style: TextStyle(
                                      fontSize: buttonFontSize, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // (2) 필터 섹션 (디자인 개선)
                      if (!isLoading && quotes.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(bottom: cardMargin),
                          padding: filterPadding,
                          decoration: BoxDecoration(
                            color: AirbnbColors.background,
                            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
                            boxShadow: [
                              BoxShadow(
                                color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 상단: 탭 스타일 필터바
                              Row(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: _statusFilterDefinitions.map((definition) {
                                          final value = definition['value']!;
                                          final label = definition['label']!;
                                          final count = value == 'all'
                                              ? quotes.length
                                              : quotes.where((q) {
                                                  final group = _statusGroups[value];
                                                  if (group == null) return q.status == value;
                                                  return group.contains(q.status);
                                                }).length;
                                          
                                          final isSelected = selectedStatus == value;
                                          
                                          return Padding(
                                            padding: EdgeInsets.only(right: isMobile ? 6 : 8),
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  selectedStatus = value;
                                                  _applyFilter(source: 'user');
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(30),
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                padding: filterChipPadding,
                                                decoration: BoxDecoration(
                                                  color: isSelected 
                                                      ? AirbnbColors.primary 
                                                      : AirbnbColors.surface,
                                                  borderRadius: BorderRadius.circular(30),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      label,
                                                      style: TextStyle(
                                                        fontSize: filterChipFontSize,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                        color: isSelected ? AirbnbColors.background : AirbnbColors.textSecondary,
                                                      ),
                                                    ),
                                                    if (count > 0) ...[
                                                      SizedBox(width: isMobile ? 4 : 6),
                                                      Container(
                                                        padding: EdgeInsets.symmetric(
                                                          horizontal: isMobile ? 5 : 6, 
                                                          vertical: 2
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isSelected 
                                                              ? AirbnbColors.background.withValues(alpha: 0.2)
                                                              : AirbnbColors.border,
                                                          borderRadius: BorderRadius.circular(10),
                                                        ),
                                                        child: Text(
                                                          '$count',
                                                          style: TextStyle(
                                                            fontSize: isMobile ? 10 : 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: isSelected ? AirbnbColors.background : AirbnbColors.textSecondary,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // 하단: 액션 영역 (미응답 삭제 등)
                              Builder(
                                builder: (context) {
                                  final waitingCount = quotes.where((q) => (_statusGroups['waiting'] ?? []).contains(q.status)).length;
                                  if (waitingCount == 0) return const SizedBox.shrink();
                                  
                                  return Column(
                                    children: [
                                      SizedBox(height: isMobile ? 12 : 16),
                                      const Divider(height: 1),
                                      SizedBox(height: isMobile ? 8 : 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: _deleteWaitingQuotes,
                                          style: TextButton.styleFrom(
                                            foregroundColor: AirbnbColors.error.withValues(alpha: 0.7),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 10 : 12, 
                                              vertical: isMobile ? 6 : 8
                                            ),
                                            backgroundColor: AirbnbColors.error.withValues(alpha: 0.05),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: Icon(
                                            Icons.delete_sweep_outlined, 
                                            size: isMobile ? 16 : 18
                                          ),
                                          label: Text(
                                            '미응답 내역 전체 삭제 ($waitingCount)',
                                            style: TextStyle(
                                              fontSize: isMobile ? 12 : 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                      // (3) 견적 목록
                      if (isLoading)
                        _buildSkeletonList()
                      else if (error != null)
                        RetryView(message: error!, onRetry: _loadQuotes)
                      else if (quotes.isEmpty)
                        _buildEmptyCard()
                      else if (filteredQuotes.isEmpty)
                        _buildNoFilterResultsCard()
                      else
                        _buildQuoteList(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasStructuredData(QuoteRequest quote) {
    return (quote.recommendedPrice?.isNotEmpty ?? false) ||
        (quote.minimumPrice?.isNotEmpty ?? false) ||
        (quote.commissionRate?.isNotEmpty ?? false) ||
        (quote.expectedDuration?.isNotEmpty ?? false) ||
        (quote.promotionMethod?.isNotEmpty ?? false) ||
        (quote.recentCases?.isNotEmpty ?? false);
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AirbnbColors.background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AirbnbColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 18,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AirbnbColors.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                Container(
                  height: 14,
                  width: 220,
                  decoration: BoxDecoration(
                    color: AirbnbColors.textSecondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AirbnbColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // 진행 현황 요약 카드는 UX 단순화를 위해 제거되었습니다.

  // 사용되지 않는 함수들 (향후 사용 가능성을 위해 주석 처리)
  /*
  Widget _buildGuestBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AirbnbColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AirbnbColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AirbnbColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '로그인하시면 상담 현황이 자동으로 저장되고, 알림도 받을 수 있어요.',
                  style: TextStyle(
                    style: AppTypography.bodySmall,
                    fontWeight: FontWeight.w600,
                    color: AirbnbColors.primaryDark,
                  ),
                ),
                SizedBox(height: AppSpacing.xs + AppSpacing.xs / 2),
                const Text(
                  '지금은 게스트 모드입니다. 손쉽게 로그인하고 알림/비교 기능을 끝까지 활용해보세요.',
                  style: TextStyle(
                    style: AppTypography.caption,
                    color: AirbnbColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: AppSpacing.md + AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      AnalyticsService.instance.logEvent(
                        AnalyticsEventNames.guestLoginCtaTapped,
                        params: {'source': 'quote_history_banner'},
                        userId: widget.userId,
                        userName: widget.userName,
                        stage: FunnelStage.selection,
                      );
                      await _navigateToLoginAndRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
                      foregroundColor: AirbnbColors.background,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text(
                      '로그인하고 이어서 보기',
                      style: TextStyle(
                        style: AppTypography.bodySmall,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(List<QuoteRequest> data) {
    final displayed = data.length > 6 ? data.sublist(0, 6) : data;
    return Card(
      elevation: 3,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 주요 제안 비교',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AirbnbColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.md + AppSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.resolveWith(
                  (states) => AirbnbColors.primaryLight.withValues(alpha: 0.1),
                ),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AirbnbColors.textPrimary,
                ),
                columnSpacing: 32,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text('중개사')),
                  DataColumn(label: Text('권장가')),
                  DataColumn(label: Text('수수료')),
                ],
                rows: displayed.map((quote) {
                  String format(String? value) =>
                      value == null || value.isEmpty ? '-' : value;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          quote.brokerName,
                          style: const TextStyle(
                            style: AppTypography.bodySmall,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          format(quote.recommendedPrice),
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      DataCell(
                        Text(
                          format(quote.commissionRate),
                          style: const TextStyle(
                            style: AppTypography.bodySmall,
                            fontWeight: FontWeight.bold,
                            color: AirbnbColors.primary,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            if (data.length > displayed.length)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '※ 최신 제안 6건만 표시됩니다. 전체 내용은 각 카드에서 확인하세요.',
                  style: TextStyle(
                    style: AppTypography.caption.copyWith(fontSize: 11),
                    color: AirbnbColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  */

  /// 정보 행 위젯
  Widget _buildInfoRow(String label, String value, {bool isMobile = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? 70 : 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: AirbnbColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: AirbnbColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 필터 칩 위젯 (사용되지 않음 - 향후 사용 가능성을 위해 주석 처리)
  /*
  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = selectedStatus == value;
    // 상태별 대표 색상 정의
    Color statusColor;
    switch (value) {
      case 'waiting':
        statusColor = AirbnbColors.warning;
        break;
      case 'progress':
        statusColor = AirbnbColors.primary;
        break;
      case 'completed':
        statusColor = AirbnbColors.success;
        break;
      case 'cancelled':
        statusColor = AirbnbColors.error;
        break;
      default:
        statusColor = AirbnbColors.primary;
    }
    return Tooltip(
      message: '$label ($count건)',
      child: FilterChip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? statusColor.withValues(alpha: 0.25)
                    : AirbnbColors.textSecondary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  style: AppTypography.caption,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? statusColor : AirbnbColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedStatus = value;
            _applyFilter(source: 'user');
          });
        },
        selectedColor: statusColor.withValues(alpha: 0.15),
        checkmarkColor: statusColor,
        backgroundColor: AirbnbColors.surface,
        labelStyle: TextStyle(
          color: isSelected ? statusColor : AirbnbColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
  */

  /// 견적문의 목록 (날짜별 그룹화 - 시각적 구분 강화)
  Widget _buildQuoteList() {
    if (_dateGroupedQuotes.isEmpty) {
      return const SizedBox.shrink();
    }

    // 날짜를 최신순으로 정렬
    final sortedDates = _dateGroupedQuotes.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 내림차순 (최신 날짜가 먼저)

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedDates.length,
      itemBuilder: (context, dateIndex) {
        final dateKey = sortedDates[dateIndex];
        final quotesForDate = _dateGroupedQuotes[dateKey]!;
        final isLatestGroup = dateIndex == 0; // 첫 번째 그룹이 최신

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜별 섹션 헤더
            _buildDateSectionHeader(dateKey, quotesForDate.length, isLatestGroup),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            // 해당 날짜의 견적 카드들
            ...quotesForDate.map((quote) {
              final isMobile = ResponsiveHelper.isMobile(context);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: isMobile ? 12 : 16,
                  left: isLatestGroup ? 0 : (isMobile ? 4 : 8), // 최신 그룹은 왼쪽 여백 없음
                  right: isLatestGroup ? 0 : (isMobile ? 4 : 8),
                ),
                child: _buildQuoteCardWithDateGroup(quote, isLatestGroup, context: context),
              );
            }),
            // 날짜 그룹 간 구분선 (마지막 그룹 제외)
            if (dateIndex < sortedDates.length - 1) ...[
              const SizedBox(height: 24),
              const Divider(
                thickness: 2,
                height: 2,
                color: AirbnbColors.border,
                indent: 20,
                endIndent: 20,
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }

  /// 날짜별 섹션 헤더
  Widget _buildDateSectionHeader(String dateKey, int count, bool isLatest) {
    final dateFormat = DateFormat('yyyy년 MM월 dd일');
    final parsedDate = DateFormat('yyyy.MM.dd').parse(dateKey);
    final isToday = DateFormat('yyyy.MM.dd').format(DateTime.now()) == dateKey;
    final isYesterday = DateFormat('yyyy.MM.dd').format(
      DateTime.now().subtract(const Duration(days: 1))
    ) == dateKey;

    String displayText;
    if (isToday) {
      displayText = '오늘 보낸 요청 ($count건)';
    } else if (isYesterday) {
      displayText = '어제 보낸 요청 ($count건)';
    } else {
      displayText = '${dateFormat.format(parsedDate)} 요청 ($count건)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isLatest 
            ? AirbnbColors.primary.withValues(alpha: 0.1)
            : AirbnbColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLatest 
              ? AirbnbColors.primary.withValues(alpha: 0.3)
              : AirbnbColors.border,
          width: isLatest ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isLatest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AirbnbColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '최신',
                style: TextStyle(
                  color: AirbnbColors.background,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            Icons.calendar_today,
            size: 16,
            color: isLatest ? AirbnbColors.primary : AirbnbColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            displayText,
            style: AppTypography.withColor(
              AppTypography.buttonSmall.copyWith(
                fontWeight: isLatest ? FontWeight.bold : FontWeight.w600,
              ),
              isLatest ? AirbnbColors.primary : AirbnbColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 날짜 그룹 구분이 있는 견적 카드
  Widget _buildQuoteCardWithDateGroup(QuoteRequest quote, bool isLatestGroup, {required BuildContext context}) {
    // 기존 _buildQuoteCard를 재사용하되, 최신 그룹은 강조 표시
    final baseCard = _buildQuoteCard(quote, context: context);
    
    // 최신 그룹이 아니면 약간 투명하게
    if (!isLatestGroup) {
      return Opacity(
        opacity: 0.85,
        child: baseCard,
      );
    }
    
    // 최신 그룹은 강조 테두리 추가 (기존 Container의 decoration에 추가)
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AirbnbColors.primary.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.primary.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // 내부는 2px 작게
        child: baseCard,
      ),
    );
  }

  /// 견적문의 카드
  Widget _buildQuoteCard(QuoteRequest quote, {required BuildContext context}) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');
    final isPending = quote.status == 'pending';
    final hasResponded = _hasStructuredData(quote);
    final respondedQuotes = quotes.where(_hasStructuredData).toList();
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    final cardPadding = isMobile ? 16.0 : 20.0;
    final cardBorderRadius = isMobile ? 12.0 : 16.0;
    final headerIconSize = isMobile ? 18.0 : 20.0;
    final brokerNameSize = isMobile ? 16.0 : 18.0;
    final dateSize = isMobile ? 12.0 : 13.0;
    final statusBadgePadding = isMobile 
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 5)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final statusBadgeFontSize = isMobile ? 11.0 : 12.0;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              color: isPending
                  ? AirbnbColors.warning.withValues(alpha: 0.1)
                  : AirbnbColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(cardBorderRadius),
                topRight: Radius.circular(cardBorderRadius),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 6 : 8),
                  decoration: BoxDecoration(
                    color: isPending ? AirbnbColors.warning : AirbnbColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isPending ? Icons.schedule : Icons.check_circle,
                    color: AirbnbColors.background,
                    size: headerIconSize,
                  ),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.brokerName,
                        style: TextStyle(
                          fontSize: brokerNameSize,
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        dateFormat.format(quote.requestDate),
                        style: TextStyle(fontSize: dateSize, color: AirbnbColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: statusBadgePadding,
                  decoration: BoxDecoration(
                    color: isPending ? AirbnbColors.warning : AirbnbColors.success,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPending ? '답변대기' : '답변완료',
                    style: TextStyle(
                      color: AirbnbColors.background,
                      fontSize: statusBadgeFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 내용
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 중개사 주소
                if (quote.brokerRoadAddress != null &&
                    quote.brokerRoadAddress!.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.business, size: isMobile ? 14 : 16, color: AirbnbColors.textSecondary),
                      SizedBox(width: isMobile ? 6 : 8),
                      Expanded(
                        child: Text(
                          quote.brokerRoadAddress!,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: AirbnbColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                ],

                // ========== 기본정보 ==========
                if (quote.propertyType != null ||
                    quote.propertyAddress != null ||
                    quote.propertyArea != null) ...[
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AirbnbColors.textSecondary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.home, size: isMobile ? 14 : 16, color: AirbnbColors.primary.withValues(alpha: 0.7)),
                            SizedBox(width: isMobile ? 6 : 8),
                            Text(
                              '매물 정보',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.primary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 10 : 12),
                        if (quote.propertyType != null) ...[
                          _buildInfoRow('유형', quote.propertyType!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.propertyAddress != null) ...[
                          _buildInfoRow('위치', quote.propertyAddress!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.propertyArea != null)
                          _buildInfoRow('면적', '${quote.propertyArea} ㎡', isMobile: isMobile),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                ],

                // ========== 특이사항 ==========
                if (quote.hasTenant != null ||
                    quote.desiredPrice != null ||
                    quote.targetPeriod != null ||
                    quote.specialNotes != null) ...[
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AirbnbColors.textSecondary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.edit_note,
                              size: isMobile ? 14 : 16,
                              color: AirbnbColors.warning.withValues(alpha: 0.7),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),
                            Text(
                              '특이사항',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.warning.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 10 : 12),
                        if (quote.hasTenant != null) ...[
                          _buildInfoRow('세입자', quote.hasTenant! ? '있음' : '없음', isMobile: isMobile),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (quote.desiredPrice != null &&
                            quote.desiredPrice!.isNotEmpty) ...[
                          _buildInfoRow('희망가', quote.desiredPrice!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.targetPeriod != null &&
                            quote.targetPeriod!.isNotEmpty) ...[
                          _buildInfoRow('목표기간', quote.targetPeriod!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.specialNotes != null &&
                            quote.specialNotes!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '추가사항',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: AirbnbColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                quote.specialNotes!,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  color: AirbnbColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                ],

                // ========== 중개 제안 (중개업자가 입력한 경우) ==========
                if (quote.recommendedPrice != null ||
                    quote.minimumPrice != null ||
                    quote.expectedDuration != null ||
                    quote.promotionMethod != null ||
                    quote.commissionRate != null ||
                    quote.recentCases != null) ...[
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AirbnbColors.textSecondary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.campaign,
                              size: isMobile ? 14 : 16,
                              color: AirbnbColors.success.withValues(alpha: 0.7),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),
                            Text(
                              '중개 제안',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.success.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isMobile ? 10 : 12),
                        if (quote.recommendedPrice != null &&
                            quote.recommendedPrice!.isNotEmpty) ...[
                          _buildInfoRow('권장 매도가', quote.recommendedPrice!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.minimumPrice != null &&
                            quote.minimumPrice!.isNotEmpty) ...[
                          _buildInfoRow('최저수락가', quote.minimumPrice!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.expectedDuration != null &&
                            quote.expectedDuration!.isNotEmpty) ...[
                          _buildInfoRow('예상 거래기간', quote.expectedDuration!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.promotionMethod != null &&
                            quote.promotionMethod!.isNotEmpty) ...[
                          _buildInfoRow('홍보 방법', quote.promotionMethod!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.commissionRate != null &&
                            quote.commissionRate!.isNotEmpty) ...[
                          _buildInfoRow('중개 수수료', quote.commissionRate!, isMobile: isMobile),
                          SizedBox(height: isMobile ? 6 : 8),
                        ],
                        if (quote.recentCases != null &&
                            quote.recentCases!.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '최근 유사 거래 사례',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: AirbnbColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                quote.recentCases!,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  color: AirbnbColors.textPrimary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                ],

                // ========== 공인중개사 답변 ==========
                // 답변이 있거나 상태가 answered/completed인 경우 표시 (답변 데이터가 없어도 상태 확인)
                if (quote.hasAnswer ||
                    quote.status == 'answered' ||
                    quote.status == 'completed') ...[
                  SizedBox(height: isMobile ? 12 : 16),
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: AirbnbColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AirbnbColors.textSecondary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF9C27B0,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.reply,
                                size: 16,
                                color: AirbnbColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '✅ 공인중개사 답변',
                              style: AppTypography.withColor(
                                AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                                AirbnbColors.primary,
                              ),
                            ),
                            if (quote.answerDate != null) ...[
                              const Spacer(),
                              Text(
                                DateFormat(
                                  'yyyy.MM.dd HH:mm',
                                ).format(quote.answerDate!),
                                style: AppTypography.withColor(
                                  AppTypography.caption.copyWith(fontSize: 11),
                                  AirbnbColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md + AppSpacing.xs),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isMobile ? 12 : 14),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(
                                0xFF9C27B0,
                              ).withValues(alpha: 0.2),
                            ),
                          ),
                          child:
                              quote.brokerAnswer != null &&
                                  quote.brokerAnswer!.isNotEmpty
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      quote.brokerAnswer!,
                                      style: TextStyle(
                                        fontSize: isMobile ? 13 : 14,
                                        color: AirbnbColors.textPrimary,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    Icon(
                                      Icons.hourglass_empty,
                                      size: isMobile ? 28 : 32,
                                      color: AirbnbColors.textLight,
                                    ),
                                    SizedBox(height: isMobile ? 6 : 8),
                                    Text(
                                      '답변 내용을 불러오는 중입니다...',
                                      style: TextStyle(
                                        fontSize: isMobile ? 12 : 13,
                                        color: AirbnbColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: isMobile ? 12 : 16),
                // 1줄째: 중개사 상세 / 견적 상세 (둘 다 큰 버튼)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openBrokerDetailFromQuote(quote),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.primary,
                          side: const BorderSide(
                            color: AirbnbColors.primary,
                            width: 1.5,
                          ),
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.person_search, size: isMobile ? 16 : 18),
                        label: Text(
                          isMobile ? '중개사 소개' : '중개사 소개 / 후기 보기',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showFullQuoteDetails(quote),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AirbnbColors.primary,
                          side: const BorderSide(
                            color: AirbnbColors.primary,
                            width: 1.5,
                          ),
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(Icons.visibility_outlined, size: isMobile ? 16 : 18),
                        label: Text(
                          '상세 보기',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 8),
                // 2줄째: 이 공인중개사랑 계속할래요 (응답이 있는 경우에만 표시)
                if (_hasStructuredData(quote))
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: quote.isSelectedByUser == true
                          ? null
                          : () => _onSelectBroker(quote),
                      icon: Icon(
                        quote.isSelectedByUser == true
                            ? Icons.check_circle
                            : Icons.handshake,
                        size: isMobile ? 16 : 18,
                      ),
                      label: Text(
                        quote.isSelectedByUser == true
                            ? (isMobile ? '진행 중' : '이 공인중개사와 진행 중입니다')
                            : (isMobile ? '계속 진행' : '이 공인중개사와 계속 진행할래요'),
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: quote.isSelectedByUser == true
                            ? AirbnbColors.border
                            : AirbnbColors.primary,
                        foregroundColor: quote.isSelectedByUser == true
                            ? AirbnbColors.textPrimary
                            : AirbnbColors.background,
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (_hasStructuredData(quote)) SizedBox(height: isMobile ? 6 : 8),
                // 3줄째: 비교 화면 / 중개사 재연락 (추가 기능)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: hasResponded && respondedQuotes.isNotEmpty
                        ? () {
                            AnalyticsService.instance.logEvent(
                              AnalyticsEventNames.quoteComparisonOpened,
                              params: {
                                'source': 'card_cta',
                                'brokerName': quote.brokerName,
                                'respondedQuotes': respondedQuotes.length,
                              },
                              userId: widget.userId,
                              userName: widget.userName,
                              stage: FunnelStage.selection,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuoteComparisonPage(
                                  quotes: respondedQuotes,
                                  userName: widget.userName,
                                  userId: widget.userId,
                                  selectedQuote: quote, // 선택된 견적 전달
                                ),
                              ),
                            );
                          }
                        : () => _recontactBroker(quote),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasResponded
                          ? AirbnbColors.primary
                          : AirbnbColors.primary,
                      foregroundColor: AirbnbColors.background,
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      hasResponded ? Icons.compare_outlined : Icons.phone_forwarded,
                      size: isMobile ? 16 : 18,
                    ),
                    label: Text(
                      hasResponded ? (isMobile ? '비교 화면' : '비교 화면으로 이동') : '중개사 재연락',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 8),
                // 카드에서는 후기 작성 버튼 제거 (상세 페이지에서 통합 처리)
                SizedBox(height: isMobile ? 6 : 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _deleteQuote(quote.id),
                    style: TextButton.styleFrom(
                      foregroundColor: AirbnbColors.error.withValues(alpha: 0.7),
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 6 : 8,
                      ),
                    ),
                    icon: Icon(Icons.delete_outline, size: isMobile ? 16 : 18),
                    label: Text(
                      '내역 삭제',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 내역 없음 카드
  Widget _buildEmptyCard() {
    // 🔥 게스트 모드 여부 확인
    final isGuestMode = widget.userId == null || widget.userId!.isEmpty;
    
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AirbnbColors.textSecondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGuestMode ? Icons.info_outline : Icons.inbox,
                size: 64,
                color: AirbnbColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              // 🔥 게스트 모드일 때 다른 메시지
              isGuestMode
                  ? '게스트 모드입니다'
                  : '관리 중인 견적이 없습니다',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AirbnbColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            Text(
              // 🔥 게스트 모드일 때 다른 안내 문구
              isGuestMode
                  ? '내집관리를 이용하려면\n매물상담을 먼저 진행해주세요'
                  : '공인중개사에게 문의를 보내보세요!',
              style: AppTypography.withColor(
                AppTypography.buttonSmall.copyWith(height: 1.5),
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
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AirbnbColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.filter_alt_off,
                size: 64,
                color: AirbnbColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '해당하는 문의 내역이 없습니다',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AirbnbColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md + AppSpacing.xs),
            Text(
              '다른 필터를 선택해보세요.',
              style: AppTypography.withColor(
                AppTypography.buttonSmall.copyWith(height: 1.5),
                AirbnbColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// 진행 현황 요약 타일 위젯은 더 이상 사용되지 않습니다.
