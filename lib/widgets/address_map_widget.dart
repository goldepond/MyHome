// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui;
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// 주소 입력 탭용 지도 위젯
/// RegionSelectionMap을 기반으로 하되, 좌표 이동 기능만 제공
class AddressMapWidget extends StatefulWidget {
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
  State<AddressMapWidget> createState() => _AddressMapState();
}

class _AddressMapState extends State<AddressMapWidget> {
  bool _isInitialized = false;
  static int _mapCounter = 0;
  late final String _mapId;
  
  // iframe 저장 (안정적인 통신을 위해)
  web.HTMLIFrameElement? _iframeElement;
  
  // VWorld API 인증키
  static const String _apiKey = 'FA0D6750-3DC2-3389-B8F1-0385C5976B96';
  
  // 기본 위치 (서울시청)
  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.9780;

  @override
  void initState() {
    super.initState();
    _mapId = 'address_map_${_mapCounter++}';
    if (kIsWeb) {
      _initializeMap();
    }
  }
  
  @override
  void didUpdateWidget(AddressMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 좌표가 변경되면 지도 이동
    if ((oldWidget.latitude != widget.latitude || 
         oldWidget.longitude != widget.longitude) &&
        widget.latitude != null && 
        widget.longitude != null) {
      // 지도가 초기화될 때까지 대기
      if (_isInitialized) {
        _moveToLocation(widget.latitude!, widget.longitude!);
      } else {
        // 초기화가 완료되지 않았으면 초기화 후 이동하도록 예약
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isInitialized && mounted) {
            _moveToLocation(widget.latitude!, widget.longitude!);
          }
        });
      }
    }
  }

  void _initializeMap() {
    if (!kIsWeb) return;
    
    final lat = widget.latitude ?? _defaultLat;
    final lng = widget.longitude ?? _defaultLng;
    
    final iframe = web.HTMLIFrameElement()
      ..srcdoc = _buildHtmlContent(lat, lng).toJS
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
    
    _iframeElement = iframe; // iframe 저장 (안정적인 통신을 위해)
    
    // 플랫폼 뷰로 등록
    ui.platformViewRegistry.registerViewFactory(
      _mapId,
      (int viewId) => iframe,
    );
    
    setState(() {
      _isInitialized = true;
    });
  }
  
  /// VWorld 지도 HTML 콘텐츠 생성
  String _buildHtmlContent(double lat, double lng) {
    final latStr = lat.toString();
    final lngStr = lng.toString();
    final mapIdStr = _mapId; // mapId를 HTML에 포함하여 식별 가능하게
    
    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>주소 지도</title>
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
    // 지도 ID (iframe 식별용) - address_map_으로 시작하여 region_map_과 구분
    var mapId = '$mapIdStr';
    
    var targetLat = $latStr;
    var targetLng = $lngStr;
    
    var retryCount = 0;
    var maxRetries = 50;
    var mapInitialized = false;
    var vmap = null;
    
    function initializeMap() {
      if (mapInitialized && vmap !== null) {
        return;
      }
      
      try {
        if (typeof vw === 'undefined' || typeof vw.ol3 === 'undefined') {
          retryCount++;
          if (retryCount < maxRetries) {
            setTimeout(initializeMap, 100);
            return;
          } else {
            console.error('🗺️ [지도 HTML] vw 라이브러리 로드 시간 초과');
            var loadingEl = document.getElementById('loading');
            if (loadingEl) {
              loadingEl.textContent = '지도 로드 시간 초과';
              loadingEl.style.color = '#f00';
            }
            return;
          }
        }
        
        var initPosition = null;
        try {
          if (typeof vw.ol3.CameraPosition !== 'undefined') {
            var cameraParams = {
              longitude: targetLng,
              latitude: targetLat,
              zoom: 15
            };
            initPosition = new vw.ol3.CameraPosition(cameraParams);
          } else {
            initPosition = {
              longitude: targetLng,
              latitude: targetLat,
              zoom: 15
            };
          }
        } catch (e) {
          initPosition = {
            longitude: targetLng,
            latitude: targetLat,
            zoom: 15
          };
        }
        
        var baseMapOptions = {
          basemapType: vw.ol3.BasemapType.GRAPHIC,
          controlDensity: vw.ol3.DensityType.EMPTY,
          interactionDensity: vw.ol3.DensityType.BASIC,
          controlsAutoArrange: true
        };
        
        if (initPosition) {
          baseMapOptions.initPosition = initPosition;
        }
        
        vw.ol3.MapOptions = baseMapOptions;
        
        try {
          vmap = new vw.ol3.Map("vmap", vw.ol3.MapOptions);
        } catch (firstError) {
          try {
            var retryOptions = {
              basemapType: vw.ol3.BasemapType.GRAPHIC,
              controlDensity: vw.ol3.DensityType.EMPTY,
              interactionDensity: vw.ol3.DensityType.BASIC,
              controlsAutoArrange: true,
              initPosition: initPosition
            };
            vmap = new vw.ol3.Map("vmap", retryOptions);
          } catch (secondError) {
            console.error('🗺️ [지도 HTML] 지도 객체 생성 실패 (두 번째 시도): ' + secondError);
            var loadingEl = document.getElementById('loading');
            if (loadingEl) {
              loadingEl.textContent = '지도 생성 실패';
              loadingEl.style.color = '#f00';
            }
            return;
          }
        }
        
        mapInitialized = true;
        var loadingEl = document.getElementById('loading');
        if (loadingEl) {
          loadingEl.style.display = 'none';
        }
        
        try {
          window.parent.postMessage({ type: 'MAP_LOADED', mapId: mapId }, '*');
        } catch (e) {
          console.error('🗺️ [지도 HTML] MAP_LOADED 메시지 전송 실패: ' + e);
        }
        
        // 지도가 완전히 로드될 때까지 대기 후 초기 위치로 이동 및 마커 추가
        setTimeout(function() {
          try {
            if (vmap && typeof vmap.getView === 'function') {
              var view = vmap.getView();
              if (view) {
                var center = [targetLng, targetLat];
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
                
                if (view.setCenter && finalCenter) {
                  view.setCenter(finalCenter);
                }
                
                if (view.setZoom) {
                  view.setZoom(15);
                }
                
                // 마커 추가
                try {
                  if (vmap && typeof vw !== 'undefined' && typeof vw.ol3 !== 'undefined' && typeof vw.ol3.layer !== 'undefined' && typeof vw.ol3.layer.Marker !== 'undefined') {
                    var markerLayer = new vw.ol3.layer.Marker(vmap);
                    var markerOptions = {
                      x: targetLng,
                      y: targetLat,
                      epsg: 'EPSG:4326',
                      title: '선택된 주소',
                      contents: '주소 검색으로 선택한 위치입니다',
                      iconUrl: 'https://map.vworld.kr/images/marker/marker_red.png',
                      imgAnchor: {x: 0.5, y: 1.0}
                    };
                    markerLayer.addMarker(markerOptions);
                  }
                } catch (markerError) {
                  console.warn('🗺️ [지도 HTML] 마커 추가 오류:', markerError);
                }
              }
            }
          } catch (moveError) {
            console.error('🗺️ [지도 HTML] 초기 위치 이동 오류: ' + moveError);
          }
        }, 2000);
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
    
    // 주소로 이동 메시지 리스너
    window.addEventListener('message', function(event) {
      try {
        if (event.data && event.data.type === 'GO_TO_LOCATION') {
          var lat = event.data.latitude;
          var lon = event.data.longitude;
          
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
                try {
                  view.setCenter(finalCenter);
                } catch (e) {
                  console.error('🗺️ [지도 HTML] setCenter 호출 오류: ' + e);
                }
              }
              
              // 적절한 줌 레벨 설정
              if (view.setZoom) {
                try {
                  view.setZoom(15);
                } catch (e) {
                  console.error('🗺️ [지도 HTML] setZoom 호출 오류: ' + e);
                }
              }
              
              // 마커 업데이트 (기존 마커 제거 후 새로 추가)
              try {
                if (vmap && typeof vw !== 'undefined' && typeof vw.ol3 !== 'undefined' && typeof vw.ol3.layer !== 'undefined' && typeof vw.ol3.layer.Marker !== 'undefined') {
                  // 기존 마커 레이어 제거 (있는 경우)
                  try {
                    var layers = vmap.getLayers();
                    if (layers && layers.getArray) {
                      var layerArray = layers.getArray();
                      for (var i = layerArray.length - 1; i >= 0; i--) {
                        var layer = layerArray[i];
                        if (layer && layer.get && layer.get('type') === 'marker') {
                          vmap.removeLayer(layer);
                        }
                      }
                    }
                  } catch (e) {
                    // 무시
                  }
                  
                  // 새 마커 추가
                  var markerLayer = new vw.ol3.layer.Marker(vmap);
                  var markerOptions = {
                    x: lon,
                    y: lat,
                    epsg: 'EPSG:4326',
                    title: '선택된 주소',
                    contents: '주소 검색으로 선택한 위치입니다',
                    iconUrl: 'https://map.vworld.kr/images/marker/marker_red.png',
                    imgAnchor: {x: 0.5, y: 1.0}
                  };
                  markerLayer.addMarker(markerOptions);
                }
              } catch (markerError) {
                console.warn('🗺️ [지도 HTML] 마커 업데이트 오류:', markerError);
              }
            }
          }
        }
      } catch (e) {
        console.error('🗺️ [지도 HTML] 메시지 처리 오류: ' + e);
      }
    });
    
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', function() {
        setTimeout(initializeMap, 500);
      });
    } else {
      setTimeout(initializeMap, 500);
    }
  </script>
</body>
</html>
''';
  }
  
  /// 지도를 특정 좌표로 이동
  void moveToLocation(double latitude, double longitude) {
    if (!kIsWeb || !_isInitialized) return;
    _moveToLocation(latitude, longitude);
  }
  
  void _moveToLocation(double latitude, double longitude) {
    if (!kIsWeb || !_isInitialized) return;
    
    // 방법 1: 저장된 iframe 사용 (가장 안정적)
    if (_iframeElement != null && _iframeElement!.contentWindow != null) {
      final jsMessage = {
        'type': 'GO_TO_LOCATION',
        'latitude': latitude,
        'longitude': longitude,
      }.jsify() as JSObject;
      _iframeElement!.contentWindow!.postMessage(jsMessage, '*'.toJS);
      return;
    }
    
    // 방법 2: 저장된 iframe이 없으면 찾기 (백업 방법)
    final iframes = web.document.querySelectorAll('iframe');
    web.HTMLIFrameElement? targetIframe;
    
    // NodeList를 리스트로 변환 (item() 메서드 사용)
    final iframeList = <web.HTMLIFrameElement>[];
    for (var i = 0; i < iframes.length; i++) {
      final iframe = iframes.item(i);
      if (iframe is web.HTMLIFrameElement) {
        iframeList.add(iframe);
      }
    }
    
    // address_map_을 포함하지만 region_map_은 포함하지 않는 iframe 찾기
    // (지도 선택 기능과 구분하기 위해)
    for (var element in iframeList) {
      final srcdoc = element.srcdoc;
      if (srcdoc != null) {
        if (srcdoc.isA<JSString>()) {
          final srcdocStr = (srcdoc as JSString).toDart;
          if (srcdocStr.isNotEmpty) {
            if (srcdocStr.contains('address_map_') && 
                !srcdocStr.contains('region_map_')) {
              targetIframe = element;
              _iframeElement = element; // 찾은 iframe 저장 (다음번에는 저장된 것 사용)
              break;
            }
          }
        }
      }
    }
    
    if (targetIframe != null && targetIframe.contentWindow != null) {
      final jsMessage = {
        'type': 'GO_TO_LOCATION',
        'latitude': latitude,
        'longitude': longitude,
      }.jsify() as JSObject;
      targetIframe.contentWindow!.postMessage(jsMessage, '*'.toJS);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('지도는 웹에서만 지원됩니다'),
        ),
      );
    }
    
    return SizedBox(
      height: widget.height,
      child: HtmlElementView(
        viewType: _mapId,
        onPlatformViewCreated: (int viewId) {
          _isInitialized = true;
          // 초기 좌표가 있으면 이동
          if (widget.latitude != null && widget.longitude != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _moveToLocation(widget.latitude!, widget.longitude!);
            });
          }
        },
      ),
    );
  }
}

