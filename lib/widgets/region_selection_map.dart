// 웹 전용 import (조건부)
import 'region_selection_map_stub.dart'
    if (dart.library.html) 'region_selection_map_web.dart' as web_map;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:property/constants/app_constants.dart';

/// 지역 선택 지도 위젯
/// 
/// VWorld OpenLayers 3.10.1 API를 사용하여 지도를 표시합니다.
/// GPS 위치를 자동으로 감지하고 현재 위치에 마커를 표시합니다.
/// 
/// Flutter Web에서만 작동합니다.
/// 
/// 사용법:
/// ```dart
/// RegionSelectionMap(
///   height: 400,
///   radiusMeters: 500.0,
/// )
/// ```
class RegionSelectionMap extends StatefulWidget {
  /// 지도 높이 (기본값: 400)
  final double height;
  
  /// 실제 원의 반경 (미터 단위, 고정값)
  final double fixedRadiusMeters;
  
  /// 표시할 반경 (미터 단위, 지도 줌 조정에 사용)
  final double displayRadiusMeters;
  
  /// 초기 위도 (선택 사항, 주소 입력 탭에서 사용)
  final double? latitude;
  
  /// 초기 경도 (선택 사항, 주소 입력 탭에서 사용)
  final double? longitude;
  
  /// 위치 변경 콜백 (위도, 경도)
  final ValueChanged<(double, double)>? onLocationChanged;
  
  /// 내 위치로 돌아가기 요청 콜백
  final VoidCallback? onReturnToMyLocationRequested;

  const RegionSelectionMap({
    super.key,
    this.height = 400,
    this.fixedRadiusMeters = 500.0,
    this.displayRadiusMeters = 500.0,
    this.latitude,
    this.longitude,
    this.onLocationChanged,
    this.onReturnToMyLocationRequested,
  });

  @override
  State<RegionSelectionMap> createState() => _RegionSelectionMapState();
}

class _RegionSelectionMapState extends State<RegionSelectionMap> {
  bool _isInitialized = false;
  bool _isLoadingLocation = true;
  static int _mapCounter = 0;
  late final String _mapId;
  
  // GPS 위치 정보
  double? _latitude;
  double? _longitude;

  // VWorld API 인증키
  static const String _apiKey = 'FA0D6750-3DC2-3389-B8F1-0385C5976B96';
  
  // 기본 위치 (서울시청)
  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.9780;

  @override
  void initState() {
    super.initState();
    _mapId = 'region_map_${_mapCounter++}';
    if (kIsWeb) {
      // 위젯에 좌표가 제공되면 그것을 사용, 그렇지 않으면 GPS 위치 가져오기
      if (widget.latitude != null && widget.longitude != null) {
        _latitude = widget.latitude;
        _longitude = widget.longitude;
        _isLoadingLocation = false;
      } else {
        _getCurrentLocation();
      }
    }
  }
  
  @override
  void didUpdateWidget(RegionSelectionMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 표시 반경이 변경되면 지도 줌만 조정 (원은 고정)
    if (oldWidget.displayRadiusMeters != widget.displayRadiusMeters && _isInitialized) {
      _adjustMapZoom();
    }
    
    // 좌표가 변경되면 지도를 해당 위치로 이동
    if ((oldWidget.latitude != widget.latitude || oldWidget.longitude != widget.longitude) &&
        widget.latitude != null && widget.longitude != null && _isInitialized) {
      _latitude = widget.latitude;
      _longitude = widget.longitude;
      _moveMapToLocation(widget.latitude!, widget.longitude!);
    }
  }
  
  /// 지도 줌만 조정 (원의 크기는 변경하지 않음)
  void _adjustMapZoom() {
    if (!kIsWeb || !_isInitialized) return;
    
    final lat = _latitude ?? _defaultLat;
    final lng = _longitude ?? _defaultLng;
    
    // iframe에 메시지 전송하여 줌 조정 (웹 전용)
    if (kIsWeb) {
      final iframe = web_map.findMapIframe();
      if (iframe != null) {
        web_map.postMessageToIframe(iframe, {
          'type': 'ADJUST_ZOOM',
          'displayRadiusMeters': widget.displayRadiusMeters,
          'fixedRadiusMeters': widget.fixedRadiusMeters,
          'latitude': lat,
          'longitude': lng,
        });
      } else {
        // iframe을 찾을 수 없으면 지도 재초기화
        _initializeMap();
      }
    }
  }
  
  /// 지도를 특정 좌표로 이동
  void _moveMapToLocation(double latitude, double longitude) {
    if (!kIsWeb || !_isInitialized) return;
    
    // iframe에 메시지 전송하여 지도 이동 (웹 전용)
    if (kIsWeb) {
      final iframe = web_map.findMapIframe();
      if (iframe != null) {
        web_map.postMessageToIframe(iframe, {
          'type': 'GO_TO_MY_LOCATION',
          'latitude': latitude,
          'longitude': longitude,
          'displayRadiusMeters': widget.displayRadiusMeters,
          'fixedRadiusMeters': widget.fixedRadiusMeters,
        });
      }
    }
  }
  
  /// GPS 위치 가져오기 (웹 전용)
  Future<void> _getCurrentLocation() async {
    // Windows/모바일에서는 GPS 기능 비활성화
    if (!kIsWeb) {
      _setDefaultLocation();
      return;
    }
    
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setDefaultLocation();
        return;
      }

      // 위치 서비스 활성화 확인
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      if (!serviceEnabled) {
        _setDefaultLocation();
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isLoadingLocation = false;
        });
        _initializeMap();
      }
    } catch (e) {
      // 에러 발생 시 기본 위치 사용
      if (mounted) {
        _setDefaultLocation();
      }
    }
  }
  
  /// 기본 위치 설정 (서울시청)
  void _setDefaultLocation() {
    setState(() {
      _latitude = _defaultLat;
      _longitude = _defaultLng;
      _isLoadingLocation = false;
    });
    _initializeMap();
  }

  void _initializeMap() {
    // Windows/모바일에서는 지도 초기화하지 않음
    if (!kIsWeb) {
      setState(() {
        _isInitialized = true;
        _isLoadingLocation = false;
      });
      return;
    }
    
    // GPS 위치가 없으면 기본 위치 사용
    final lat = _latitude ?? _defaultLat;
    final lng = _longitude ?? _defaultLng;
    
    // 초기 위치를 콜백으로 전달 (지도 로드 전에 미리 전달)
    widget.onLocationChanged?.call((lat, lng));
    
    // HTML 콘텐츠 생성 (GPS 좌표, 실제 반경, 표시 반경 전달)
    final htmlContent = _buildHtmlContent(lat, lng, widget.fixedRadiusMeters, widget.displayRadiusMeters);
    
    // iframe 생성 및 등록 (웹 전용)
    final iframe = web_map.createIframeElement();
    web_map.setupIframe(iframe, htmlContent);
    web_map.registerPlatformView(_mapId, iframe);
    
    setState(() {
      _isInitialized = true;
    });
  }

  /// VWorld 지도 HTML 콘텐츠 생성
  /// [lat] 위도
  /// [lng] 경도
  /// [fixedRadiusMeters] 실제 원의 반경 (미터 단위, 고정)
  /// [displayRadiusMeters] 표시할 반경 (미터 단위, 지도 줌 조정에 사용)
  String _buildHtmlContent(double lat, double lng, double fixedRadiusMeters, double displayRadiusMeters) {
    // 좌표 값을 안전하게 JavaScript 숫자 리터럴로 변환
    final latStr = lat.toString();
    final lngStr = lng.toString();
    final fixedRadiusStr = fixedRadiusMeters.toString();
    final displayRadiusStr = displayRadiusMeters.toString();
    
    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>지역 선택 지도</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
    }
    #vmap {
      width: 100%;
      height: 100%;
    }
    .loading {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      color: #666;
      font-family: Arial, sans-serif;
      z-index: 1000;
      background: rgba(255, 255, 255, 0.9);
      padding: 10px 20px;
      border-radius: 4px;
    }
  </style>
  <script type="text/javascript" src="https://map.vworld.kr/js/vworldMapInit.js.do?version=2.0&apiKey=$_apiKey"></script>
</head>
<body>
  <div id="vmap"></div>
  <div class="loading" id="loading">지도를 불러오는 중...</div>
  <script type="text/javascript">
    var targetLat = $latStr;
    var targetLng = $lngStr;
    // ⚠️ 중요: 원의 크기는 항상 fixedRadiusMeters로 고정됩니다 (500m)
    // 슬라이더를 조정해도 원의 크기는 변경되지 않고, 지도 줌만 조정됩니다.
    var fixedRadiusMeters = $fixedRadiusStr;  // 실제 원의 반경 (고정, 항상 500m)
    var displayRadiusMeters = $displayRadiusStr;  // 표시할 반경 (지도 줌 조정용, 슬라이더 값)
    
    // 반경에 맞는 extent 계산 함수 (EPSG:4326)
    function calculateCircleExtent(centerLon, centerLat, radiusMeters) {
      // 위도에 따른 미터당 도 변환
      var latRad = centerLat * Math.PI / 180;
      var metersPerDegreeLat = 111320;
      var metersPerDegreeLon = 111320 * Math.cos(latRad);
      
      // 반경을 도 단위로 변환
      var radiusDegreesLat = radiusMeters / metersPerDegreeLat;
      var radiusDegreesLon = radiusMeters / metersPerDegreeLon;
      
      // extent 계산 (minLon, minLat, maxLon, maxLat)
      var minLon = centerLon - radiusDegreesLon;
      var maxLon = centerLon + radiusDegreesLon;
      var minLat = centerLat - radiusDegreesLat;
      var maxLat = centerLat + radiusDegreesLat;
      
      return [minLon, minLat, maxLon, maxLat];
    }
    
    // 반경에 맞는 줌 레벨 계산
    function calculateZoomForRadius(radiusMeters) {
      // 거리가 짧을수록 줌 레벨이 높아져서 더 확대되도록 조정
      // 300m → 17, 500m → 16, 1km → 15, 1.5km → 14
      if (radiusMeters <= 300) return 17;
      if (radiusMeters <= 500) return 16;
      if (radiusMeters <= 1000) return 15;
      return 14;
    }
    
    // 지도를 반경에 맞게 조정하는 함수
    // fit()이 VWorld에서 제대로 작동하지 않으므로 직접 줌 레벨만 사용
    function adjustMapToRadius(vmap, view, centerLon, centerLat, radiusMeters) {
      try {
        // 현재 줌 레벨 확인
        var currentZoom = null;
        if (view && typeof view.getZoom === 'function') {
          currentZoom = view.getZoom();
        }
        
        // 목표 줌 레벨 계산
        var targetZoom = calculateZoomForRadius(radiusMeters);
        
        // 직접 줌 레벨 설정 (fit()은 VWorld에서 제대로 작동하지 않음)
        if (view && typeof view.setZoom === 'function') {
          view.setZoom(targetZoom);
          return true;
        }
        
        return false;
      } catch (e) {
        console.error('[지도 조정 오류]', e);
        return false;
      }
    }
    
    console.log('[지도 초기화] JavaScript 실행 시작');
    console.log('[지도 초기화] 초기 위치 - 위도: ' + targetLat + ', 경도: ' + targetLng);
    console.log('[지도 초기화] 반경 정보 - 고정 반경: ' + fixedRadiusMeters + 'm, 표시 반경: ' + displayRadiusMeters + 'm');
    
    var retryCount = 0;
    var maxRetries = 50;
    var mapInitialized = false;
    var vmap = null;
    
    function initializeMap() {
      console.log('[지도 초기화] initializeMap 호출 - retryCount: ' + retryCount + ', mapInitialized: ' + mapInitialized);
      
      if (mapInitialized && vmap !== null) {
        console.log('[지도 초기화] 이미 초기화됨, 종료');
        return;
      }
      
      try {
        console.log('[지도 초기화] VWorld API 스크립트 확인 중...');
        console.log('[지도 초기화] typeof vw: ' + typeof vw);
        console.log('[지도 초기화] typeof vw.ol3: ' + (typeof vw !== 'undefined' ? typeof vw.ol3 : 'undefined'));
        
        if (typeof vw === 'undefined' || typeof vw.ol3 === 'undefined') {
          retryCount++;
          console.log('[지도 초기화] VWorld API 스크립트 로드 대기 중... (재시도: ' + retryCount + '/' + maxRetries + ')');
          if (retryCount < maxRetries) {
            setTimeout(initializeMap, 100);
            return;
          } else {
            console.error('[지도 초기화] VWorld API 스크립트 로드 시간 초과');
            var loadingEl = document.getElementById('loading');
            if (loadingEl) {
              loadingEl.textContent = '지도 로드 시간 초과';
              loadingEl.style.color = '#f00';
            }
            return;
          }
        }
        
        console.log('[지도 초기화] VWorld API 스크립트 로드 완료');
        
        // 초기 줌 레벨 계산 (표시 반경에 맞게)
        var initialZoom = calculateZoomForRadius(displayRadiusMeters);
        console.log('[지도 초기화] 초기 줌 레벨 계산: ' + initialZoom);
        
        var initPosition = null;
        try {
          console.log('[지도 초기화] CameraPosition 생성 시도...');
          if (typeof vw.ol3.CameraPosition !== 'undefined') {
            var cameraParams = {
              longitude: targetLng,
              latitude: targetLat,
              zoom: initialZoom
            };
            initPosition = new vw.ol3.CameraPosition(cameraParams);
            console.log('[지도 초기화] CameraPosition 생성 성공');
          } else {
            console.log('[지도 초기화] CameraPosition 없음, 객체 리터럴 사용');
            initPosition = {
              longitude: targetLng,
              latitude: targetLat,
              zoom: initialZoom
            };
          }
        } catch (e) {
          console.warn('[지도 초기화] CameraPosition 생성 실패, 객체 리터럴 사용:', e);
          initPosition = {
            longitude: targetLng,
            latitude: targetLat,
            zoom: initialZoom
          };
        }
        
        console.log('[지도 초기화] MapOptions 설정 중...');
        var baseMapOptions = {
          basemapType: vw.ol3.BasemapType.GRAPHIC,
          controlDensity: vw.ol3.DensityType.EMPTY,
          interactionDensity: vw.ol3.DensityType.BASIC,
          controlsAutoArrange: true
        };
        
        if (initPosition) {
          baseMapOptions.initPosition = initPosition;
          console.log('[지도 초기화] initPosition 설정됨');
        }
        
        vw.ol3.MapOptions = baseMapOptions;
        console.log('[지도 초기화] MapOptions 설정 완료');
        
        console.log('[지도 초기화] 지도 생성 시도...');
        try {
          vmap = new vw.ol3.Map("vmap", vw.ol3.MapOptions);
          console.log('[지도 초기화] 지도 생성 성공 (첫 번째 시도)');
        } catch (firstError) {
          console.warn('[지도 초기화] 지도 생성 실패 (첫 번째 시도):', firstError);
          try {
            console.log('[지도 초기화] 지도 생성 재시도 (initPosition 제외)...');
            var retryOptions = {
              basemapType: vw.ol3.BasemapType.GRAPHIC,
              controlDensity: vw.ol3.DensityType.EMPTY,
              interactionDensity: vw.ol3.DensityType.BASIC,
              controlsAutoArrange: true
            };
            vmap = new vw.ol3.Map("vmap", retryOptions);
            console.log('[지도 초기화] 지도 생성 성공 (재시도)');
          } catch (secondError) {
            console.error('[지도 초기화] 지도 생성 실패 (재시도):', secondError);
            throw secondError;
          }
        }
        
        if (vmap) {
          console.log('[지도 초기화] 지도 객체 생성 완료, 후속 작업 시작...');
          setTimeout(function() {
            console.log('[지도 초기화] 후속 작업 시작 (2초 후)...');
            try {
              if (vmap && typeof vmap.getView === 'function') {
                console.log('[지도 초기화] getView() 호출 중...');
                var view = vmap.getView();
                console.log('[지도 초기화] view 객체:', view);
                if (view) {
                  console.log('[지도 초기화] view 객체 확인됨');
                  var center = [targetLng, targetLat];
                  console.log('[지도 초기화] 중심 좌표 (EPSG:4326):', center);
                  
                  // 중심 좌표 변환 (EPSG:4326 → EPSG:3857)
                  var finalCenter = null;
                  if (typeof ol !== 'undefined' && ol.proj && ol.proj.fromLonLat) {
                    console.log('[지도 초기화] 좌표 변환 시도 (EPSG:4326 → EPSG:3857)...');
                    try {
                      finalCenter = ol.proj.fromLonLat(center);
                      console.log('[지도 초기화] 좌표 변환 성공:', finalCenter);
                    } catch (e) {
                      console.warn('[지도 초기화] 좌표 변환 실패, 원본 좌표 사용:', e);
                      finalCenter = center;
                    }
                  } else {
                    console.warn('[지도 초기화] ol.proj 없음, 원본 좌표 사용');
                    finalCenter = center;
                  }
                  
                  // 중심 설정
                  if (view.setCenter && finalCenter) {
                    console.log('[지도 초기화] setCenter() 호출 중...');
                    view.setCenter(finalCenter);
                    console.log('[지도 초기화] setCenter() 완료');
                  } else {
                    console.warn('[지도 초기화] setCenter() 호출 불가 - view.setCenter:', typeof view.setCenter, ', finalCenter:', finalCenter);
                  }
                  
                  // 현재 줌 레벨 확인
                  var currentZoom = null;
                  if (typeof view.getZoom === 'function') {
                    currentZoom = view.getZoom();
                    console.log('[지도 초기화] 현재 줌 레벨:', currentZoom);
                  }
                  
                  // 목표 줌 레벨 계산
                  var targetZoom = calculateZoomForRadius(displayRadiusMeters);
                  console.log('[지도 초기화] 목표 줌 레벨:', targetZoom);
                  
                  // ✅ fit() 방식으로 표시 반경에 맞게 지도 조정
                  // 실제 원의 크기는 fixedRadiusMeters로 고정되어 있음
                  console.log('[지도 초기화] adjustMapToRadius() 호출 중...');
                  var adjusted = adjustMapToRadius(vmap, view, targetLng, targetLat, displayRadiusMeters);
                  console.log('[지도 초기화] adjustMapToRadius() 결과:', adjusted);
                  
                  // fit()이 실패했거나 사용할 수 없으면 줌 레벨만 설정
                  if (!adjusted && view.setZoom) {
                    var zoom = calculateZoomForRadius(displayRadiusMeters);
                    console.log('[지도 초기화] setZoom() 직접 호출:', zoom);
                    view.setZoom(zoom);
                  } else if (adjusted) {
                    // fit() 사용 시 줌 레벨 확인
                    setTimeout(function() {
                      console.log('[지도 초기화] 줌 레벨 확인 (200ms 후)...');
                      if (typeof view.getZoom === 'function') {
                        var newZoom = view.getZoom();
                        console.log('[지도 초기화] 새로운 줌 레벨:', newZoom);
                        
                        // fit()이 효과가 없으면 직접 설정
                        if (currentZoom !== null && Math.abs(newZoom - targetZoom) > 0.5) {
                          console.log('[지도 초기화] 줌 레벨 차이 큼, 직접 설정');
                          if (view.setZoom) {
                            view.setZoom(targetZoom);
                          }
                        }
                      }
                    }, 200);
                  }
                  
                  // 지도 이동 이벤트 리스너 추가 (moveend)
                  vmap.on('moveend', function() {
                    try {
                      console.log('[지도 이동] moveend 이벤트 발생');
                      if (view && view.getCenter) {
                        var center3857 = view.getCenter();
                        console.log('[지도 이동] 중심 좌표 (EPSG:3857):', center3857);
                        if (center3857 && Array.isArray(center3857) && center3857.length >= 2) {
                          // EPSG:3857 → EPSG:4326 변환
                          if (typeof ol !== 'undefined' && ol.proj && ol.proj.toLonLat) {
                            try {
                              var center4326 = ol.proj.toLonLat(center3857);
                              console.log('[지도 이동] 변환된 좌표 (EPSG:4326):', center4326);
                              if (center4326 && Array.isArray(center4326) && center4326.length >= 2) {
                                var lon = center4326[0];
                                var lat = center4326[1];
                                console.log('[지도 이동] 최종 좌표: lat=' + lat + ', lon=' + lon);
                                
                                // 부모 창에 메시지 전달
                                if (window.parent && window.parent !== window) {
                                  var message = {
                                    type: 'MAP_LOCATION_CHANGED',
                                    latitude: lat,
                                    longitude: lon
                                  };
                                  console.log('[지도 이동] 메시지 전송:', message);
                                  window.parent.postMessage(message, '*');
                                } else {
                                  console.warn('[지도 이동] window.parent 없음');
                                }
                              } else {
                                console.warn('[지도 이동] 좌표 변환 결과가 유효하지 않음:', center4326);
                              }
                            } catch (e) {
                              console.error('[지도 이동] 좌표 변환 실패:', e);
                            }
                          } else {
                            console.warn('[지도 이동] ol.proj.toLonLat 없음');
                          }
                        } else {
                          console.warn('[지도 이동] 중심 좌표가 유효하지 않음:', center3857);
                        }
                      } else {
                        console.warn('[지도 이동] view 또는 getCenter 없음');
                      }
                    } catch (e) {
                      console.error('[지도 이동] 에러:', e);
                    }
                  });
                  
                  // 마커 추가
                  console.log('[지도 초기화] 마커 추가 시도...');
                  try {
                    var markerLayer = new vw.ol3.layer.Marker(vmap);
                    var markerOptions = {
                      x: targetLng,
                      y: targetLat,
                      epsg: 'EPSG:4326',
                      title: '현재 위치',
                      contents: '내 현재 위치입니다',
                      iconUrl: 'https://map.vworld.kr/images/marker/marker_red.png'
                    };
                    markerLayer.addMarker(markerOptions);
                    console.log('[지도 초기화] 마커 추가 성공');
                  } catch (markerError) {
                    console.warn('[지도 초기화] 마커 추가 실패:', markerError);
                  }
                  
                  // 초기 위치를 부모 창에 전달 (지도가 완전히 로드된 후)
                  setTimeout(function() {
                    try {
                      if (window.parent && window.parent !== window) {
                        window.parent.postMessage({
                          type: 'MAP_LOCATION_CHANGED',
                          latitude: targetLat,
                          longitude: targetLng
                        }, '*');
                      }
                    } catch (e) {
                      // 에러는 무시
                    }
                  }, 500);
                  
                }
              }
            } catch (moveError) {
              // 이동 실패는 무시
            }
          }, 2000);
          
          mapInitialized = true;
          
          // 로딩 화면 숨기기
          setTimeout(function() {
            var loadingEl = document.getElementById('loading');
            if (loadingEl) {
              loadingEl.style.display = 'none';
            }
          }, 1000);
        }
      } catch (error) {
        var loadingEl = document.getElementById('loading');
        if (loadingEl && !mapInitialized) {
          loadingEl.textContent = '지도 로드 실패';
          loadingEl.style.color = '#f00';
        } else if (loadingEl) {
          loadingEl.style.display = 'none';
        }
      }
    }
    
    // 현재 위치로 이동 메시지 리스너
    window.addEventListener('message', function(event) {
      try {
        if (event.data && event.data.type === 'GO_TO_MY_LOCATION') {
          var lat = event.data.latitude;
          var lon = event.data.longitude;
          var displayRadius = event.data.displayRadiusMeters;
          
          if (vmap && typeof vmap.getView === 'function') {
            var view = vmap.getView();
            if (view) {
              // 중심 좌표 변환 (EPSG:4326 → EPSG:3857)
              var center = [lon, lat];
              var finalCenter = null;
              if (typeof ol !== 'undefined' && ol.proj && ol.proj.fromLonLat) {
                try {
                  finalCenter = ol.proj.fromLonLat(center);
                } catch (e) {
                  finalCenter = center;
                }
              } else {
                finalCenter = center;
              }
              
              // 지도 중심 이동
              if (view.setCenter && finalCenter) {
                view.setCenter(finalCenter);
              }
              
              // 줌 레벨 조정
              var targetZoom = calculateZoomForRadius(displayRadius);
              if (view.setZoom) {
                view.setZoom(targetZoom);
              }
            }
          }
        }
      } catch (e) {
        // 에러는 무시
      }
    });
    
    // 표시 반경 변경 메시지 리스너 (줌만 조정)
    window.addEventListener('message', function(event) {
      try {
        if (event.data && event.data.type === 'ADJUST_ZOOM') {
          var displayRadius = event.data.displayRadiusMeters;
          var fixedRadius = event.data.fixedRadiusMeters;
          var lat = event.data.latitude;
          var lon = event.data.longitude;
          
          if (vmap && typeof vmap.getView === 'function') {
            var view = vmap.getView();
            if (view) {
              // 현재 줌 레벨 확인
              var currentZoom = null;
              if (typeof view.getZoom === 'function') {
                currentZoom = view.getZoom();
              }
              
              // 목표 줌 레벨 계산
              var targetZoom = calculateZoomForRadius(displayRadius);
              
              // 지도 줌만 조정 (원의 크기는 변경하지 않음)
              var adjusted = adjustMapToRadius(vmap, view, lon, lat, displayRadius);
              
              if (!adjusted && view.setZoom) {
                var zoom = calculateZoomForRadius(displayRadius);
                view.setZoom(zoom);
              } else if (adjusted) {
                // fit() 사용 시 줌 레벨 확인
                setTimeout(function() {
                  if (typeof view.getZoom === 'function') {
                    var newZoom = view.getZoom();
                    
                    // fit()이 효과가 없으면 직접 설정
                    if (currentZoom !== null && Math.abs(newZoom - targetZoom) > 0.5) {
                      if (view.setZoom) {
                        view.setZoom(targetZoom);
                      }
                    }
                  }
                }, 200);
              }
            }
          }
        }
      } catch (e) {
        // 에러는 무시
      }
    });
    
    console.log('[지도 초기화] DOM 상태 확인:', document.readyState);
    if (document.readyState === 'loading') {
      console.log('[지도 초기화] DOM 로딩 중, DOMContentLoaded 이벤트 대기...');
      document.addEventListener('DOMContentLoaded', function() {
        console.log('[지도 초기화] DOMContentLoaded 이벤트 발생, initializeMap 호출 예약 (500ms 후)...');
        setTimeout(initializeMap, 500);
      });
    } else {
      console.log('[지도 초기화] DOM 로드 완료, initializeMap 호출 예약 (500ms 후)...');
      setTimeout(initializeMap, 500);
    }
  </script>
</body>
</html>
''';
  }

  /// 현재 GPS 위치로 지도 이동 (public 메서드)
  void returnToMyLocation() {
    if (!kIsWeb || !_isInitialized) return;
    
    final lat = _latitude ?? _defaultLat;
    final lng = _longitude ?? _defaultLng;
    
    // iframe에 메시지 전송하여 지도 이동
    // 웹 전용: iframe에 메시지 전송
    if (kIsWeb) {
      final iframe = web_map.findMapIframe();
      if (iframe != null) {
        web_map.postMessageToIframe(iframe, {
          'type': 'GO_TO_MY_LOCATION',
          'latitude': lat,
          'longitude': lng,
          'displayRadiusMeters': widget.displayRadiusMeters,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          border: Border.all(
            color: AirbnbColors.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            '지도는 웹에서만 지원됩니다.',
            style: TextStyle(color: AirbnbColors.textSecondary),
          ),
        ),
      );
    }

    if (!_isInitialized || _isLoadingLocation) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          border: Border.all(
            color: AirbnbColors.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _isLoadingLocation ? '위치 정보를 가져오는 중...' : '지도를 불러오는 중...',
                style: const TextStyle(
                  color: AirbnbColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(
          color: AirbnbColors.borderLight,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: HtmlElementView(
          viewType: _mapId,
        ),
      ),
    );
  }
}
