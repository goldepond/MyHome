import 'package:flutter/material.dart';
import 'package:property/widgets/region_selection/region_selection_section.dart';
import 'address_search_result.dart';

/// GPS 기반 검색 탭 위젯
/// 
/// GPS 위치를 기반으로 지도에서 지역을 선택하는 탭입니다.
/// RegionSelectionSection을 활용하여 구현되었습니다.
class GpsBasedSearchTab extends StatefulWidget {
  /// 주소 선택 시 콜백
  final ValueChanged<SelectedAddressResult>? onAddressSelected;
  
  /// 콘텐츠 변경 시 콜백 (높이 재측정용)
  final VoidCallback? onContentChanged;

  const GpsBasedSearchTab({
    super.key,
    this.onAddressSelected,
    this.onContentChanged,
  });

  @override
  State<GpsBasedSearchTab> createState() => GpsBasedSearchTabState();
}

class GpsBasedSearchTabState extends State<GpsBasedSearchTab> {
  @override
  void initState() {
    super.initState();
  }

  /// 자동 완료 활성화 (외부에서 호출, 탭 전환 시)
  /// 항상 활성화되어 있으므로 빈 구현
  void enableAutoComplete() {
    // 항상 활성화되어 있으므로 아무 작업도 하지 않음
  }
  
  /// 자동 완료 상태 리셋 (다시 자동 완료할 수 있도록)
  /// 항상 활성화되어 있으므로 빈 구현
  void resetAutoComplete() {
    // 항상 활성화되어 있으므로 아무 작업도 하지 않음
  }

  @override
  Widget build(BuildContext context) {
    return RegionSelectionSection(
      autoComplete: true, // 항상 자동 완료 활성화
      onContentChanged: widget.onContentChanged, // 콘텐츠 변경 알림 전달
      onComplete: (result) {
        // 자동 완료 제한 제거 - 주소가 변경될 때마다 호출됨
        widget.onAddressSelected?.call(
          SelectedAddressResult(
            address: result.address,
            latitude: result.latitude,
            longitude: result.longitude,
            radiusMeters: result.radiusMeters,
          ),
        );
      },
    );
  }
}

