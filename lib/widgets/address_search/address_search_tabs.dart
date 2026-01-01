import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'gps_based_search_tab.dart';
import 'address_input_tab.dart';
import 'address_search_result.dart';

/// 주소 검색 탭 컨테이너 위젯
/// 
/// GPS 기반 검색과 주소 입력 검색을 탭으로 분리하여 제공합니다.
/// 각 탭은 독립적으로 관리되며, 선택된 주소 정보를 콜백으로 전달합니다.
class AddressSearchTabs extends StatefulWidget {
  /// 주소 선택 시 콜백
  final ValueChanged<SelectedAddressResult>? onAddressSelected;

  const AddressSearchTabs({
    super.key,
    this.onAddressSelected,
  });

  @override
  State<AddressSearchTabs> createState() => _AddressSearchTabsState();
}

class _AddressSearchTabsState extends State<AddressSearchTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<GpsBasedSearchTabState> _gpsTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }
  
  /// 탭 전환 감지
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // GPS 탭(인덱스 0)으로 전환되면 자동 완료 활성화
      if (_tabController.index == 0) {
        // GPS 탭이 활성화되면 자동 완료를 위해 약간의 지연 후 처리
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _tabController.index == 0) {
            // 자동 완료 상태 리셋 후 다시 활성화
            _gpsTabKey.currentState?.resetAutoComplete();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AirbnbColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 탭 헤더
          Container(
            decoration: const BoxDecoration(
              color: AirbnbColors.background,
              border: Border(
                bottom: BorderSide(
                  color: AirbnbColors.borderLight,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AirbnbColors.primary,
              unselectedLabelColor: AirbnbColors.textSecondary,
              indicatorColor: AirbnbColors.primary,
              indicatorWeight: 3,
              labelStyle: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.my_location, size: 20),
                  text: 'GPS 기반 검색',
                ),
                Tab(
                  icon: Icon(Icons.search, size: 20),
                  text: '주소 입력 검색',
                ),
              ],
            ),
          ),

          // 탭 콘텐츠
          SizedBox(
            height: 1000, // GPS 검색 탭의 모든 콘텐츠가 스크롤 없이 표시되도록 충분한 높이 제공
            child: TabBarView(
              controller: _tabController,
              children: [
                // GPS 기반 검색 탭
                GpsBasedSearchTab(
                  key: _gpsTabKey,
                  onAddressSelected: (result) {
                    widget.onAddressSelected?.call(
                      SelectedAddressResult(
                        address: result.address,
                        latitude: result.latitude,
                        longitude: result.longitude,
                      ),
                    );
                  },
                ),

                // 주소 입력 검색 탭
                AddressInputTab(
                  onAddressSelected: (result) {
                    widget.onAddressSelected?.call(result);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

