import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/apple_design_system.dart';

/// 모바일용 주소 지도 위젯 (WebView 사용)
class AddressMapWidgetMobile extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double height;

  const AddressMapWidgetMobile({
    super.key,
    this.latitude,
    this.longitude,
    this.height = 300,
  });

  @override
  State<AddressMapWidgetMobile> createState() => _AddressMapWidgetMobileState();
}

class _AddressMapWidgetMobileState extends State<AddressMapWidgetMobile> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  // VWorld API 인증키 (환경변수에서 로드)
  static String get _apiKey => const String.fromEnvironment('VWORLD_MAP_API_KEY', defaultValue: 'FA0D6750-3DC2-3389-B8F1-0385C5976B96');

  // 기본 위치 (서울시청)
  static const double _defaultLat = 37.5665;
  static const double _defaultLng = 126.9780;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final lat = widget.latitude ?? _defaultLat;
    final lng = widget.longitude ?? _defaultLng;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              // 지도 로드 후 위치 이동
              _moveToLocation(lat, lng);
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadHtmlString(_buildHtmlContent(lat, lng));
  }

  @override
  void didUpdateWidget(AddressMapWidgetMobile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 좌표가 변경되면 지도 이동
    if ((oldWidget.latitude != widget.latitude ||
            oldWidget.longitude != widget.longitude) &&
        widget.latitude != null &&
        widget.longitude != null) {
      _moveToLocation(widget.latitude!, widget.longitude!);
    }
  }

  void _moveToLocation(double lat, double lng) {
    final js = '''
      if (typeof moveToLocation === 'function') {
        moveToLocation($lat, $lng);
      }
    ''';
    _controller.runJavaScript(js);
  }

  String _buildHtmlContent(double lat, double lng) {
    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>주소 지도</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; }
    #vmap { width: 100%; height: 100%; }
    .loading {
      position: absolute;
      top: 50%; left: 50%;
      transform: translate(-50%, -50%);
      color: #666;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      z-index: 1000;
      background: rgba(255, 255, 255, 0.9);
      padding: 10px 20px;
      border-radius: 8px;
    }
  </style>
  <script src="https://map.vworld.kr/js/vworldMapInit.js.do?version=2.0&apiKey=$_apiKey"></script>
</head>
<body>
  <div id="vmap"></div>
  <div class="loading" id="loading">지도를 불러오는 중...</div>
  <script>
    var targetLat = $lat;
    var targetLng = $lng;
    var vmap = null;
    var markerLayer = null;
    var retryCount = 0;
    var maxRetries = 50;

    function initializeMap() {
      try {
        if (typeof vw === 'undefined' || typeof vw.ol3 === 'undefined') {
          retryCount++;
          if (retryCount < maxRetries) {
            setTimeout(initializeMap, 100);
            return;
          }
          document.getElementById('loading').textContent = '지도 로드 실패';
          return;
        }

        var initPosition = new vw.ol3.CameraPosition({
          longitude: targetLng,
          latitude: targetLat,
          zoom: 15
        });

        vw.ol3.MapOptions = {
          basemapType: vw.ol3.BasemapType.GRAPHIC,
          controlDensity: vw.ol3.DensityType.EMPTY,
          interactionDensity: vw.ol3.DensityType.BASIC,
          controlsAutoArrange: true,
          initPosition: initPosition
        };

        vmap = new vw.ol3.Map("vmap", vw.ol3.MapOptions);
        document.getElementById('loading').style.display = 'none';

        // 마커 추가
        setTimeout(function() {
          addMarker(targetLat, targetLng);
        }, 1000);

      } catch (e) {
        document.getElementById('loading').textContent = '지도 로드 실패';
      }
    }

    function addMarker(lat, lng) {
      try {
        if (vmap && typeof vw.ol3.layer.Marker !== 'undefined') {
          markerLayer = new vw.ol3.layer.Marker(vmap);
          markerLayer.addMarker({
            x: lng, y: lat,
            epsg: 'EPSG:4326',
            title: '선택된 주소',
            iconUrl: 'https://map.vworld.kr/images/marker/marker_red.png',
            imgAnchor: {x: 0.5, y: 1.0}
          });
        }
      } catch (e) {}
    }

    function moveToLocation(lat, lng) {
      targetLat = lat;
      targetLng = lng;

      if (vmap && typeof vmap.getView === 'function') {
        try {
          var view = vmap.getView();
          var center = [lng, lat];

          if (typeof ol !== 'undefined' && ol.proj && ol.proj.fromLonLat) {
            center = ol.proj.fromLonLat(center);
          }

          view.setCenter(center);
          view.setZoom(15);

          // 마커 업데이트
          if (markerLayer) {
            try {
              var layers = vmap.getLayers().getArray();
              for (var i = layers.length - 1; i >= 0; i--) {
                if (layers[i].get && layers[i].get('type') === 'marker') {
                  vmap.removeLayer(layers[i]);
                }
              }
            } catch (e) {}
          }
          addMarker(lat, lng);
        } catch (e) {}
      }
    }

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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppleRadius.md),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: AppleColors.secondarySystemGroupedBackground,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_hasError)
              Container(
                color: AppleColors.secondarySystemGroupedBackground,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: AppleColors.tertiaryLabel,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '지도를 불러올 수 없습니다',
                        style: TextStyle(
                          color: AppleColors.tertiaryLabel,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
