import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/responsive_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/widgets/common_design_system.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/widgets/home_logo_button.dart';
import 'package:intl/intl.dart';
import 'package:property/utils/analytics_service.dart';
import 'package:property/utils/analytics_events.dart';
import 'package:property/api_request/firebase_service.dart';

/// 견적 비교 페이지 (MVP 핵심 기능)
class QuoteComparisonPage extends StatefulWidget {
  final List<QuoteRequest> quotes;
  final String? userName; // 로그인 사용자 이름
  final String? userId; // 로그인 사용자 ID
  final QuoteRequest? selectedQuote; // 선택된 견적 (해당 매물로 자동 선택)

  const QuoteComparisonPage({
    required this.quotes,
    this.userName,
    this.userId,
    this.selectedQuote,
    super.key,
  });

  @override
  State<QuoteComparisonPage> createState() => _QuoteComparisonPageState();
}

class _QuoteComparisonPageState extends State<QuoteComparisonPage> {
  final FirebaseService _firebaseService = FirebaseService();

  /// 이 화면에서 사용자가 선택 완료한 견적 ID
  String? _selectedQuoteId;
  bool _isAssigning = false;
  
  /// 선택된 매물 주소 (탭 인덱스)
  int _selectedPropertyIndex = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logEvent(
      AnalyticsEventNames.quoteComparisonPageOpened,
      params: {'quoteCount': widget.quotes.length},
      userId: widget.userId,
      userName: widget.userName,
      stage: FunnelStage.selection,
    );
    
    // 선택된 견적이 있으면 해당 매물의 인덱스를 찾아서 설정
    if (widget.selectedQuote != null) {
      _initializeSelectedPropertyIndex(widget.selectedQuote!);
    }
  }
  
  /// 선택된 견적의 매물 인덱스를 찾아서 설정
  void _initializeSelectedPropertyIndex(QuoteRequest selectedQuote) {
    // 답변 완료된 견적만 필터
    final respondedQuotes = widget.quotes.where((q) {
      return (q.recommendedPrice != null && q.recommendedPrice!.isNotEmpty) ||
             (q.minimumPrice != null && q.minimumPrice!.isNotEmpty);
    }).toList();
    
    // 매물별로 견적 그룹화
    final groupedQuotes = _groupQuotesByProperty(respondedQuotes);
    final propertyKeys = groupedQuotes.keys.toList();
    
    // 주소 없는 견적 제외
    if (groupedQuotes.containsKey('주소없음') && groupedQuotes.length > 1) {
      propertyKeys.remove('주소없음');
    }
    
    // 선택된 견적의 매물 키 찾기
    final selectedPropertyKey = _getPropertyKey(selectedQuote);
    
    // 해당 키의 인덱스 찾기
    final index = propertyKeys.indexWhere((key) => key == selectedPropertyKey);
    if (index != -1) {
      _selectedPropertyIndex = index;
    }
  }

  /// 사용자가 특정 공인중개사를 최종 선택할 때 호출
  Future<void> _onSelectBroker(QuoteRequest quote) async {
    // 이미 이 화면에서 선택 완료된 견적이면 다시 처리하지 않음
    if (_selectedQuoteId == quote.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 이 공인중개사와 진행 중입니다.'),
            backgroundColor: AirbnbColors.background, // 에어비엔비 스타일: 흰색 배경
          ),
        );
      }
      return;
    }

    // 로그인 여부 확인 (userId 필요)
    if (widget.userId == null || widget.userId!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인 후에 공인중개사를 선택할 수 있습니다.'),
            backgroundColor: AirbnbColors.warning,
          ),
        );
      }
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

    // 로딩 다이얼로그
    setState(() {
      _isAssigning = true;
    });
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
        setState(() {
          _selectedQuoteId = quote.id;
          _isAssigning = false;
        });
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
        setState(() {
          _isAssigning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공인중개사 선택 처리 중 오류가 발생했습니다. 다시 시도해주세요.'),
            backgroundColor: AirbnbColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기
      setState(() {
        _isAssigning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다: $e'),
          backgroundColor: AirbnbColors.error,
        ),
      );
    }
  }

  /// 가격 문자열에서 숫자 추출
  int? _extractPrice(String? priceStr) {
    if (priceStr == null || priceStr.isEmpty) return null;
    
    // "2억 5천만원", "250000000", "2.5억" 등 다양한 형식 처리
    final cleanStr = priceStr.replaceAll(RegExp(r'[^0-9억천만원\.]'), '');
    
    // "억" 처리
    if (cleanStr.contains('억')) {
      final parts = cleanStr.split('억');
      double? eok = double.tryParse(parts[0].replaceAll(RegExp(r'[^0-9\.]'), ''));
      if (eok == null) return null;
      
      int total = (eok * 100000000).toInt();
      
      // "천만", "만" 처리
      if (parts.length > 1) {
        final remainder = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
        if (remainder.isNotEmpty) {
          final remainderInt = int.tryParse(remainder);
          if (remainderInt != null) {
            // "천만" 또는 "만" 구분
            if (parts[1].contains('천만')) {
              total += remainderInt * 10000000;
            } else if (parts[1].contains('만')) {
              total += remainderInt * 10000;
            } else {
              // 숫자만 있으면 만원 단위로 가정
              total += remainderInt * 10000;
            }
          }
        }
      }
      
      return total;
    }
    
    // 숫자만 있는 경우
    final digits = cleanStr.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits);
  }

  /// 가격 포맷팅
  String _formatPrice(int price) {
    if (price >= 100000000) {
      final eok = price / 100000000;
      if (eok == eok.roundToDouble()) {
        return '${eok.toInt()}억원';
      }
      return '${eok.toStringAsFixed(1)}억원';
    } else if (price >= 10000) {
      final man = price / 10000;
      return '${man.toInt()}만원';
    }
    return '$price원';
  }

  /// 수수료율 문자열에서 숫자 추출 (예: "0.3%", "5%", "0.5%" -> 0.3, 5.0, 0.5)
  double? _extractCommissionRate(String? rateStr) {
    if (rateStr == null || rateStr.isEmpty) return null;
    
    // "%" 제거하고 숫자만 추출
    final cleanStr = rateStr.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleanStr.isEmpty) return null;
    
    return double.tryParse(cleanStr);
  }

  /// 수수료율 포맷팅
  String _formatCommissionRate(double rate) {
    // 소수점이 있으면 그대로, 없으면 정수로 표시
    if (rate == rate.roundToDouble()) {
      return '${rate.toInt()}%';
    }
    return '${rate.toStringAsFixed(1)}%';
  }

  /// 주소 정규화 함수 (공백 제거, 대소문자 통일, 약칭 통일)
  String _normalizeAddress(String address) {
    return address
        .replaceAll(RegExp(r'\s+'), '') // 모든 공백 제거
        .replaceAll('서울시', '서울특별시')
        .replaceAll('부산시', '부산광역시')
        .replaceAll('대구시', '대구광역시')
        .replaceAll('인천시', '인천광역시')
        .replaceAll('광주시', '광주광역시')
        .replaceAll('대전시', '대전광역시')
        .replaceAll('울산시', '울산광역시')
        .replaceAll('경기', '경기도')
        .toLowerCase();
  }

  /// 매물 식별 키 생성 (주소 + 유형 + 면적)
  String _getPropertyKey(QuoteRequest quote) {
    final address = quote.propertyAddress ?? '주소없음';
    final type = quote.propertyType ?? '';
    final area = quote.propertyArea ?? '';
    
    // 주소 정규화
    final normalizedAddress = _normalizeAddress(address);
    
    // 키 생성: 주소 + 유형 + 면적 (면적은 반올림하여 유사한 면적은 같은 그룹으로)
    String areaKey = '';
    if (area.isNotEmpty) {
      final areaNum = double.tryParse(area.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (areaNum != null) {
        // 5㎡ 단위로 반올림 (예: 84㎡와 86㎡는 같은 그룹)
        final roundedArea = (areaNum / 5).round() * 5;
        areaKey = '${roundedArea.toInt()}㎡';
      }
    }
    
    return '$normalizedAddress|$type|$areaKey';
  }

  /// 매물별로 견적 그룹화 (주소 + 유형 + 면적 기준)
  Map<String, List<QuoteRequest>> _groupQuotesByProperty(List<QuoteRequest> quotes) {
    final Map<String, List<QuoteRequest>> grouped = {};
    
    for (final quote in quotes) {
      if (quote.propertyAddress == null || quote.propertyAddress!.isEmpty) {
        // 주소가 없는 견적은 별도 그룹
        const key = '주소없음';
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(quote);
      } else {
        final key = _getPropertyKey(quote);
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(quote);
      }
    }
    
    return grouped;
  }

  /// 매물 표시 이름 생성 (주소 + 유형 + 면적)
  String _buildPropertyDisplayName(QuoteRequest quote) {
    final parts = <String>[];
    
    if (quote.propertyAddress != null && quote.propertyAddress!.isNotEmpty) {
      parts.add(quote.propertyAddress!);
    }
    
    if (quote.propertyType != null && quote.propertyType!.isNotEmpty) {
      parts.add(quote.propertyType!);
    }
    
    if (quote.propertyArea != null && quote.propertyArea!.isNotEmpty) {
      parts.add('${quote.propertyArea}㎡');
    }
    
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    // 답변 완료된 견적만 필터 (recommendedPrice 또는 minimumPrice가 있는 것)
    final respondedQuotes = widget.quotes.where((q) {
      return (q.recommendedPrice != null && q.recommendedPrice!.isNotEmpty) ||
             (q.minimumPrice != null && q.minimumPrice!.isNotEmpty);
    }).toList();

    if (respondedQuotes.isEmpty) {
      return Scaffold(
        backgroundColor: AirbnbColors.surface,
        appBar: AppBar(
          backgroundColor: AirbnbColors.background,
          foregroundColor: AirbnbColors.primary,
          elevation: 0.5,
          title: HomeLogoButton(
            fontSize: AppTypography.h4.fontSize!,
            color: AirbnbColors.primary,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.compare_arrows,
                size: 80,
                color: AirbnbColors.textLight,
              ),
              const SizedBox(height: 24),
              Text(
                '확인할 견적이 없습니다',
                style: AppTypography.withColor(
                  AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                  AirbnbColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '공인중개사로부터 답변을 받으면\n여기서 견적을 비교할 수 있습니다',
                textAlign: TextAlign.center,
                style: AppTypography.withColor(
                  AppTypography.bodySmall,
                  AirbnbColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 매물별로 견적 그룹화
    final groupedQuotes = _groupQuotesByProperty(respondedQuotes);
    final propertyKeys = groupedQuotes.keys.toList();
    
    // 주소가 없는 견적이 있으면 경고 표시
    final hasNoAddressQuotes = groupedQuotes.containsKey('주소없음');
    if (hasNoAddressQuotes && groupedQuotes.length > 1) {
      // 주소 없는 견적 제외하고 표시
      propertyKeys.remove('주소없음');
    }
    
    if (propertyKeys.isEmpty) {
      return Scaffold(
        backgroundColor: AirbnbColors.surface,
        appBar: AppBar(
          backgroundColor: AirbnbColors.background,
          foregroundColor: AirbnbColors.primary,
          elevation: 0.5,
          title: HomeLogoButton(
            fontSize: AppTypography.h4.fontSize!,
            color: AirbnbColors.primary,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: AirbnbColors.warning.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 24),
              Text(
                '확인할 견적이 없습니다',
                style: AppTypography.withColor(
                  AppTypography.h3.copyWith(fontWeight: FontWeight.bold),
                  AirbnbColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '매물 주소 정보가 있는 견적만 비교할 수 있습니다',
                textAlign: TextAlign.center,
                style: AppTypography.withColor(
                  AppTypography.bodySmall,
                  AirbnbColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // 선택된 매물이 유효한지 확인
    if (_selectedPropertyIndex >= propertyKeys.length) {
      _selectedPropertyIndex = 0;
    }
    
    final selectedPropertyKey = propertyKeys[_selectedPropertyIndex];
    final selectedPropertyQuotes = groupedQuotes[selectedPropertyKey]!;
    
    // 선택된 매물의 견적에서 가격 추출 및 정렬
    final quotePrices = selectedPropertyQuotes.map((q) {
      final priceStr = q.recommendedPrice ?? q.minimumPrice;
      final price = _extractPrice(priceStr);
      return {
        'quote': q,
        'price': price,
        'priceStr': priceStr,
      };
    }).where((item) => item['price'] != null).toList();

    if (quotePrices.isEmpty) {
      return Scaffold(
        backgroundColor: AirbnbColors.surface,
        appBar: AppBar(
          backgroundColor: AirbnbColors.background,
          foregroundColor: AirbnbColors.primary,
          elevation: 0.5,
          title: HomeLogoButton(
            fontSize: AppTypography.h4.fontSize!,
            color: AirbnbColors.primary,
          ),
        ),
        body: const Center(
          child: Text('가격 정보가 없는 견적만 있습니다.'),
        ),
      );
    }

    // 가격 정렬
    quotePrices.sort((a, b) {
      final aPrice = a['price'] as int?;
      final bPrice = b['price'] as int?;
      if (aPrice == null && bPrice == null) return 0;
      if (aPrice == null) return 1;
      if (bPrice == null) return -1;
      return aPrice.compareTo(bPrice);
    });

    final prices = quotePrices.map((item) => item['price'] as int).toList();
    final minPrice = prices.first;
    final maxPrice = prices.last;
    // 평균가 계산: 항상 표시되도록 보장
    final avgPrice = prices.isNotEmpty 
        ? (prices.reduce((a, b) => a + b) / prices.length).round()
        : 0;

    // 수수료율 추출 및 비교
    final commissionRates = quotePrices.map((item) {
      final quote = item['quote'] as QuoteRequest;
      final rate = _extractCommissionRate(quote.commissionRate);
      return {
        'quote': quote,
        'rate': rate,
        'rateStr': quote.commissionRate,
      };
    }).where((item) => item['rate'] != null).toList();
    
    double? minCommissionRate;
    double? maxCommissionRate;
    double? avgCommissionRate;
    
    // 평균율 계산: 수수료율이 있을 때만 계산
    if (commissionRates.isNotEmpty) {
      final rates = commissionRates.map((item) => item['rate'] as double).toList();
      minCommissionRate = rates.reduce((a, b) => a < b ? a : b);
      maxCommissionRate = rates.reduce((a, b) => a > b ? a : b);
      avgCommissionRate = rates.reduce((a, b) => a + b) / rates.length;
    }

    final dateFormat = DateFormat('yyyy.MM.dd');

    // 반응형 레이아웃: 표준화된 반응형 디자인 사용
    final maxWidth = ResponsiveHelper.getMaxWidth(context);
    final horizontalPadding = ResponsiveHelper.getHorizontalPadding(context);
    final cardSpacing = ResponsiveHelper.getCardSpacing(context);
    final columns = ResponsiveHelper.getGridColumns(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isWeb = ResponsiveHelper.isWeb(context);
    
    // 표시용 이름 생성
    final displayName = _buildPropertyDisplayName(selectedPropertyQuotes.first);

    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        backgroundColor: AirbnbColors.background,
        foregroundColor: AirbnbColors.primary,
        elevation: 0.5,
        title: HomeLogoButton(
          fontSize: AppTypography.h4.fontSize!,
          color: AirbnbColors.primary,
        ),
        actions: [
          AccessibleWidget.iconButton(
            icon: Icons.info_outline,
            tooltip: '견적 비교 가이드',
            semanticLabel: '견적 비교 가이드 보기',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.compare_arrows, color: AirbnbColors.primary, size: 24),
                      SizedBox(width: AppSpacing.sm),
                      const Text('견적 비교 가이드'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '📊 견적 비교 방법',
                          style: AppTypography.h4.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: AppSpacing.md),
                        _buildGuideItem('매물별로 탭을 선택하여 각 매물의 견적을 비교하세요'),
                        _buildGuideItem('최저가: 가장 낮은 견적 (초록색으로 강조)'),
                        _buildGuideItem('평균가: 모든 견적의 평균'),
                        _buildGuideItem('최고가: 가장 높은 견적'),
                        SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AirbnbColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AirbnbColors.success.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.checklist, color: AirbnbColors.success, size: 20),
                                  SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '안전한 거래 체크리스트',
                                    style: AppTypography.body.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AirbnbColors.success,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppSpacing.sm),
                              _buildChecklistItem('✅ 중개사 등록번호 확인'),
                              _buildChecklistItem('✅ 견적서에 명시된 조건 확인'),
                              _buildChecklistItem('✅ 수수료율 비교 (중요!)'),
                              _buildChecklistItem('✅ 예상 거래기간 확인'),
                              _buildChecklistItem('✅ 추가 메시지 내용 검토'),
                              SizedBox(height: AppSpacing.sm),
                              Text(
                                '💡 팁: 최저가만 보고 선택하지 마세요.\n수수료율과 거래 조건도 함께 비교하세요!',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AirbnbColors.textSecondary,
                                  fontStyle: FontStyle.italic,
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text('확인'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 주소 없는 견적 경고 (있는 경우)
          if (hasNoAddressQuotes && groupedQuotes['주소없음']!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
              color: AirbnbColors.warning.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AirbnbColors.warning, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '주소 정보가 없는 견적 ${groupedQuotes['주소없음']!.length}개가 제외되었습니다.',
                      style: AppTypography.withColor(AppTypography.caption, AirbnbColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          
          // 매물 선택 탭 (여러 매물이 있는 경우에만 표시)
          if (propertyKeys.length > 1)
            Container(
              color: AirbnbColors.background,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16, 
                vertical: isMobile ? 6 : 8
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(propertyKeys.length, (index) {
                    final key = propertyKeys[index];
                    final quotes = groupedQuotes[key]!;
                    final isSelected = index == _selectedPropertyIndex;
                    final quoteCount = quotes.length;
                    final displayName = _buildPropertyDisplayName(quotes.first);
                    final maxLength = isMobile ? 20 : 25;
                    
                    return Padding(
                      padding: EdgeInsets.only(right: isMobile ? 6 : 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                displayName.length > maxLength 
                                    ? '${displayName.substring(0, maxLength)}...' 
                                    : displayName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            SizedBox(width: isMobile ? 3 : 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 5 : 6, 
                                vertical: 2
                              ),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AirbnbColors.background.withValues(alpha: 0.3)
                                    : AirbnbColors.textSecondary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$quoteCount',
                                style: TextStyle(
                                  fontSize: isMobile ? 10 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? AirbnbColors.background : AirbnbColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedPropertyIndex = index;
                            });
                          }
                        },
                        selectedColor: AirbnbColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AirbnbColors.background : AirbnbColors.textSecondary,
                        ),
                        backgroundColor: AirbnbColors.borderLight,
                      ),
                    );
                  }),
                ),
              ),
            ),
          
          // 견적 비교 내용
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, 
                vertical: isMobile ? 12.0 : (isWeb ? 32.0 : 16.0)
              ),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 선택된 매물 정보 표시 (여러 매물이 있거나 상세 정보가 있는 경우)
                      if (propertyKeys.length > 1 || 
                          selectedPropertyQuotes.first.propertyType != null ||
                          selectedPropertyQuotes.first.propertyArea != null)
                        Container(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color: AirbnbColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AirbnbColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.home, 
                                    color: AirbnbColors.primary, 
                                    size: isMobile ? 18 : 20
                                  ),
                                  SizedBox(width: isMobile ? 6 : 8),
                                  Expanded(
                                    child: Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: isMobile ? 13 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: AirbnbColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              // 매물 상세 정보 (유형, 면적)
                              if (selectedPropertyQuotes.first.propertyType != null ||
                                  selectedPropertyQuotes.first.propertyArea != null) ...[
                                SizedBox(height: isMobile ? 6 : 8),
                                Row(
                                  children: [
                                    if (selectedPropertyQuotes.first.propertyType != null) ...[
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isMobile ? 6 : 8, 
                                          vertical: isMobile ? 3 : 4
                                        ),
                                        decoration: BoxDecoration(
                                          color: AirbnbColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          selectedPropertyQuotes.first.propertyType!,
                                          style: TextStyle(
                                            fontSize: isMobile ? 11 : 12,
                                            color: AirbnbColors.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isMobile ? 6 : 8),
                                    ],
                                    if (selectedPropertyQuotes.first.propertyArea != null)
                                      Text(
                                        '${selectedPropertyQuotes.first.propertyArea}㎡',
                                        style: TextStyle(
                                          fontSize: isMobile ? 11 : 12,
                                          color: AirbnbColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      
                      // 요약 카드 (PC에서는 더 크고 눈에 띄게)
                      Container(
                        padding: EdgeInsets.all(isMobile ? 16.0 : (isWeb ? 32.0 : 24.0)),
                        decoration: BoxDecoration(
                          color: AirbnbColors.background,
                          borderRadius: BorderRadius.circular(isMobile ? 16.0 : (isWeb ? 24.0 : 20.0)),
                          boxShadow: [
                            BoxShadow(
                              color: AirbnbColors.primary.withValues(alpha: 0.3),
                              blurRadius: isMobile ? 16.0 : (isWeb ? 24.0 : 20.0),
                              offset: Offset(0, isMobile ? 4 : 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 가격 비교 (1행)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: _buildSummaryItem('최저가', _formatPrice(minPrice), AirbnbColors.success.withValues(alpha: 0.1), isMobile, isWeb),
                                ),
                                SizedBox(width: isMobile ? 8.0 : (isWeb ? 20.0 : 12.0)),
                                Expanded(
                                  child: _buildSummaryItem('평균가', _formatPrice(avgPrice), AirbnbColors.background, isMobile, isWeb),
                                ),
                                SizedBox(width: isMobile ? 8.0 : (isWeb ? 20.0 : 12.0)),
                                Expanded(
                                  child: _buildSummaryItem('최고가', _formatPrice(maxPrice), AirbnbColors.error.withValues(alpha: 0.1), isMobile, isWeb),
                                ),
                              ],
                            ),
                            // 수수료율 비교 (2행) - 큰 글씨로 강조 (평균율이 있으면 표시)
                            if (minCommissionRate != null && maxCommissionRate != null) ...[
                              SizedBox(height: isMobile ? 16.0 : (isWeb ? 24.0 : 20.0)),
                              Container(
                                padding: EdgeInsets.all(isMobile ? 16.0 : (isWeb ? 24.0 : 20.0)),
                                decoration: BoxDecoration(
                                  // 수수료율 섹션: 명확한 배경으로 가독성 향상
                                  color: AirbnbColors.background.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AirbnbColors.background,
                                    width: 2.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.percent,
                                          color: AirbnbColors.background,
                                          size: isMobile ? 22.0 : (isWeb ? 30.0 : 26.0),
                                        ),
                                        SizedBox(width: isMobile ? 8.0 : (isWeb ? 12.0 : 8.0)),
                                        Text(
                                          '수수료율 비교',
                                          style: TextStyle(
                                            color: AirbnbColors.background,
                                            fontSize: isMobile ? 16.0 : (isWeb ? 20.0 : 18.0),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 16.0 : (isWeb ? 24.0 : 20.0)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: _buildCommissionRateItem(
                                            '최저율',
                                            _formatCommissionRate(minCommissionRate),
                                            AirbnbColors.success.withValues(alpha: 0.2),
                                            isMobile,
                                            isWeb,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8.0 : (isWeb ? 20.0 : 12.0)),
                                        Expanded(
                                          child: _buildCommissionRateItem(
                                            '평균율',
                                            avgCommissionRate != null 
                                                ? _formatCommissionRate(avgCommissionRate)
                                                : '-',
                                            AirbnbColors.background,
                                            isMobile,
                                            isWeb,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8.0 : (isWeb ? 20.0 : 12.0)),
                                        Expanded(
                                          child: _buildCommissionRateItem(
                                            '최고율',
                                            _formatCommissionRate(maxCommissionRate),
                                            AirbnbColors.error.withValues(alpha: 0.2),
                                            isMobile,
                                            isWeb,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: isMobile ? 16.0 : (isWeb ? 24.0 : 20.0)),
                            Container(
                              padding: EdgeInsets.all(isMobile ? 10.0 : (isWeb ? 16.0 : 12.0)),
                              decoration: BoxDecoration(
                                color: AirbnbColors.background.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline, 
                                    color: AirbnbColors.background, 
                                    size: isMobile ? 18.0 : (isWeb ? 24.0 : 20.0)
                                  ),
                                  SizedBox(width: isMobile ? 8.0 : (isWeb ? 12.0 : 8.0)),
                                  Text(
                                    '${quotePrices.length}개 견적 비교 중',
                                    style: TextStyle(
                                      color: AirbnbColors.background,
                                      fontSize: isMobile ? 12.0 : (isWeb ? 16.0 : 14.0),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 20.0 : (isWeb ? 32.0 : 24.0)),

                      // 견적 목록
                      Text(
                        '견적 상세',
                        style: TextStyle(
                          fontSize: isMobile ? 18.0 : (isWeb ? 24.0 : 20.0),
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.textPrimary,
                        ),
                      ),

                      SizedBox(height: isMobile ? 12.0 : (isWeb ? 24.0 : 16.0)),

                      // 견적 목록 (PC에서는 그리드, 모바일에서는 리스트)
                      isWeb
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                final cardWidth = (availableWidth - (cardSpacing * (columns - 1))) / columns;
                                
                                return Wrap(
                                  spacing: cardSpacing,
                                  runSpacing: cardSpacing,
                                  alignment: WrapAlignment.start,
                                  children: quotePrices.map((item) {
                                    final quote = item['quote'] as QuoteRequest;
                                    final isAlreadySelected = quote.isSelectedByUser == true;
                                    final isSelectedHere = _selectedQuoteId == quote.id;
                                    final price = item['price'] as int;
                                    final priceStr = item['priceStr'] as String?;
                                    final isLowest = price == minPrice;
                                    final isHighest = price == maxPrice;

                                    return SizedBox(
                                      width: cardWidth,
                                      child: _buildQuoteCard(
                                        quote: quote,
                                        isAlreadySelected: isAlreadySelected,
                                        isSelectedHere: isSelectedHere,
                                        price: price,
                                        priceStr: priceStr,
                                        isLowest: isLowest,
                                        isHighest: isHighest,
                                        minPrice: minPrice,
                                        dateFormat: dateFormat,
                                        isMobile: isMobile,
                                        isWeb: isWeb,
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            )
                          : Column(
                              children: quotePrices.map((item) {
                                final quote = item['quote'] as QuoteRequest;
                                final isAlreadySelected = quote.isSelectedByUser == true;
                                final isSelectedHere = _selectedQuoteId == quote.id;
                                final price = item['price'] as int;
                                final priceStr = item['priceStr'] as String?;
                                final isLowest = price == minPrice;
                                final isHighest = price == maxPrice;

                                return _buildQuoteCard(
                                  quote: quote,
                                  isAlreadySelected: isAlreadySelected,
                                  isSelectedHere: isSelectedHere,
                                  price: price,
                                  priceStr: priceStr,
                                  isLowest: isLowest,
                                  isHighest: isHighest,
                                  minPrice: minPrice,
                                  dateFormat: dateFormat,
                                  isMobile: isMobile,
                                  isWeb: false,
                                );
                              }).toList(),
                            ),
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

  /// 견적 카드 위젯 (재사용 가능하도록 분리)
  Widget _buildQuoteCard({
    required QuoteRequest quote,
    required bool isAlreadySelected,
    required bool isSelectedHere,
    required int price,
    required String? priceStr,
    required bool isLowest,
    required bool isHighest,
    required int minPrice,
    required DateFormat dateFormat,
    required bool isMobile,
    required bool isWeb,
  }) {
    final cardPadding = isMobile ? 16.0 : (isWeb ? 24.0 : 20.0);
    final borderRadius = isMobile ? 12.0 : (isWeb ? 20.0 : 16.0);
    
    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 0 : 16),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(borderRadius),
        border: isLowest
            ? Border.all(color: AirbnbColors.success, width: isWeb ? 4 : 3)
            : Border.all(color: AirbnbColors.textSecondary.withValues(alpha: 0.2), width: isWeb ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: isLowest
                ? AirbnbColors.success.withValues(alpha: 0.2)
                : AirbnbColors.textPrimary.withValues(alpha: 0.08),
            blurRadius: isWeb ? (isLowest ? 16 : 12) : (isLowest ? 12 : 8),
            offset: Offset(0, isWeb ? 6 : 4),
            spreadRadius: isWeb ? 1 : 0,
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
              color: isLowest
                  ? AirbnbColors.success.withValues(alpha: 0.1)
                  : isHighest
                      ? AirbnbColors.error.withValues(alpha: 0.1)
                      : AirbnbColors.textSecondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(borderRadius),
                topRight: Radius.circular(borderRadius),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.brokerName,
                        style: TextStyle(
                          fontSize: isMobile ? 16.0 : (isWeb ? 20.0 : 18.0),
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.textPrimary,
                        ),
                      ),
                      if (quote.answerDate != null) ...[
                        SizedBox(height: isMobile ? 4 : (isWeb ? 6 : 4)),
                        Text(
                          '답변일: ${dateFormat.format(quote.answerDate!)}',
                          style: TextStyle(
                            fontSize: isMobile ? 11.0 : (isWeb ? 13.0 : 12.0),
                            color: AirbnbColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isLowest)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : (isWeb ? 16 : 12),
                      vertical: isMobile ? 5 : (isWeb ? 8 : 6),
                    ),
                    decoration: BoxDecoration(
                      color: AirbnbColors.success,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '최저가',
                      style: TextStyle(
                        color: AirbnbColors.background,
                        fontSize: isMobile ? 11.0 : (isWeb ? 13.0 : 12.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isHighest && !isLowest)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : (isWeb ? 16 : 12),
                      vertical: isMobile ? 5 : (isWeb ? 8 : 6),
                    ),
                    decoration: BoxDecoration(
                      color: AirbnbColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '최고가',
                      style: TextStyle(
                        color: AirbnbColors.background,
                        fontSize: isMobile ? 11.0 : (isWeb ? 13.0 : 12.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 가격 정보 + 세부 정보 + 선택 버튼
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 가격과 수수료율을 함께 표시 (수수료율 강조)
                Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 14.0 : (isWeb ? 20.0 : 16.0)),
                      decoration: BoxDecoration(
                        color: isLowest
                            ? AirbnbColors.success.withValues(alpha: 0.05)
                            : AirbnbColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLowest
                              ? AirbnbColors.success.withValues(alpha: 0.3)
                              : AirbnbColors.textSecondary.withValues(alpha: 0.2),
                          width: isMobile ? 1 : (isWeb ? 1.5 : 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.attach_money,
                                color: isLowest
                                    ? AirbnbColors.success.withValues(alpha: 0.7)
                                    : AirbnbColors.textPrimary,
                                size: isMobile ? 18.0 : (isWeb ? 22.0 : 20.0),
                              ),
                              SizedBox(width: isMobile ? 6.0 : (isWeb ? 8.0 : 6.0)),
                              Text(
                                '예상 금액',
                                style: TextStyle(
                                  fontSize: isMobile ? 14.0 : (isWeb ? 18.0 : 16.0),
                                  fontWeight: FontWeight.w600,
                                  color: AirbnbColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            priceStr ?? _formatPrice(price),
                            style: TextStyle(
                              fontSize: isMobile ? 20.0 : (isWeb ? 28.0 : 24.0),
                              fontWeight: FontWeight.bold,
                              color: isLowest
                                  ? AirbnbColors.success.withValues(alpha: 0.7)
                                  : AirbnbColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // 수수료율을 큰 글씨로 강조 표시
                    if (quote.commissionRate != null &&
                        quote.commissionRate!.isNotEmpty) ...[
                      SizedBox(height: isMobile ? 10.0 : (isWeb ? 16.0 : 12.0)),
                      Container(
                        padding: EdgeInsets.all(isMobile ? 14.0 : (isWeb ? 20.0 : 16.0)),
                        decoration: BoxDecoration(
                          // 수수료율: 명확한 배경색으로 가독성 향상
                          color: AirbnbColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AirbnbColors.primary,
                            width: isMobile ? 1.5 : (isWeb ? 2 : 1.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.percent,
                                  color: AirbnbColors.textPrimary, // 진한 회색으로 변경
                                  size: isMobile ? 18.0 : (isWeb ? 24.0 : 20.0),
                                ),
                                SizedBox(width: isMobile ? 6.0 : (isWeb ? 10.0 : 8.0)),
                                Text(
                                  '수수료율',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14.0 : (isWeb ? 18.0 : 16.0),
                                    fontWeight: FontWeight.w600,
                                    color: AirbnbColors.textPrimary, // 진한 회색으로 변경
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              quote.commissionRate!,
                              style: TextStyle(
                                fontSize: isMobile ? 24.0 : (isWeb ? 32.0 : 28.0),
                                fontWeight: FontWeight.bold,
                                color: AirbnbColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                if (quote.expectedDuration != null &&
                    quote.expectedDuration!.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 14.0 : (isWeb ? 20.0 : 16.0)),
                  _buildInfoRow('예상 거래기간', quote.expectedDuration!, isMobile, isWeb),
                ],

                if (quote.brokerAnswer != null &&
                    quote.brokerAnswer!.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 14.0 : (isWeb ? 20.0 : 16.0)),
                  Container(
                    padding: EdgeInsets.all(isMobile ? 10.0 : (isWeb ? 16.0 : 12.0)),
                    decoration: BoxDecoration(
                      color: AirbnbColors.textSecondary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '추가 메시지',
                          style: TextStyle(
                            fontSize: isMobile ? 11.0 : (isWeb ? 13.0 : 12.0),
                            fontWeight: FontWeight.w600,
                            color: AirbnbColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: isMobile ? 6.0 : (isWeb ? 10.0 : 8.0)),
                        Text(
                          quote.brokerAnswer!,
                          style: TextStyle(
                            fontSize: isMobile ? 13.0 : (isWeb ? 15.0 : 14.0),
                            color: AirbnbColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: isMobile ? 16.0 : (isWeb ? 24.0 : 20.0)),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isAssigning || isAlreadySelected || isSelectedHere)
                        ? null
                        : () => _onSelectBroker(quote),
                    icon: Icon(
                      isAlreadySelected || isSelectedHere
                          ? Icons.check_circle
                          : Icons.handshake,
                      size: isMobile ? 16 : 18,
                    ),
                    label: Text(
                      isAlreadySelected || isSelectedHere
                          ? (isMobile ? '진행 중' : '이 공인중개사와 진행 중입니다')
                          : (isMobile ? '계속 진행' : '이 공인중개사와 계속 진행할래요'),
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAlreadySelected || isSelectedHere
                          ? AirbnbColors.border
                          : AirbnbColors.primary,
                      foregroundColor: isAlreadySelected || isSelectedHere
                          ? AirbnbColors.textPrimary
                          : AirbnbColors.background,
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildSummaryItem(String label, String value, Color bgColor, bool isMobile, bool isWeb) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12.0 : (isWeb ? 20.0 : 16.0)),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 12.0 : (isWeb ? 14.0 : 13.0),
                color: AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isMobile ? 6.0 : (isWeb ? 12.0 : 8.0)),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 18.0 : (isWeb ? 24.0 : 20.0),
                fontWeight: FontWeight.bold,
                color: bgColor == AirbnbColors.background ? AirbnbColors.background : AirbnbColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 수수료율 아이템 (명확한 가독성을 위한 단순한 디자인)
  Widget _buildCommissionRateItem(String label, String value, Color bgColor, bool isMobile, bool isWeb) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12.0 : (isWeb ? 20.0 : 16.0)),
        decoration: BoxDecoration(
          // 단순하고 명확한 배경색
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AirbnbColors.background.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 13.0 : (isWeb ? 15.0 : 14.0),
                color: bgColor == AirbnbColors.background ? AirbnbColors.background : AirbnbColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isMobile ? 6.0 : (isWeb ? 12.0 : 8.0)),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 24.0 : (isWeb ? 32.0 : 28.0),
                fontWeight: FontWeight.bold,
                color: bgColor == AirbnbColors.background ? AirbnbColors.background : AirbnbColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isMobile, bool isWeb) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? 80.0 : (isWeb ? 120.0 : 100.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 13.0 : (isWeb ? 15.0 : 14.0),
              color: AirbnbColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 13.0 : (isWeb ? 15.0 : 14.0),
              color: AirbnbColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
  
  /// 가이드 아이템 위젯
  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: AppTypography.body.copyWith(color: AirbnbColors.primary)),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 체크리스트 아이템 위젯
  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: AirbnbColors.success),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

