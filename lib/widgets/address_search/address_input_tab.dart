import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/typography.dart';
import 'package:property/api_request/address_service.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/widgets/road_address_list.dart';
import 'package:property/widgets/region_selection_map.dart';
import 'package:property/widgets/region_selection/distance_slider_widget.dart';
import 'address_search_result.dart';

// 웹 전용 import (조건부)
import 'package:property/widgets/region_selection_map_stub.dart'
    if (dart.library.html) 'package:property/widgets/region_selection_map_web.dart' as web_map;

/// 주소 입력 검색 탭 위젯
/// 
/// 사용자가 주소를 직접 입력하여 검색하는 탭입니다.
/// 기존 주소 검색 로직을 캡슐화하여 구현되었습니다.
class AddressInputTab extends StatefulWidget {
  /// 주소 선택 시 콜백
  final ValueChanged<SelectedAddressResult>? onAddressSelected;
  
  /// 콘텐츠 변경 시 콜백 (높이 재측정용)
  final VoidCallback? onContentChanged;

  const AddressInputTab({
    super.key,
    this.onAddressSelected,
    this.onContentChanged,
  });

  @override
  State<AddressInputTab> createState() => _AddressInputTabState();
}

class _AddressInputTabState extends State<AddressInputTab> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String? _lastSearchKeyword;

  // 검색 상태
  bool _isSearching = false;
  List<Map<String, String>> _searchResults = [];
  List<String> _addresses = [];
  String? _errorMessage;
  String? _selectedAddress;

  // 선택된 좌표 (지도 이동용)
  double? _selectedLatitude;
  double? _selectedLongitude;

  // 범위 정보 (GPS 탭과 동일)
  static const double _fixedRadiusMeters = 500.0; // 실제 원의 반경 (고정)
  double _displayRadiusMeters = 1000.0; // 표시할 반경 (슬라이더 값, 기본값 1km)

  // 페이지네이션
  int _currentPage = 1;
  int _totalCount = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// 주소 검색 수행
  Future<void> _performSearch(String keyword, {int page = 1}) async {
    if (keyword.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _addresses = [];
        _errorMessage = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      if (page == 1) {
        _currentPage = 1;
        _searchResults = [];
        _addresses = [];
      }
    });
    
    // 검색 시작 시 콘텐츠 변경 알림 (로딩 상태 변경)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onContentChanged?.call();
    });

    try {
      final result = await AddressService().searchRoadAddress(keyword, page: page);

      setState(() {
        _isSearching = false;
        _searchResults = result.fullData;
        _addresses = result.addresses;
        _totalCount = result.totalCount;
        _currentPage = page;
        _errorMessage = result.errorMessage;
      });
      
      // 콘텐츠 변경 알림 (높이 재측정용)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onContentChanged?.call();
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = '주소 검색 중 오류가 발생했습니다: ${e.toString()}';
      });
      
      // 콘텐츠 변경 알림 (높이 재측정용)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onContentChanged?.call();
      });
    }
  }

  /// 디바운싱 적용된 검색
  void _searchWithDebounce(String keyword, {int page = 1, bool skipDebounce = false}) {
    if (!skipDebounce && page == 1) {
      // 중복 요청 방지
      if (_lastSearchKeyword == keyword.trim() && _isSearching) {
        return;
      }

      // 이전 타이머 취소
      _debounceTimer?.cancel();

      // 디바운싱 적용 (500ms)
      _lastSearchKeyword = keyword.trim();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _performSearch(keyword, page: page);
      });
      return;
    }

    // 페이지네이션이나 즉시 검색이 필요한 경우 바로 실행
    _performSearch(keyword, page: page);
  }

  /// 지도를 특정 좌표로 이동
  void _moveMapToLocation(double latitude, double longitude) {
    if (!kIsWeb) return;
    
    // 지도가 준비될 때까지 재시도 (최대 5초)
    int retryCount = 0;
    const maxRetries = 10;
    const retryDelay = Duration(milliseconds: 500);
    
    void tryMoveMap() {
      try {
        final iframe = web_map.findMapIframe();
        if (iframe != null) {
          web_map.postMessageToIframe(iframe, {
            'type': 'GO_TO_MY_LOCATION',
            'latitude': latitude,
            'longitude': longitude,
            'displayRadiusMeters': _displayRadiusMeters,
            'fixedRadiusMeters': _fixedRadiusMeters,
          });
        } else if (retryCount < maxRetries) {
          retryCount++;
          Future.delayed(retryDelay, tryMoveMap);
        }
      } catch (e) {
        if (retryCount < maxRetries) {
          retryCount++;
          Future.delayed(retryDelay, tryMoveMap);
        }
      }
    }
    
    tryMoveMap();
  }

  /// 거리 변경 처리 (슬라이더)
  /// GPS 탭과 동일한 로직
  void _onDistanceChanged(double distance) {
    setState(() {
      _displayRadiusMeters = distance;
    });
    
    // 지도에 줌 조정 메시지 전송 (웹 전용, 선택된 좌표가 있을 때만)
    if (kIsWeb && _selectedLatitude != null && _selectedLongitude != null) {
      int retryCount = 0;
      const maxRetries = 5;
      const retryDelay = Duration(milliseconds: 200);
      
      void tryAdjustZoom() {
        try {
          final iframe = web_map.findMapIframe();
          if (iframe != null) {
            web_map.postMessageToIframe(iframe, {
              'type': 'ADJUST_ZOOM',
              'displayRadiusMeters': distance,
              'fixedRadiusMeters': _fixedRadiusMeters,
              'latitude': _selectedLatitude,
              'longitude': _selectedLongitude,
            });
          } else if (retryCount < maxRetries) {
            retryCount++;
            Future.delayed(retryDelay, tryAdjustZoom);
          }
        } catch (e) {
          if (retryCount < maxRetries) {
            retryCount++;
            Future.delayed(retryDelay, tryAdjustZoom);
          }
        }
      }
      
      tryAdjustZoom();
    }
  }

  /// 주소 선택 처리
  Future<void> _selectAddress(Map<String, String> fullData, String displayAddr) async {
    final roadAddr = (fullData['roadAddr'] ?? '').trim();
    final jibunAddr = (fullData['jibunAddr'] ?? '').trim();
    final cleanAddress = roadAddr.isNotEmpty ? roadAddr : jibunAddr;

    setState(() {
      _selectedAddress = displayAddr;
    });

    // 좌표 조회
    try {
      final coordinates = await VWorldService.getCoordinatesFromAddress(
        cleanAddress,
        fullAddrData: fullData,
      );

      if (coordinates != null && mounted) {
        // getCoordinatesFromAddress는 {'x': ..., 'y': ...} 형식으로 반환
        // x, y는 문자열 또는 숫자일 수 있음
        double? lat;
        double? lon;
        
        if (coordinates['y'] != null) {
          if (coordinates['y'] is double) {
            lat = coordinates['y'] as double;
          } else if (coordinates['y'] is num) {
            lat = (coordinates['y'] as num).toDouble();
          } else {
            lat = double.tryParse(coordinates['y'].toString());
          }
        }
        
        if (coordinates['x'] != null) {
          if (coordinates['x'] is double) {
            lon = coordinates['x'] as double;
          } else if (coordinates['x'] is num) {
            lon = (coordinates['x'] as num).toDouble();
          } else {
            lon = double.tryParse(coordinates['x'].toString());
          }
        }

        // 선택된 좌표 저장 및 지도 이동
        if (lat != null && lon != null) {
          setState(() {
            _selectedLatitude = lat;
            _selectedLongitude = lon;
          });
          
          // 지도 이동 (웹 전용)
          if (kIsWeb) {
            _moveMapToLocation(lat, lon);
          }
        }

        widget.onAddressSelected?.call(
          SelectedAddressResult(
            address: cleanAddress,
            latitude: lat,
            longitude: lon,
            fullAddrAPIData: fullData,
            radiusMeters: _displayRadiusMeters,
          ),
        );
      } else {
        // 좌표 조회 실패해도 주소는 전달
        widget.onAddressSelected?.call(
          SelectedAddressResult(
            address: cleanAddress,
            fullAddrAPIData: fullData,
            radiusMeters: _displayRadiusMeters,
          ),
        );
      }
    } catch (e) {
      // 좌표 조회 실패해도 주소는 전달
      widget.onAddressSelected?.call(
        SelectedAddressResult(
          address: cleanAddress,
          fullAddrAPIData: fullData,
          radiusMeters: _displayRadiusMeters,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 지도 (선택된 주소가 있으면 해당 위치로 이동)
          SizedBox(
            height: 300,
            child: RegionSelectionMap(
              height: 300,
              displayRadiusMeters: _displayRadiusMeters,
              latitude: _selectedLatitude,
              longitude: _selectedLongitude,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 거리 슬라이더 (GPS 탭과 동일)
          DistanceSliderWidget(
            distanceMeters: _displayRadiusMeters,
            onDistanceChanged: _onDistanceChanged,
          ),

          const SizedBox(height: AppSpacing.lg),

          // 검색창 (슬라이더 아래로 이동, 크기 확대)
          Container(
            decoration: BoxDecoration(
              color: AirbnbColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AirbnbColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AirbnbColors.primary.withValues(alpha: 0.08),
                  offset: const Offset(0, 4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '도로명, 건물명, 지번 등을 입력하세요',
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: AirbnbColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 24,
                  color: AirbnbColors.textSecondary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          size: 24,
                          color: AirbnbColors.textSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _addresses = [];
                            _selectedAddress = null;
                            _selectedLatitude = null;
                            _selectedLongitude = null;
                            _displayRadiusMeters = 1000.0; // 기본값으로 리셋
                          });
                          
                          // 콘텐츠 변경 알림 (높이 재측정용)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.onContentChanged?.call();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
              ),
              style: AppTypography.bodyLarge,
              onChanged: (value) {
                setState(() {});
                if (value.trim().isNotEmpty) {
                  _searchWithDebounce(value.trim());
                } else {
                  setState(() {
                    _searchResults = [];
                    _addresses = [];
                    _selectedAddress = null;
                    _selectedLatitude = null;
                    _selectedLongitude = null;
                    _displayRadiusMeters = 1000.0; // 기본값으로 리셋
                  });
                  
                  // 콘텐츠 변경 알림 (높이 재측정용)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onContentChanged?.call();
                  });
                }
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _searchWithDebounce(value.trim(), skipDebounce: true);
                }
              },
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // 로딩 인디케이터
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.primary),
                ),
              ),
            ),

          // 에러 메시지
          if (_errorMessage != null && !_isSearching)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AirbnbColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AirbnbColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _errorMessage!,
                style: AppTypography.bodySmall.copyWith(
                  color: AirbnbColors.error,
                ),
              ),
            ),

          // 검색 결과 목록
          if (_addresses.isNotEmpty && !_isSearching) ...[
            RoadAddressList(
              fullAddrAPIDatas: _searchResults,
              addresses: _addresses,
              selectedAddress: _selectedAddress ?? '',
              onSelect: _selectAddress,
            ),

            // 페이지네이션
            if (_totalCount > ApiConstants.pageSize) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentPage > 1)
                    TextButton(
                      onPressed: () {
                        _searchWithDebounce(
                          _searchController.text.trim(),
                          page: _currentPage - 1,
                          skipDebounce: true,
                        );
                      },
                      child: const Text('이전'),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(
                      '페이지 $_currentPage / ${((_totalCount - 1) ~/ ApiConstants.pageSize) + 1}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AirbnbColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_currentPage * ApiConstants.pageSize < _totalCount)
                    TextButton(
                      onPressed: () {
                        _searchWithDebounce(
                          _searchController.text.trim(),
                          page: _currentPage + 1,
                          skipDebounce: true,
                        );
                      },
                      child: const Text('다음'),
                    ),
                ],
              ),
            ],
          ],

          // 검색 결과 없음
          if (_addresses.isEmpty &&
              !_isSearching &&
              _errorMessage == null &&
              _searchController.text.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.search_off,
                      size: 48,
                      color: AirbnbColors.textSecondary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '검색 결과가 없습니다',
                      style: AppTypography.body.copyWith(
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

