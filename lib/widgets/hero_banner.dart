import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class HeroBanner extends StatefulWidget {
  const HeroBanner({super.key});

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner> {
  // 히어로 배너 단계 (1: 주소 입력, 2: 주소 선택, 3: 공인중개사 찾기)
  int _currentHeroStep = 1;

  String get _heroTitle {
    switch (_currentHeroStep) {
      case 1:
        return '쉽고 빠른\n부동산 상담';
      case 2:
        return '주소를 정확히\n선택해 주세요';
      case 3:
        return '중개사 견적을\n비교해서 선택하세요';
      default:
        return '쉽고 빠른\n부동산 상담';
    }
  }

  String get _heroSubtitle {
    switch (_currentHeroStep) {
      case 1:
        return '도로명·건물명 일부만 입력해도 자동완성이 나옵니다';
      case 2:
        return '추천 리스트에서 내가 원하는 주소를 탭해서 선택하세요';
      case 3:
        return '받은 견적과 후기를 보고 믿을 수 있는 공인중개사를 고르세요';
      default:
        return '주소만 입력하면 근처 공인중개사를 찾아드립니다';
    }
  }

  /// 히어로 배너 그라데이션 색상
  List<Color> get _heroGradientColors {
    switch (_currentHeroStep) {
      case 1:
        return const [Color(0xFF5B21B6), Color(0xFF1E3A8A)];
      case 2:
        return const [Color(0xFF1E3A8A), Color(0xFF065F46)];
      case 3:
        return const [Color(0xFF065F46), Color(0xFF4C1D95)];
      default:
        return const [AppColors.kPrimary, AppColors.kSecondary];
    }
  }

  /// 히어로 배너 아이콘
  IconData get _heroIconData {
    switch (_currentHeroStep) {
      case 1:
        return Icons.edit_location_alt_rounded;
      case 2:
        return Icons.place_rounded;
      case 3:
        return Icons.handshake_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  Widget _buildStepChip(int step, String label, {bool isVerySmallScreen = false}) {
    final bool isSelected = _currentHeroStep == step;

    return InkWell(
      onTap: () {
        setState(() {
          _currentHeroStep = step;
        });
      },
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isVerySmallScreen ? 2 : 4,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isVerySmallScreen ? 18 : 20,
              height: isVerySmallScreen ? 18 : 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.25),
              ),
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 10 : 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.kPrimary
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            SizedBox(width: isVerySmallScreen ? 4 : 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isVerySmallScreen ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 16,
        height: 1,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 400;

    return AnimatedContainer(
      height: 360,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _heroGradientColors,
        ),
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: AppColors.kPrimary.withValues(alpha: 0.25),
            offset: const Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Icon(
              _heroIconData,
              key: ValueKey<int>(_currentHeroStep),
              size: 52,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _heroTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _heroSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 8 : 18,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: _buildStepChip(1, '주소 입력', isVerySmallScreen: isVerySmallScreen),
                ),
                _buildStepDivider(),
                Flexible(
                  child: _buildStepChip(2, '주소 선택', isVerySmallScreen: isVerySmallScreen),
                ),
                _buildStepDivider(),
                Flexible(
                  child: _buildStepChip(3, isVerySmallScreen ? '중개사찾기' : '공인중개사 찾기', isVerySmallScreen: isVerySmallScreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

