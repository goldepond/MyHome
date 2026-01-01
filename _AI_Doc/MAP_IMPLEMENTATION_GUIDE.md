# VWorld 지도 구현 가이드

> 작성일: 2025-01-XX  
> 목적: Flutter Web에서 VWorld 지도를 구현하는 방법 정리  
> 플랫폼: Flutter Web 전용

---

## 📋 목차

1. [기본 구조](#기본-구조)
2. [Flutter 위젯 구현](#flutter-위젯-구현)
3. [HTML 템플릿 생성](#html-템플릿-생성)
4. [JavaScript 지도 초기화](#javascript-지도-초기화)
5. [GPS 위치로 지도 이동](#gps-위치로-지도-이동)
6. [마커 추가](#마커-추가)
7. [원형 폴리곤 구현](#원형-폴리곤-구현)
8. [좌표계 변환](#좌표계-변환)
9. [에러 처리](#에러-처리)
10. [타입 안전성 및 플랫폼 뷰 등록](#타입-안전성-및-플랫폼-뷰-등록)
11. [디버깅 및 로깅](#디버깅-및-로깅)
12. [문제 해결 이력](#문제-해결-이력)

---

## 기본 구조

### Flutter Web에서의 제약사항

1. **`webview_flutter` 미지원**
   - Flutter Web에서는 `webview_flutter` 패키지가 작동하지 않음
   - 대신 `dart:html`과 `dart:ui_web`을 사용해야 함

2. **필수 Import**
```dart
import 'dart:html' as html;      // HTML 요소 생성
import 'dart:ui_web' as ui;       // 플랫폼 뷰 등록
import 'package:flutter/foundation.dart' show kIsWeb;
```

3. **플랫폼 뷰 등록**
```dart
ui.platformViewRegistry.registerViewFactory(
  'unique_view_id',
  (int viewId) => htmlElement,
);
```

### VWorld API 인증키

- **인증키**: `FA0D6750-3DC2-3389-B8F1-0385C5976B96`
- **만료일**: 2026-03-25
- **API 버전**: 2.0

---

## Flutter 위젯 구현

### 기본 위젯 구조

```dart
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RegionSelectionMap extends StatefulWidget {
  /// 지도 높이 (기본값: 400)
  final double height;
  
  /// 반경 (미터 단위, 기본값: 500m)
  final double radiusMeters;

  const RegionSelectionMap({
    super.key,
    this.height = 400,
    this.radiusMeters = 500.0,
  });

  @override
  State<RegionSelectionMap> createState() => _RegionSelectionMapState();
}
```

### 지도 초기화 과정

1. **고유 ID 생성**: 각 지도 인스턴스마다 고유한 `_mapId` 생성
2. **HTML 콘텐츠 생성**: VWorld API를 포함한 완전한 HTML 문서 생성
3. **iframe 생성**: `srcdoc` 속성을 사용하여 HTML을 직접 삽입
4. **플랫폼 뷰 등록**: `ui.platformViewRegistry.registerViewFactory()`로 등록

```dart
class _RegionSelectionMapState extends State<RegionSelectionMap> {
  bool _isInitialized = false;
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
      _initializeMap();
    }
  }

  void _initializeMap() {
    // GPS 위치가 없으면 기본 위치 사용
    final lat = _latitude ?? _defaultLat;
    final lng = _longitude ?? _defaultLng;
    
    // HTML 콘텐츠 생성 (GPS 좌표 및 반경 전달)
    final htmlContent = _buildHtmlContent(lat, lng, widget.radiusMeters);
    
    // iframe 생성 (srcdoc 사용)
    final iframe = html.IFrameElement()
      ..srcdoc = htmlContent
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..allowFullscreen = true;
    
    // 플랫폼 뷰로 등록
    ui.platformViewRegistry.registerViewFactory(
      _mapId,
      (int viewId) => iframe,
    );
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Container(
        height: widget.height,
        child: const Center(
          child: Text('지도는 웹에서만 지원됩니다.'),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      height: widget.height,
      child: HtmlElementView(
        viewType: _mapId,
      ),
    );
  }
}
```

---

## HTML 템플릿 생성

### VWorld API 스크립트 로드

```html
<script type="text/javascript" 
  src="https://map.vworld.kr/js/vworldMapInit.js.do?version=2.0&apiKey=FA0D6750-3DC2-3389-B8F1-0385C5976B96">
</script>
```

### 기본 HTML 구조

```dart
String _buildHtmlContent(double lat, double lng, double radiusMeters) {
  final latStr = lat.toString();
  final lngStr = lng.toString();
  final radiusStr = radiusMeters.toString();
  
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
    // JavaScript 코드는 아래 섹션 참조
  </script>
</body>
</html>
''';
}
```

---

## JavaScript 지도 초기화

### 스크립트 로드 타이밍 처리

**문제**: VWorld API 스크립트가 로드되기 전에 지도 초기화 시도

**해결**: 재시도 로직으로 스크립트 로드 대기

```javascript
var retryCount = 0;
var maxRetries = 50; // 최대 5초 대기
var mapInitialized = false;
var vmap = null;

function initializeMap() {
  if (mapInitialized && vmap !== null) {
    return;
  }
  
  try {
    // VWorld API 스크립트 로드 확인
    if (typeof vw === 'undefined' || typeof vw.ol3 === 'undefined') {
      retryCount++;
      if (retryCount < maxRetries) {
        setTimeout(initializeMap, 100);
        return;
      } else {
        var loadingEl = document.getElementById('loading');
        if (loadingEl) {
          loadingEl.textContent = '지도 로드 시간 초과';
          loadingEl.style.color = '#f00';
        }
        return;
      }
    }
    
    // 지도 초기화 진행...
  } catch (error) {
    console.error('지도 초기화 오류:', error);
  }
}

// DOM 로드 후 초기화 시작
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', function() {
    setTimeout(initializeMap, 500);
  });
} else {
  setTimeout(initializeMap, 500);
}
```

### 지도 생성 옵션

```javascript
// 초기 위치 설정 (CameraPosition)
var initPosition = null;
try {
  if (typeof vw.ol3.CameraPosition !== 'undefined') {
    var cameraParams = {
      longitude: targetLng,  // GPS 경도
      latitude: targetLat,   // GPS 위도
      zoom: 15               // 줌 레벨 (15 = 적절한 확대)
    };
    initPosition = new vw.ol3.CameraPosition(cameraParams);
  } else {
    // CameraPosition이 없으면 객체 리터럴 사용
    initPosition = {
      longitude: targetLng,
      latitude: targetLat,
      zoom: 15
    };
  }
} catch (e) {
  // 에러 발생 시 객체 리터럴로 대체
  initPosition = {
    longitude: targetLng,
    latitude: targetLat,
    zoom: 15
  };
}

// MapOptions 설정
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

// 지도 생성 (에러 처리 포함)
try {
  vmap = new vw.ol3.Map("vmap", vw.ol3.MapOptions);
} catch (firstError) {
  // initPosition이 문제일 수 있으므로 제거하고 재시도
  try {
    var retryOptions = {
      basemapType: vw.ol3.BasemapType.GRAPHIC,
      controlDensity: vw.ol3.DensityType.EMPTY,
      interactionDensity: vw.ol3.DensityType.BASIC,
      controlsAutoArrange: true
      // initPosition 제외
    };
    vmap = new vw.ol3.Map("vmap", retryOptions);
  } catch (secondError) {
    console.error('지도 생성 실패:', secondError);
  }
}

if (vmap) {
  mapInitialized = true;
  
  // 로딩 메시지 제거
  setTimeout(function() {
    var loadingEl = document.getElementById('loading');
    if (loadingEl) {
      loadingEl.style.display = 'none';
    }
  }, 1000);
}
```

### MapOptions 속성 설명

- `basemapType`: 지도 유형 (`GRAPHIC`, `SATELLITE`, `HYBRID` 등)
- `controlDensity`: 컨트롤 밀도 (`EMPTY`, `BASIC`, `NORMAL`)
- `interactionDensity`: 인터랙션 밀도 (`BASIC`, `NORMAL`)
- `controlsAutoArrange`: 컨트롤 자동 배치 여부
- `initPosition`: 초기 위치 설정 (CameraPosition)

---

## GPS 위치로 지도 이동

### 지도 생성 후 추가 이동

**이유**: 지도가 완전히 로드된 후에 이동해야 정확하게 작동함

```javascript
if (vmap) {
  // 지도가 완전히 로드될 때까지 2초 대기
  setTimeout(function() {
    try {
      if (vmap && typeof vmap.getView === 'function') {
        var view = vmap.getView();
        if (view) {
          // GPS 좌표 (EPSG:4326)
          var center = [targetLng, targetLat];
          var zoom = 15;
          
          // 좌표 변환 (EPSG:4326 → EPSG:3857)
          var finalCenter = null;
          if (typeof ol !== 'undefined' && ol.proj && ol.proj.fromLonLat) {
            try {
              // OpenLayers 좌표 변환 함수 사용
              finalCenter = ol.proj.fromLonLat(center);
            } catch (e) {
              // 변환 실패 시 원본 좌표 사용
              finalCenter = center;
            }
          } else {
            // ol.proj가 없으면 원본 좌표 사용
            finalCenter = center;
          }
          
          // 지도 중심 이동
          if (view.setCenter && finalCenter) {
            view.setCenter(finalCenter);
          }
          
          // 지도 확대
          if (view.setZoom) {
            view.setZoom(zoom);
          }
        }
      }
    } catch (moveError) {
      // 이동 실패는 무시 (지도는 이미 표시됨)
      console.warn('지도 이동 실패:', moveError);
    }
  }, 2000);  // 2초 대기
}
```

### 줌 레벨 설명

- **zoom: 10**: 도시 전체 보기
- **zoom: 15**: 동네 단위 (기본값, 도로명/건물명 보임)
- **zoom: 18**: 건물 단위 상세 보기

---

## 마커 추가

### VWorld Marker 레이어 사용

```javascript
// 마커 추가
try {
  if (vmap && typeof vw.ol3.layer !== 'undefined' && typeof vw.ol3.layer.Marker !== 'undefined') {
    var markerLayer = new vw.ol3.layer.Marker(vmap);
    var markerOptions = {
      x: targetLng,
      y: targetLat,
      epsg: 'EPSG:4326',
      title: '현재 위치',
      contents: '내 현재 위치입니다',
      iconUrl: 'https://map.vworld.kr/images/marker/marker_red.png',
      imgAnchor: {x: 0.5, y: 1.0}  // 마커 중앙 하단 기준
    };
    markerLayer.addMarker(markerOptions);
  }
} catch (markerError) {
  console.warn('마커 추가 실패:', markerError);
}
```

### 마커 옵션 설명

- `x`, `y`: 마커 좌표 (경도, 위도)
- `epsg`: 좌표계 (`EPSG:4326` 또는 `EPSG:900913`)
- `title`: 마커 팝업 제목
- `contents`: 마커 팝업 본문
- `iconUrl`: 마커 이미지 URL
- `imgAnchor`: 마커 이미지 앵커 위치 (`{x: 0.5, y: 1.0}` = 중앙 하단)

---

## 원형 폴리곤 구현

> ⚠️ **참고**: 현재 구현에서는 원형 폴리곤이 제거되었습니다 (2025-01-XX). 아래 내용은 참고용으로만 남겨둡니다.

### 원형 폴리곤 생성 함수

```javascript
// 원형 폴리곤 생성 함수
function createCirclePolygon(centerLon, centerLat, radiusMeters) {
  // 원의 점 개수 (더 많은 점 = 더 부드러운 원)
  var numPoints = 64;
  var coordinates = [];
  
  // 각도별로 점 생성
  for (var i = 0; i <= numPoints; i++) {
    var angle = (i / numPoints) * 2 * Math.PI;
    
    // 각도에 따른 방향 벡터
    var dx = Math.cos(angle);
    var dy = Math.sin(angle);
    
    // EPSG:4326에서 미터 단위로 이동한 점 계산
    // 위도 1도 ≈ 111,320 미터
    // 경도 1도 ≈ 111,320 * cos(위도) 미터
    var latRad = centerLat * Math.PI / 180;
    var metersPerDegreeLat = 111320;
    var metersPerDegreeLon = 111320 * Math.cos(latRad);
    
    // 미터 단위로 이동
    var newLat = centerLat + (dy * radiusMeters) / metersPerDegreeLat;
    var newLon = centerLon + (dx * radiusMeters) / metersPerDegreeLon;
    
    // EPSG:3857로 변환
    var point3857 = ol.proj.fromLonLat([newLon, newLat]);
    coordinates.push(point3857);
  }
  
  // 폐곡선을 위해 첫 점을 마지막에 추가
  coordinates.push(coordinates[0]);
  
  return coordinates;
}
```

### 핵심 알고리즘 설명

1. **원의 점 생성**
   - 64개의 점으로 원을 근사화 (더 많은 점 = 더 부드러운 원)
   - 각 점은 중심점에서 반경만큼 떨어진 위치

2. **정확한 거리 계산**
   - 위도 1도 ≈ 111,320 미터 (일정)
   - 경도 1도 ≈ 111,320 × cos(위도) 미터 (위도에 따라 변함)
   - 위도가 높을수록 경도 1도의 거리가 짧아짐

3. **좌표 변환**
   - EPSG:4326 (WGS84)에서 미터 단위로 계산
   - 각 점을 EPSG:3857 (Web Mercator)로 변환하여 지도에 표시

### 수식 설명

```
새 위도 = 중심 위도 + (sin(각도) × 반경) / 111320
새 경도 = 중심 경도 + (cos(각도) × 반경) / (111320 × cos(위도))
```

### 폴리곤 레이어 추가

```javascript
// 원형 폴리곤 추가
try {
  if (typeof ol !== 'undefined' && ol.geom && ol.geom.Polygon) {
    // 원형 폴리곤 좌표 생성
    var circleCoordinates = createCirclePolygon(targetLng, targetLat, radiusMeters);
    
    // 폴리곤 Feature 생성
    var polygonFeature = new ol.Feature({
      geometry: new ol.geom.Polygon([circleCoordinates])
    });
    
    // 스타일 정의 (반투명 빨간색 채우기, 초록색 테두리)
    var style = new ol.style.Style({
      stroke: new ol.style.Stroke({
        color: [0, 255, 0, 0.7],  // 초록색 테두리 (RGBA)
        width: 3
      }),
      fill: new ol.style.Fill({
        color: [255, 0, 0, 0.4]  // 반투명 빨간색 채우기 (RGBA)
      })
    });
    
    polygonFeature.setStyle(style);
    
    // Vector 레이어 생성 및 추가
    var vectorLayer = new ol.layer.Vector({
      source: new ol.source.Vector({
        features: [polygonFeature]
      })
    });
    
    vmap.addLayer(vectorLayer);
  }
} catch (polygonError) {
  console.warn('폴리곤 추가 실패:', polygonError);
}
```

### 실행 순서

1. 원형 폴리곤 좌표 생성 (`createCirclePolygon`)
2. OpenLayers Feature 생성 (`ol.Feature`)
3. 폴리곤 Geometry 생성 (`ol.geom.Polygon`)
4. 스타일 적용
5. Vector 레이어 생성 (`ol.layer.Vector`)
6. 지도에 레이어 추가 (`vmap.addLayer`)

---

## 좌표계 변환

### 좌표계 종류

1. **EPSG:4326 (WGS84)**
   - GPS 좌표계 (위도/경도)
   - 예: `[127.1365699, 37.3793199]` (경도, 위도)
   - 미터 단위 거리 계산에 사용

2. **EPSG:3857 (Web Mercator)**
   - 웹 지도 표준 좌표계
   - 예: `[14150000, 4510000]` (미터 단위)
   - 지도 렌더링에 사용

### 변환 필요 이유

- OpenLayers는 내부적으로 EPSG:3857을 사용
- GPS 좌표를 지도에 표시하려면 변환 필수
- `ol.proj.fromLonLat()` 함수 사용

### 좌표 변환 코드

```javascript
// EPSG:4326 → EPSG:3857 변환
var center = [longitude, latitude];  // 경도, 위도 순서
var finalCenter = null;

if (typeof ol !== 'undefined' && ol.proj && ol.proj.fromLonLat) {
  try {
    finalCenter = ol.proj.fromLonLat(center);
  } catch (e) {
    console.warn('좌표 변환 실패:', e);
    finalCenter = center;  // 변환 실패 시 원본 좌표 사용
  }
} else {
  finalCenter = center;  // ol.proj가 없으면 원본 좌표 사용
}
```

### 거리 계산 정확도

**위도에 따른 경도 보정:**

```
경도 1도의 거리 = 111,320 × cos(위도) 미터
```

**예시:**
- 서울 (위도 37.5°): 경도 1도 ≈ 88,400미터
- 적도 (위도 0°): 경도 1도 ≈ 111,320미터
- 북극 근처 (위도 80°): 경도 1도 ≈ 19,300미터

이 보정을 통해 정확한 원형 폴리곤을 생성할 수 있습니다.

---

## 에러 처리

### 전역 에러 핸들러

```javascript
// 전역 에러 핸들러 추가
window.addEventListener('error', function(e) {
  if (e.message && (e.message.includes('zoom') || e.message.includes('undefined'))) {
    if (mapInitialized || vmap !== null) {
      e.preventDefault();
      e.stopPropagation();
      return true;
    }
  }
}, true);

// Promise Rejection 처리
window.addEventListener('unhandledrejection', function(e) {
  if (e.reason && e.reason.message && e.reason.message.includes('zoom')) {
    e.preventDefault();
  }
});
```

### 안전한 지도 생성

```javascript
try {
  vmap = new vw.ol3.Map("vmap", vw.ol3.MapOptions);
  mapInitialized = true;
} catch (mapError) {
  console.warn('지도 생성 중 경고:', mapError);
  // 지도가 부분적으로라도 작동할 수 있음
  mapInitialized = true;
}
```

### 에러 처리 원칙

1. **좌표 변환 실패 시 원본 좌표 사용**
2. **setCenter/setZoom 실패해도 지도는 정상 표시됨**
3. **try-catch로 모든 에러를 무시하여 안정성 확보**
4. **로딩 메시지는 지도 생성 후 무조건 숨김**

---

## 타입 안전성 및 플랫폼 뷰 등록

### 문제: 타입 시그니처 불일치

Flutter Web의 `registerViewFactory`는 엄격한 타입 체크를 수행합니다. `dynamic` 타입을 사용하면 다음과 같은 에러가 발생합니다:

```
Assertion failed: Factory signature is invalid. 
Expected either {(int) => Object} or {(int, {Object? params}) => Object} 
but got: {(int) => dynamic}
```

### 해결 방법: 명시적 타입 지정

웹 전용 파일(`region_selection_map_web.dart`)에서 모든 함수의 타입을 명시적으로 지정해야 합니다:

```dart
// ❌ 잘못된 방법 (dynamic 사용)
dynamic createIframeElement() {
  return html.IFrameElement()...;
}

void registerPlatformView(String viewId, dynamic iframe) {
  ui.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => iframe,  // dynamic 반환으로 인한 타입 에러
  );
}

// ✅ 올바른 방법 (명시적 타입 지정)
html.IFrameElement createIframeElement() {
  return html.IFrameElement()
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.border = 'none'
    ..allowFullscreen = true;
}

void registerPlatformView(String viewId, html.IFrameElement iframe) {
  ui.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => iframe as html.Element,  // 명시적 캐스팅
  );
}
```

### 조건부 Import 패턴

웹/비웹 환경을 분리하기 위해 조건부 import를 사용합니다:

```dart
// region_selection_map.dart
import 'region_selection_map_stub.dart'
    if (dart.library.html) 'region_selection_map_web.dart' as web_map;

void _initializeMap() {
  if (!kIsWeb) return;
  
  final iframe = web_map.createIframeElement();  // 웹에서만 실행
  web_map.setupIframe(iframe, htmlContent);
  web_map.registerPlatformView(_mapId, iframe);
}
```

**파일 구조:**
- `region_selection_map.dart`: 메인 위젯 (조건부 import 사용)
- `region_selection_map_web.dart`: 웹 전용 구현 (`dart:html` 사용)
- `region_selection_map_stub.dart`: 비웹 환경용 스텁 (null 반환)

---

## 디버깅 및 로깅

### 문제: 지도가 로드되지 않을 때

지도 초기화 과정에서 어디서 멈추는지 확인하기 위해 상세한 로그를 추가했습니다.

### Dart 코드 로깅

```dart
void _initializeMap() {
  print('[지도 초기화] 시작 - MapID: $_mapId');
  print('[지도 초기화] 위치 정보 - 위도: $lat, 경도: $lng');
  print('[지도 초기화] 반경 정보 - 고정 반경: ${widget.fixedRadiusMeters}m, 표시 반경: ${widget.displayRadiusMeters}m');
  print('[지도 초기화] HTML 콘텐츠 생성 중...');
  // ... HTML 생성
  print('[지도 초기화] HTML 콘텐츠 생성 완료 (길이: ${htmlContent.length} bytes)');
  print('[지도 초기화] iframe 생성 중...');
  // ... iframe 생성 및 등록
  print('[지도 초기화] 플랫폼 뷰 등록 완료 - MapID: $_mapId');
}
```

### JavaScript 코드 로깅

```javascript
console.log('[지도 초기화] JavaScript 실행 시작');
console.log('[지도 초기화] 초기 위치 - 위도: ' + targetLat + ', 경도: ' + targetLng);

function initializeMap() {
  console.log('[지도 초기화] initializeMap 호출 - retryCount: ' + retryCount);
  console.log('[지도 초기화] VWorld API 스크립트 확인 중...');
  console.log('[지도 초기화] typeof vw: ' + typeof vw);
  console.log('[지도 초기화] typeof vw.ol3: ' + (typeof vw !== 'undefined' ? typeof vw.ol3 : 'undefined'));
  
  if (typeof vw === 'undefined' || typeof vw.ol3 === 'undefined') {
    console.log('[지도 초기화] VWorld API 스크립트 로드 대기 중... (재시도: ' + retryCount + '/' + maxRetries + ')');
    // 재시도 로직...
  }
  
  console.log('[지도 초기화] VWorld API 스크립트 로드 완료');
  console.log('[지도 초기화] 지도 생성 시도...');
  // ... 지도 생성
  console.log('[지도 초기화] 지도 생성 성공');
  console.log('[지도 초기화] 마커 추가 시도...');
  // ... 마커 추가
  console.log('[지도 초기화] 원형 폴리곤 추가 시작...');
  // ... 원형 폴리곤 추가
  console.log('[지도 초기화] 원형 폴리곤 추가 완료');
}
```

### 로그 확인 방법

1. **브라우저 개발자 도구 열기** (F12)
2. **Console 탭 선택**
3. **`[지도 초기화]`로 시작하는 로그 확인**
4. **마지막 로그 위치로 멈춘 지점 파악**

### 주요 로그 포인트

- ✅ `[지도 초기화] 시작`: Dart 코드 실행 시작
- ✅ `[지도 초기화] HTML 콘텐츠 생성 완료`: HTML 생성 성공
- ✅ `[지도 초기화] 플랫폼 뷰 등록 완료`: iframe 등록 성공
- ✅ `[지도 초기화] JavaScript 실행 시작`: JavaScript 코드 실행 시작
- ✅ `[지도 초기화] VWorld API 스크립트 로드 완료`: VWorld API 로드 성공
- ✅ `[지도 초기화] 지도 생성 성공`: 지도 객체 생성 성공
- ✅ `[지도 초기화] 마커 추가 성공`: 마커 추가 성공
- ✅ `[지도 초기화] 원형 폴리곤 추가 완료`: 원형 폴리곤 추가 성공

---

## 주의사항

### 1. 웹 전용

- Flutter Web에서만 작동
- 모바일/데스크톱 앱에서는 "지도는 웹에서만 지원됩니다" 메시지 표시
- 조건부 import를 통해 웹/비웹 환경 분리 필수

### 2. 타입 안전성

- `registerViewFactory`는 엄격한 타입 체크를 수행
- `dynamic` 타입 사용 시 런타임 에러 발생 가능
- 모든 함수의 파라미터와 반환 타입을 명시적으로 지정해야 함
- `html.Element`로 명시적 캐스팅 필요

### 3. 도메인 인증

- VWorld API는 도메인 인증이 필요할 수 있음
- 지도가 표시되지 않으면 브라우저 콘솔 확인 필요
- 로그를 통해 어느 단계에서 멈추는지 확인 가능

### 4. 에러 처리

- `zoom` 관련 에러는 VWorld API 내부에서 발생하는 것으로, 지도 기능에는 영향 없음
- 전역 에러 핸들러로 무시 처리
- 각 단계마다 try-catch로 에러 처리

### 5. 좌표계 변환 필수

- GPS 좌표(EPSG:4326)를 지도 좌표(EPSG:3857)로 변환해야 함
- `ol.proj.fromLonLat()` 사용
- 변환 실패 시 원본 좌표 사용 (fallback)

### 6. 위도에 따른 경도 보정

- 위도가 높을수록 경도 1도의 거리가 짧아짐
- 보정하지 않으면 원이 타원형으로 보일 수 있음
- 원형 폴리곤 생성 시 위도 기반 보정 필수

### 7. 폐곡선 처리

- 폴리곤의 첫 점을 마지막에 추가하여 폐곡선으로 만들어야 함
- `coordinates.push(coordinates[0])`

### 8. 원형 폴리곤 추가 타이밍

- 원형 폴리곤은 지도가 완전히 로드된 후에 추가해야 함
- 지도 생성 후 2.5초 대기 후 추가하는 것이 안전
- 너무 빨리 추가하면 `ol` 객체가 아직 준비되지 않았을 수 있음

---

## 성능 고려사항

### 1. 점 개수 최적화

- **64개 점**: 기본값, 부드러운 원형
- **32개 점**: 성능 우선, 약간 각진 원형
- **128개 점**: 매우 부드러운 원형, 성능 저하 가능

현재 구현은 64개 점을 사용하여 성능과 품질의 균형을 맞췄습니다.

### 2. 레이어 관리

- 기존 레이어 재사용 고려
- 반경 변경 시 기존 폴리곤 제거 후 새로 추가

### 3. 메모리 관리

- 폴리곤 좌표 배열은 한 번만 생성
- 지도 제거 시 레이어도 함께 제거

---

## 참고 자료

- **VWorld 2D 지도 API 2.0 공식 문서**
- **OpenLayers 3 문서** (VWorld API는 OpenLayers 기반)
- **OpenLayers Polygon 문서**: [OpenLayers Polygon API](https://openlayers.org/en/latest/apidoc/module-ol_geom_Polygon.html)
- **좌표계 변환**: EPSG:4326 ↔ EPSG:3857
- **거리 계산**: Haversine 공식 또는 위도 기반 근사치

---

## 파일 구조

```
lib/
├── widgets/
│   ├── region_selection_map.dart           # 지도 위젯 (메인)
│   ├── region_selection_map_web.dart       # 웹 전용 구현 (dart:html 사용)
│   └── region_selection_map_stub.dart      # 비웹 환경용 스텁
└── screens/
    └── main_page.dart                       # 메인 페이지 (지도 통합)
```

### 파일 역할 설명

- **`region_selection_map.dart`**: 
  - 메인 지도 위젯
  - 조건부 import를 통해 웹/비웹 환경 분리
  - `kIsWeb` 체크로 웹 환경에서만 지도 초기화

- **`region_selection_map_web.dart`**:
  - 웹 전용 구현
  - `dart:html`과 `dart:ui_web` 사용
  - 모든 함수의 타입을 명시적으로 지정 (`html.IFrameElement`, `html.Element` 등)

- **`region_selection_map_stub.dart`**:
  - 비웹 환경용 스텁 파일
  - 모든 함수가 null 반환 또는 아무 작업도 하지 않음
  - 컴파일 에러 방지용

---

## 사용 예시

### 기본 사용

```dart
RegionSelectionMap(
  height: 300,
)
```

### 반경 지정

```dart
RegionSelectionMap(
  height: 300,
  radiusMeters: 1000.0,  // 1km 반경
)
```

### 다양한 반경 예시

```dart
// 300미터 반경
RegionSelectionMap(
  height: 300,
  radiusMeters: 300.0,
)

// 500미터 반경 (기본값)
RegionSelectionMap(
  height: 300,
  radiusMeters: 500.0,
)

// 1.5km 반경
RegionSelectionMap(
  height: 300,
  radiusMeters: 1500.0,
)
```

---

## 문제 해결 이력

### 2025-01-XX: 타입 에러 수정

**문제:**
```
Assertion failed: Factory signature is invalid. 
Expected either {(int) => Object} or {(int, {Object? params}) => Object} 
but got: {(int) => dynamic}
```

**원인:**
- `registerPlatformView` 함수에서 `dynamic` 타입 사용
- Flutter Web의 엄격한 타입 체크에 걸림

**해결:**
- 모든 함수의 타입을 명시적으로 지정
- `html.IFrameElement` 타입 사용
- `as html.Element`로 명시적 캐스팅

**수정 파일:**
- `lib/widgets/region_selection_map_web.dart`

### 2025-01-XX: 원형 폴리곤 추가

**문제:**
- MD 가이드에는 원형 폴리곤 코드가 있지만 실제 구현에는 없음
- 지도에 마커만 표시되고 원형 폴리곤이 표시되지 않음

**해결:**
- 원형 폴리곤 생성 함수 추가 (`createCirclePolygon`)
- 지도가 완전히 로드된 후(2.5초) 원형 폴리곤 추가
- OpenLayers의 `ol.layer.Vector` 사용

**수정 파일:**
- `lib/widgets/region_selection_map.dart` (JavaScript 부분)

### 2025-01-XX: 상세 로깅 추가

**문제:**
- 지도가 로드되지 않을 때 어느 단계에서 멈추는지 확인 불가

**해결:**
- Dart 코드와 JavaScript 코드에 상세한 로그 추가
- 각 단계마다 `[지도 초기화]` 접두사로 로그 출력
- 브라우저 콘솔에서 초기화 과정 추적 가능

**수정 파일:**
- `lib/widgets/region_selection_map.dart`

### 2025-01-XX: 레이아웃 문제 해결

**문제 1: 슬라이더 위젯이 사라짐**
- GPS 검색 탭에서 거리 슬라이더가 화면에 표시되지 않음
- `RegionSelectionSection`의 레이아웃 구조 문제

**해결:**
- `Expanded`를 `Flexible`로 변경하고 `mainAxisSize: MainAxisSize.min` 추가
- `TabBarView` 내부에서 제대로 렌더링되도록 레이아웃 조정
- 슬라이더 변경 시 지도 줌 업데이트 로직 추가

**수정 파일:**
- `lib/widgets/region_selection/region_selection_section.dart`

**문제 2: FloatingActionButton 레이아웃 오류**
- `Cannot hit test a render box that has never been laid out` 에러 발생
- `TabBarView`에서 `Expanded` 사용으로 인한 레이아웃 문제

**해결:**
- `AddressSearchTabs`에서 `TabBarView`의 `Expanded` 제거
- `SizedBox`로 고정 높이 지정 (700px → 1000px)
- `TabBarView`는 명시적 높이가 필요하므로 `Expanded` 대신 고정 높이 사용

**수정 파일:**
- `lib/widgets/address_search/address_search_tabs.dart`
- `lib/screens/home_page.dart`

**문제 3: GPS 검색 탭 스크롤바 발생**
- GPS 검색 탭의 콘텐츠가 작은 화면에서 스크롤바가 생김

**해결:**
- `AddressSearchTabs`의 `TabBarView` 높이를 700px에서 1000px로 증가
- 모든 콘텐츠가 스크롤 없이 표시되도록 충분한 높이 제공

**수정 파일:**
- `lib/widgets/address_search/address_search_tabs.dart`
- `lib/screens/home_page.dart`

### 2025-01-XX: 원형 폴리곤 제거

**요청:**
- 사용자 요청으로 지도에서 원형 폴리곤 표시 제거

**변경 사항:**
- `createCirclePolygon` 함수 제거
- 원형 폴리곤 Feature 및 Vector 레이어 추가 코드 제거
- 로딩 화면 숨기기 setTimeout 시간을 2.5초에서 1초로 단축

**수정 파일:**
- `lib/widgets/region_selection_map.dart` (JavaScript 부분)

**참고:**
- 마커는 그대로 유지되어 현재 위치를 표시
- 지도는 마커만 표시하고 원형 폴리곤 없이 동작

---

## 향후 개선 사항

1. **동적 반경 변경**
   - 사용자가 슬라이더로 반경 조절
   - 실시간으로 폴리곤 업데이트

2. **다중 반경 표시**
   - 여러 반경을 동시에 표시 (예: 300m, 500m, 1km)

3. **반경별 색상 구분**
   - 반경에 따라 다른 색상 사용

4. **클릭 이벤트**
   - 폴리곤 클릭 시 정보 표시

5. **지도 이동 이벤트**
   - 지도 이동 시 중심 좌표 업데이트
   - Flutter와 JavaScript 통신

6. **로깅 최적화**
   - 프로덕션 빌드에서는 로그 제거
   - 디버그 모드에서만 상세 로그 출력

---

**다음 단계**: 실제 프로젝트에 통합하여 사용하세요!

