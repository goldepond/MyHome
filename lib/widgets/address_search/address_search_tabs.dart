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
  final GlobalKey _gpsTabContentKey = GlobalKey();
  final GlobalKey _addressTabContentKey = GlobalKey();
  double? _tabHeight;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }
  
  /// 탭 콘텐츠 높이 측정
  void _measureTabHeight() {
    // 여러 번 시도하여 정확한 높이 측정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performHeightMeasurement();
    });
    
    // 추가로 지연 후 재측정 (렌더링 완료 대기)
    // 동적 콘텐츠(주소 로딩, 에러 메시지 등) 변경을 고려하여 더 긴 지연 시간 사용
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performHeightMeasurement();
      }
    });
    
    // 최종 재측정 (모든 비동기 작업 완료 후)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _performHeightMeasurement();
      }
    });
  }
  
  /// 실제 높이 측정 수행
  void _performHeightMeasurement() {
    if (!mounted) return;
    
    double? gpsHeight;
    double? addressHeight;
    
    // GPS 탭 높이 측정 - IntrinsicHeight를 사용하여 실제 콘텐츠 높이 측정
    final gpsContext = _gpsTabContentKey.currentContext;
    if (gpsContext != null) {
      final renderBox = gpsContext.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        // 실제 콘텐츠 높이 측정 (IntrinsicHeight가 설정한 높이)
        // IntrinsicHeight는 자식의 내재 높이를 측정하므로, 제약 없이 측정된 높이를 사용
        gpsHeight = renderBox.size.height;
        
        // 무한 높이로 인식된 경우 처리 (IntrinsicHeight가 제대로 측정하지 못한 경우)
        if (gpsHeight > 10000) {
          gpsHeight = null;
        }
      }
    }
    
    // 주소 입력 탭 높이 측정
    final addressContext = _addressTabContentKey.currentContext;
    if (addressContext != null) {
      final renderBox = addressContext.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        addressHeight = renderBox.size.height;
        
        // 무한 높이로 인식된 경우 처리
        if (addressHeight > 10000) {
          addressHeight = null;
        }
      }
    }
    
    // 두 탭 중 더 높은 높이 사용 + 여유 공간 추가 (overflow 방지)
    if (gpsHeight != null || addressHeight != null) {
      // GPS 탭과 주소 입력 탭을 각각 측정하여 더 큰 값 사용
      double maxHeight = 0;
      bool isGpsTab = false;
      
      if (gpsHeight != null && addressHeight != null) {
        if (gpsHeight > addressHeight) {
          maxHeight = gpsHeight;
          isGpsTab = true;
        } else {
          maxHeight = addressHeight;
        }
      } else if (gpsHeight != null) {
        maxHeight = gpsHeight;
        isGpsTab = true;
      } else if (addressHeight != null) {
        maxHeight = addressHeight;
      }
      
      // GPS 탭은 더 많은 여유 공간 필요 (80px - 측정 오차 및 동적 콘텐츠 대응)
      // 주소 입력 탭은 40px 여유 공간
      // overflow 에러를 방지하기 위한 최소한의 여유 공간 추가
      // 스크롤 없이 높이가 자동 확장되므로 최소한의 여유 공간 설정
      // IntrinsicHeight가 TabBarView의 높이 제약 안에서 측정되므로 여유 공간 설정
      final padding = isGpsTab ? 80.0 : 40.0;
      final heightWithPadding = maxHeight + padding;
      
      if (maxHeight > 0 && (_tabHeight == null || (_tabHeight! - heightWithPadding).abs() > 1.0)) {
        setState(() {
          _tabHeight = heightWithPadding;
        });
      }
    }
  }
  
  /// 탭 전환 감지
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      // 탭 전환 시 높이 재측정
      _measureTabHeight();
      
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

          // 탭 콘텐츠 (가변 높이 - 콘텐츠에 맞게 자동 조정)
          LayoutBuilder(
            builder: (context, constraints) {
              // 초기 높이 측정
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _measureTabHeight();
              });
              
              // 측정된 높이가 있으면 사용, 없으면 기본값 사용
              // 기본값: GPS 탭 예상 높이 (지도 300 + 헤더 + 버튼 + 주소 + 슬라이더 + 완료 버튼 + 패딩 ≈ 900px)
              final screenHeight = MediaQuery.of(context).size.height;
              final defaultHeight = (screenHeight * 0.7).clamp(800.0, 1200.0);
              
              // 측정된 높이가 있으면 사용, 없으면 기본값 사용
              // IntrinsicHeight가 제약 없이 측정할 수 있도록 충분히 큰 높이를 먼저 설정
              // 측정이 완료되기 전까지는 충분히 큰 높이를 사용하여 IntrinsicHeight가 정확히 측정할 수 있도록 함
              final height = _tabHeight ?? defaultHeight;
              
              // maxHeight 제한을 완전히 제거하여 가변 높이를 허용
              // 측정된 높이를 그대로 사용하여 콘텐츠에 맞게 자동 확장
              // 최소 높이만 보장 (너무 작은 값 방지)
              const minHeight = 500.0;
              
              // 측정된 높이를 그대로 사용 (가변 높이 허용, 스크롤 없이 자동 확장)
              // 최소값만 보장하여 너무 작은 값 방지
              final finalHeight = height < minHeight ? minHeight : height;
              
              return SizedBox(
                height: finalHeight,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // GPS 기반 검색 탭 - 실제 콘텐츠 높이에 맞게 조정
                    // IntrinsicHeight가 제약 없이 측정할 수 있도록 Align으로 감싸고
                    // TabBarView의 높이를 충분히 크게 설정
                    // 스크롤 없이 높이가 자동 확장되도록 함
                    Align(
                      alignment: Alignment.topCenter,
                      child: IntrinsicHeight(
                        key: _gpsTabContentKey,
                        child: GpsBasedSearchTab(
                          key: _gpsTabKey,
                          onContentChanged: () {
                            // 콘텐츠 변경 시 높이 재측정
                            Future.delayed(const Duration(milliseconds: 300), () {
                              _measureTabHeight();
                            });
                          },
                          onAddressSelected: (result) {
                            widget.onAddressSelected?.call(
                              SelectedAddressResult(
                                address: result.address,
                                latitude: result.latitude,
                                longitude: result.longitude,
                              ),
                            );
                            // 주소 선택 후 높이 재측정
                            Future.delayed(const Duration(milliseconds: 300), () {
                              _measureTabHeight();
                            });
                          },
                        ),
                      ),
                    ),

                    // 주소 입력 검색 탭 - 실제 콘텐츠 높이에 맞게 조정
                    // 스크롤 없이 높이가 자동 확장되도록 함
                    Align(
                      alignment: Alignment.topCenter,
                      child: IntrinsicHeight(
                        key: _addressTabContentKey,
                        child: AddressInputTab(
                          onContentChanged: () {
                            // 콘텐츠 변경 시 높이 재측정
                            Future.delayed(const Duration(milliseconds: 300), () {
                              _measureTabHeight();
                            });
                          },
                          onAddressSelected: (result) {
                            widget.onAddressSelected?.call(result);
                            // 주소 선택 후 높이 재측정
                            Future.delayed(const Duration(milliseconds: 300), () {
                              _measureTabHeight();
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

