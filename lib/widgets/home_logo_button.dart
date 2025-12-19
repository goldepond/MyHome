import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 홈으로 이동하는 MyHome 로고 버튼
class HomeLogoButton extends StatelessWidget {
  final Color? color;
  final double? fontSize;
  final double? logoHeight;
  
  const HomeLogoButton({
    this.color,
    this.fontSize = 24,
    this.logoHeight,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 홈으로 이동 (기존 스택 유지, 루트로 복귀)
        Navigator.popUntil(context, (route) => route.isFirst);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: _buildLogo(logoHeight ?? fontSize! * 2.5),
      ),
    );
  }

  Widget _buildLogo(double height) {
    // 로고 이미지 파일 존재 여부 확인 후 표시
    // assets/logo.jpg 우선 사용 (사용자가 제공한 로고)
    return Image.asset(
      'assets/logo.jpg',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // logo.jpg가 없으면 myhome_logo.png 시도
        return Image.asset(
          'assets/myhome_logo.png',
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // myhome_logo.png가 없으면 logo.png 시도
            return Image.asset(
              'assets/logo.png',
              height: height,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // 로고 파일이 없으면 기본 아이콘 사용
                return Icon(
                  Icons.home,
                  color: color ?? AirbnbColors.background,
                  size: height,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 로고만 표시하는 위젯 (텍스트 없이)
class LogoImage extends StatelessWidget {
  final double? height;
  final double? width;
  final Color? color;
  
  const LogoImage({
    this.height,
    this.width,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.jpg',
      height: height,
      width: width,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // logo.jpg가 없으면 myhome_logo.png 시도
        return Image.asset(
          'assets/myhome_logo.png',
          height: height,
          width: width,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            // myhome_logo.png가 없으면 logo.png 시도
            return Image.asset(
              'assets/logo.png',
              height: height,
              width: width,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // 로고 파일이 없으면 기본 아이콘 사용
                return Icon(
                  Icons.home,
                  color: color ?? AirbnbColors.primary,
                  size: height ?? 24,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 로고와 텍스트를 함께 표시하는 위젯 (로고 이미지에 텍스트가 포함되어 있으면 텍스트 없이 표시)
class LogoWithText extends StatelessWidget {
  final double? fontSize;
  final double? logoHeight;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool showText; // 텍스트 표시 여부 (기본값: false, 로고 이미지에 텍스트 포함)
  
  const LogoWithText({
    this.fontSize = 24,
    this.logoHeight,
    this.textColor,
    this.onTap,
    this.showText = false, // 로고 이미지에 텍스트가 포함되어 있으므로 기본값 false
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final logoWidget = LogoImage(
      height: logoHeight ?? fontSize! * 2.5,
      color: textColor,
    );

    final widget = showText
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              logoWidget,
              const SizedBox(width: 8),
              Text(
                'MyHome',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? AirbnbColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          )
        : logoWidget;

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: widget,
        ),
      );
    }

    return widget;
  }
}

/// AppBar용 타이틀 (홈 이동 가능)
class AppBarTitle extends StatelessWidget {
  final String title;
  final bool showHomeLogo;
  
  const AppBarTitle({
    required this.title,
    this.showHomeLogo = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (showHomeLogo) {
      return Row(
        children: [
          const HomeLogoButton(fontSize: 20),
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 20,
            color: AirbnbColors.background.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: AirbnbColors.background,
            ),
          ),
        ],
      );
    }
    
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        color: AirbnbColors.background,
      ),
    );
  }
}

