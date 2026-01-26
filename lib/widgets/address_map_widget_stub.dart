// Stub 파일 - 모바일 빌드용
// 웹 빌드에서는 address_map_widget.dart가 사용됩니다.

import 'package:flutter/material.dart';

/// AddressMapWidget 스텁 - 모바일에서는 사용되지 않음
/// 실제 모바일 구현은 AddressMapWidgetMobile 사용
class AddressMapWidget extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final double height;

  const AddressMapWidget({
    super.key,
    this.latitude,
    this.longitude,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    // 모바일에서는 이 위젯이 사용되지 않음 (kIsWeb 분기로 인해)
    // 만약 호출되면 빈 컨테이너 반환
    return SizedBox(
      height: height,
      child: const Center(
        child: Text('지도는 웹에서만 지원됩니다'),
      ),
    );
  }
}
