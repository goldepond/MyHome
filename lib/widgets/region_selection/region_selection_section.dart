import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// 웹 전용 import (조건부)
import 'region_selection_section_stub.dart'
    if (dart.library.html) 'region_selection_section_web.dart' as web;
import 'package:geolocator/geolocator.dart';
import 'package:property/constants/spacing.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/constants/typography.dart';
import 'package:property/widgets/region_selection/address_display_widget.dart';
import 'package:property/widgets/region_selection/distance_slider_widget.dart';
import 'package:property/widgets/region_selection/complete_button_widget.dart';
import 'package:property/widgets/region_selection_map.dart';
import 'package:property/api_request/vworld_service.dart';
import 'package:property/utils/logger.dart';

/// 선택된 지역 정보
class RegionSelectionResult {
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const RegionSelectionResult({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });
}

/// 지역 선택 섹션 통합 위젯
/// 
/// 지도, 주소 표시, 거리 슬라이더, 완료 버튼을 통합한 위젯입니다.
/// 유지보수를 쉽게 하기 위해 각 컴포넌트를 분리하여 구현했습니다.
class RegionSelectionSection extends StatefulWidget {
  /// 완료 버튼 클릭 시 콜백
  final ValueChanged<RegionSelectionResult>? onComplete;
  
  /// 자동 완료 활성화 여부 (주소가 준비되면 자동으로 완료 처리)
  final bool autoComplete;
  
  /// 콘텐츠 변경 시 콜백 (높이 재측정용)
  final VoidCallback? onContentChanged;

  const RegionSelectionSection({
    super.key,
    this.onComplete,
    this.autoComplete = false,
    this.onContentChanged,
  });

  @override
  State<RegionSelectionSection> createState() => _RegionSelectionSectionState();
}

class _RegionSelectionSectionState extends State<RegionSelectionSection> {
  // 현재 선택된 좌표
  double? _currentLatitude;
  double? _longitude;
  
  // 현재 주소
  String? _currentAddress;
  bool _isLoadingAddress = false;
  String? _addressError;
  
  // 실제 원의 반경 (고정값, 미터 단위)
  // ⚠️ 중요: 슬라이더를 조정해도 원의 크기는 항상 동일합니다 (500m 고정)
  // 슬라이더는 지도 줌 레벨만 조정하여, 줌아웃되면 같은 크기의 원이 상대적으로 더 많은 거리를 포함하게 보입니다.
  static const double _fixedRadiusMeters = 500.0;
  
  // 표시할 반경 (슬라이더 값, 미터 단위) - 지도 줌 조정에만 사용
  // 이 값은 원의 크기를 변경하지 않고, 지도가 얼마나 확대/축소될지만 결정합니다.
  double _displayRadiusMeters = 1000.0;  // 기본값을 1km로 변경
  
  // Debounce를 위한 Timer
  Timer? _debounceTimer;
  
  // 메시지 리스너 (웹 전용)
  dynamic _messageSubscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // 웹 전용: window 메시지 리스너 등록
      _initWebMessageListener();
    }
  }

  /// 웹 전용: 메시지 리스너 초기화
  void _initWebMessageListener() {
    if (!kIsWeb) return;
    _messageSubscription = web.initWebMessageListener((data) {
      if (data['type'] == 'MAP_LOCATION_CHANGED') {
        final lat = data['latitude'];
        final lon = data['longitude'];
        if (lat != null && lon != null) {
          final latValue = lat is num ? lat.toDouble() : double.tryParse(lat.toString());
          final lonValue = lon is num ? lon.toDouble() : double.tryParse(lon.toString());
          if (latValue != null && lonValue != null) {
            _updateLocation(latValue, lonValue);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  /// 좌표 업데이트 및 주소 조회
  /// 
  /// 지도에서 위치가 변경될 때 호출됩니다.
  /// Debounce를 적용하여 불필요한 API 호출을 방지합니다.
  void _updateLocation(double latitude, double longitude) {
    setState(() {
      _currentLatitude = latitude;
      _longitude = longitude;
      _currentAddress = null;
      _isLoadingAddress = true;
      _addressError = null;
    });
    
    // 콘텐츠 변경 알림 (높이 재측정용) - 로딩 상태 변경
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onContentChanged?.call();
    });

    // Debounce: 500ms 후에 주소 조회
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchAddress(latitude, longitude);
    });
  }

  /// 주소 조회 (Reverse Geocoding)
  Future<void> _fetchAddress(double latitude, double longitude) async {
    if (!mounted) return;

    try {
      final address = await VWorldService.reverseGeocode(latitude, longitude);
      
      if (!mounted) return;

      setState(() {
        _isLoadingAddress = false;
        if (address != null && address.isNotEmpty) {
          _currentAddress = address;
          _addressError = null;
          
          // 자동 완료 옵션이 활성화되어 있고 좌표가 있으면 자동으로 완료 처리
          if (widget.autoComplete && 
              _currentLatitude != null && 
              _longitude != null) {
            // 약간의 지연을 두어 UI가 업데이트된 후 완료 처리
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _currentAddress != null && 
                  _currentLatitude != null && _longitude != null) {
                _onComplete();
              }
            });
          }
        } else {
          _currentAddress = null;
          _addressError = '주소를 찾을 수 없습니다';
        }
      });
      
      // 콘텐츠 변경 알림 (높이 재측정용)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onContentChanged?.call();
      });
    } catch (e) {
      if (!mounted) return;

      Logger.warning(
        '주소 조회 실패',
        metadata: {
          'latitude': latitude,
          'longitude': longitude,
          'error': e.toString(),
        },
      );

      setState(() {
        _isLoadingAddress = false;
        _currentAddress = null;
        _addressError = '주소 조회 중 오류가 발생했습니다';
      });
      
      // 콘텐츠 변경 알림 (높이 재측정용)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onContentChanged?.call();
      });
    }
  }

  /// 거리 변경 처리
  /// 
  /// ⚠️ 중요: 슬라이더 값은 표시할 반경을 의미하지만, 실제 원의 크기는 변경되지 않습니다.
  /// - 실제 원의 크기: 항상 500m로 고정 (_fixedRadiusMeters)
  /// - 슬라이더 값: 지도 줌 레벨만 조정 (_displayRadiusMeters)
  /// - 동작 원리: 슬라이더를 조정하면 지도만 줌아웃/줌인되어, 같은 크기의 원이 상대적으로 더 많은/적은 거리를 포함하게 보입니다.
  /// 
  /// 예시:
  /// - 슬라이더 300m: 지도가 확대되어 원이 화면에서 크게 보임
  /// - 슬라이더 1.5km: 지도가 축소되어 원이 화면에서 작게 보이지만, 실제로는 같은 500m 크기
  void _onDistanceChanged(double distance) {
    setState(() {
      _displayRadiusMeters = distance;
    });
    
    // 콘텐츠 변경 알림 (높이 재측정용) - 슬라이더 변경
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onContentChanged?.call();
    });
    
    // 거리 변경 시에도 자동 완료 (주소가 있는 경우)
    if (widget.autoComplete && 
        _currentAddress != null && 
        _currentLatitude != null && 
        _longitude != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _currentAddress != null && 
            _currentLatitude != null && _longitude != null) {
          _onComplete();
        }
      });
    }
    
    // 지도에 줌 조정 메시지 전송 (웹 전용)
    if (kIsWeb && _currentLatitude != null && _longitude != null) {
      web.postMessageToMap({
        'type': 'ADJUST_ZOOM',
        'displayRadiusMeters': distance,
        'fixedRadiusMeters': _fixedRadiusMeters,
        'latitude': _currentLatitude,
        'longitude': _longitude,
      });
    }
  }

  /// 완료 버튼 클릭 처리
  void _onComplete() {
    if (_currentAddress == null || 
        _currentLatitude == null || 
        _longitude == null) {
      return;
    }

    final result = RegionSelectionResult(
      address: _currentAddress!,
      latitude: _currentLatitude!,
      longitude: _longitude!,
      radiusMeters: _displayRadiusMeters, // 슬라이더 설정 범위 사용
    );

    widget.onComplete?.call(result);
  }

  /// 내 위치로 돌아가기 버튼 클릭 처리
  /// GPS 위치를 다시 가져와서 지도와 주소를 모두 업데이트합니다.
  Future<void> _onReturnToMyLocation() async {
    if (!kIsWeb) return;
    
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      
      // 위치 서비스 활성화 확인
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      
      // 현재 GPS 위치 가져오기
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      
      final lat = position.latitude;
      final lng = position.longitude;
      
      // 좌표 업데이트 (주소도 자동으로 업데이트됨)
      _updateLocation(lat, lng);
      
      // 지도 이동 (웹 전용)
      if (kIsWeb) {
        web.postMessageToMap({
          'type': 'GO_TO_MY_LOCATION',
          'latitude': lat,
          'longitude': lng,
          'displayRadiusMeters': _displayRadiusMeters,
        });
      }
    } catch (e) {
      Logger.warning(
        'GPS 위치 가져오기 실패',
        metadata: {'error': e.toString()},
      );
    }
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // 섹션 헤더
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AirbnbColors.background, // 명시적으로 흰색 배경 설정
              border: Border(
                bottom: BorderSide(
                  color: AirbnbColors.borderLight,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AirbnbColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: AirbnbColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '지도에서 지역 선택',
                        style: AppTypography.h4.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AirbnbColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '지도를 이동하여 원하는 지역을 선택하세요',
                        style: AppTypography.bodySmall.copyWith(
                          color: AirbnbColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 콘텐츠 영역 (스크롤 가능하도록 수정)
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 지도 (고정 높이, 작은 화면에서도 적절)
                    RegionSelectionMap(
                      height: 300,
                      displayRadiusMeters: _displayRadiusMeters, // 표시할 반경 (슬라이더 값)
                      onLocationChanged: (location) => _updateLocation(location.$1, location.$2),
                    ),
                    
                    const SizedBox(height: AppSpacing.md),
                    
                    // 내 위치로 돌아가기 버튼
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _onReturnToMyLocation,
                        icon: const Icon(
                          Icons.my_location,
                          size: 20,
                          color: AirbnbColors.primary,
                        ),
                        label: Text(
                          '내 위치로 돌아가기',
                          style: AppTypography.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AirbnbColors.primary,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          side: const BorderSide(
                            color: AirbnbColors.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.md),
                    
                    // 주소 표시
                    AddressDisplayWidget(
                      address: _currentAddress,
                      isLoading: _isLoadingAddress,
                      error: _addressError,
                    ),
                    
                    const SizedBox(height: AppSpacing.md),
                    
                    // 거리 슬라이더
                    DistanceSliderWidget(
                      distanceMeters: _displayRadiusMeters,
                      onDistanceChanged: _onDistanceChanged,
                    ),
                    
                    // 완료 버튼 - autoComplete가 활성화되어 있으면 버튼 숨김
                    if (!widget.autoComplete) ...[
                      const SizedBox(height: AppSpacing.lg),
                      CompleteButtonWidget(
                        hasAddress: _currentAddress != null && _currentAddress!.isNotEmpty,
                        onComplete: _onComplete,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

