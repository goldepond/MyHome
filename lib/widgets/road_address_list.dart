import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';

/// 도로명 주소 검색 결과 리스트 위젯
class RoadAddressList extends StatelessWidget {
  final List<Map<String, String>> fullAddrAPIDatas;
  final List<String> addresses;
  final String selectedAddress;
  final void Function(Map<String, String>, String) onSelect;

  const RoadAddressList({
    required this.fullAddrAPIDatas,
    required this.addresses,
    required this.selectedAddress,
    required this.onSelect,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final horizontalMargin = isMobile ? 16.0 : 40.0;
    final itemPadding = isMobile ? 14.0 : 12.0;
    final fontSize = isMobile ? 17.0 : 15.0;

    List<Widget> listItems = [];
    for (int i = 0; i < addresses.length; i++) {
      final addr = addresses[i];
      final fullData = fullAddrAPIDatas[i];
      final isSelected = selectedAddress.trim() == addr.trim();

      listItems.add(
        _AddressListItem(
          address: addr,
          fullData: fullData,
          isSelected: isSelected,
          itemPadding: itemPadding,
          fontSize: fontSize,
          onSelect: onSelect,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: listItems,
      ),
    );
  }
}

/// 개별 주소 항목 위젯 (호버/클릭 상태 관리)
class _AddressListItem extends StatefulWidget {
  final String address;
  final Map<String, String> fullData;
  final bool isSelected;
  final double itemPadding;
  final double fontSize;
  final void Function(Map<String, String>, String) onSelect;

  const _AddressListItem({
    required this.address,
    required this.fullData,
    required this.isSelected,
    required this.itemPadding,
    required this.fontSize,
    required this.onSelect,
  });

  @override
  State<_AddressListItem> createState() => _AddressListItemState();
}

class _AddressListItemState extends State<_AddressListItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isLargeText = widget.fontSize >= 18.0;

    // 배경색 결정 (우선순위: 클릭 > 호버 > 선택 > 기본)
    Color backgroundColor;
    if (_isPressed) {
      backgroundColor = AirbnbColors.blue.withValues(alpha: 0.2);
    } else if (_isHovered) {
      backgroundColor = AirbnbColors.blue.withValues(alpha: 0.08);
    } else if (widget.isSelected && isLargeText) {
      backgroundColor = AirbnbColors.blueDark;
    } else if (widget.isSelected) {
      backgroundColor = AirbnbColors.blue.withValues(alpha: 0.15);
    } else {
      backgroundColor = AirbnbColors.background;
    }

    // 테두리 색상
    Color borderColor;
    double borderWidth;
    if (_isHovered || _isPressed) {
      borderColor = AirbnbColors.blue;
      borderWidth = 2.0;
    } else if (widget.isSelected) {
      borderColor = AirbnbColors.blueDark;
      borderWidth = isLargeText ? 1.0 : 2.0;
    } else {
      borderColor = Colors.transparent;
      borderWidth = 0;
    }

    // 텍스트 색상 - 가독성 우선
    Color textColor;
    if (widget.isSelected && isLargeText) {
      textColor = AirbnbColors.background;
    } else if (widget.isSelected) {
      // 선택된 항목은 진한 검정색으로 가독성 확보
      textColor = AirbnbColors.textPrimary;
    } else if (_isHovered || _isPressed) {
      textColor = AirbnbColors.blueDark;
    } else {
      textColor = AirbnbColors.textPrimary;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onSelect(widget.fullData, widget.address);
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: EdgeInsets.symmetric(
            vertical: widget.itemPadding,
            horizontal: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: borderWidth > 0
                ? Border.all(color: borderColor, width: borderWidth)
                : null,
            boxShadow: (widget.isSelected || _isHovered || _isPressed)
                ? [
                    BoxShadow(
                      color: AirbnbColors.blueDark.withValues(
                        alpha: _isPressed ? 0.3 : (_isHovered ? 0.15 : 0.2),
                      ),
                      blurRadius: _isPressed ? 16 : 12,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // 선택/호버 아이콘
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: (widget.isSelected || _isHovered || _isPressed) ? 22 : 0,
                child: (widget.isSelected || _isHovered || _isPressed)
                    ? Icon(
                        widget.isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        color: widget.isSelected && isLargeText
                            ? AirbnbColors.background
                            : AirbnbColors.blueDark,
                        size: 22,
                      )
                    : null,
              ),
              if (widget.isSelected || _isHovered || _isPressed)
                const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.address,
                      style: AppTypography.withColor(
                        AppTypography.body.copyWith(
                          fontSize: widget.fontSize,
                          fontWeight: (widget.isSelected || _isHovered || _isPressed)
                              ? FontWeight.w600
                              : FontWeight.normal,
                          height: 1.4,
                        ),
                        textColor,
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
}
