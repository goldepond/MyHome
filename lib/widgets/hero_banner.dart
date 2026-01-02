import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';
import 'common_design_system.dart';

class HeroBanner extends StatefulWidget {
  final TextEditingController? searchController;
  final VoidCallback? onSearchSubmitted;
  final Function(String)? onSearchChanged;
  final bool showSearchBar;
  
  const HeroBanner({
    super.key,
    this.searchController,
    this.onSearchSubmitted,
    this.onSearchChanged,
    this.showSearchBar = true,
  });

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    widget.searchController?.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    widget.searchController?.removeListener(_onSearchTextChanged);
    super.dispose();
  }

  void _onSearchTextChanged() {
    final hasText = widget.searchController?.text.isNotEmpty ?? false;
    if (_hasSearchText != hasText) {
      setState(() {
        _hasSearchText = hasText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? AppSpacing.xxl : AppSpacing.xxxl, // 48px / 64px
        horizontal: isMobile ? AppSpacing.lg : AppSpacing.xxl, // 24px / 48px
      ),
      decoration: const BoxDecoration(
        color: AirbnbColors.background,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1200, // 더 넓은 최대 너비
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 매우 큰 헤드라인 (Stripe/Vercel 스타일)
            Text(
              '처음이라도 부담 없이,\n비대면으로 문의하세요',
              textAlign: TextAlign.center,
              style: AppTypography.withColor(
                AppTypography.display.copyWith(
                  fontSize: isMobile ? 40 : (isTablet ? 52 : 64), // 40px / 52px / 64px
                  fontWeight: FontWeight.w800, // w900보다 약간 가벼운
                  letterSpacing: -1.5,
                  height: 1.1, // 타이트한 줄 간격
                ),
                AirbnbColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg), // 24px
            
            // 큰 서브헤드
            Text(
              '나가지 않아도, 집에서 편하게 문의하세요',
              textAlign: TextAlign.center,
              style: AppTypography.withColor(
                AppTypography.bodyLarge.copyWith(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                ),
                AirbnbColors.textSecondary,
              ),
            ),
            
            // 검색창 통합 (핵심 CTA)
            if (widget.showSearchBar && widget.searchController != null) ...[
              const SizedBox(height: AppSpacing.xxxl), // 64px - 넓은 여백
              _buildSearchBar(context, isMobile),
            ],
          ],
        ),
      ),
    );
  }

  /// Stripe/Vercel 스타일의 프리미엄 검색창
  Widget _buildSearchBar(BuildContext context, bool isMobile) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 680), // 검색창 최대 너비
      width: double.infinity,
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AirbnbColors.border,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.primary.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: widget.searchController,
          onChanged: widget.onSearchChanged,
          onSubmitted: (_) => widget.onSearchSubmitted?.call(),
          autofocus: false,
          style: AppTypography.withColor(
            AppTypography.h4,
            AirbnbColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '예) 서울특별시 강북구 덕릉로 138',
            hintStyle: AppTypography.withColor(
              AppTypography.h4,
              AirbnbColors.textSecondary, // textLight → textSecondary (WCAG AA 대비 비율 개선)
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AirbnbColors.primary,
              size: 24,
            ),
            suffixIcon: _hasSearchText
                ? AccessibleWidget.iconButton(
                    icon: Icons.close_rounded,
                    tooltip: '검색어 지우기',
                    semanticLabel: '검색어 지우기',
                    color: AirbnbColors.textSecondary,
                    iconSize: 20,
                    onPressed: () {
                      widget.searchController?.clear();
                      widget.onSearchChanged?.call('');
                      setState(() {
                        _hasSearchText = false;
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: isMobile ? AppSpacing.md : AppSpacing.lg, // 16px / 24px
            ),
          ),
        ),
      ),
    );
  }

}
