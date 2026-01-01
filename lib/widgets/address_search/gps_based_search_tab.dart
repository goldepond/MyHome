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

  const GpsBasedSearchTab({
    super.key,
    this.onAddressSelected,
  });

  @override
  State<GpsBasedSearchTab> createState() => GpsBasedSearchTabState();
}

class GpsBasedSearchTabState extends State<GpsBasedSearchTab> {
  bool _autoCompleteEnabled = false;
  bool _hasAutoCompleted = false; // 이미 자동 완료했는지 추적

  @override
  void initState() {
    super.initState();
    // GPS 탭이 처음 생성될 때 자동 완료 활성화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _autoCompleteEnabled = true;
        });
      }
    });
  }

  /// 자동 완료 활성화 (외부에서 호출, 탭 전환 시)
  void enableAutoComplete() {
    if (mounted && !_hasAutoCompleted) {
      setState(() {
        _autoCompleteEnabled = true;
      });
    }
  }
  
  /// 자동 완료 상태 리셋 (다시 자동 완료할 수 있도록)
  void resetAutoComplete() {
    if (mounted) {
      setState(() {
        _hasAutoCompleted = false;
        _autoCompleteEnabled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegionSelectionSection(
      autoComplete: _autoCompleteEnabled,
      onComplete: (result) {
        // 자동 완료 처리 후 플래그 설정
        if (_autoCompleteEnabled) {
          setState(() {
            _hasAutoCompleted = true;
            _autoCompleteEnabled = false; // 한 번만 자동 완료
          });
        }
        
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

