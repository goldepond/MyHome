# 주소검색 → 공인중개사 검색 구현 가이드

> 작성일: 2025-01-27  
> 파일: `_AI_Doc/ADDRESS_TO_BROKER_SEARCH_IMPLEMENTATION.md`  
> 상태: ✅ 활성화됨 (주소 검색 탭 사용)

---

## 📋 목차

1. [개요](#개요)
2. [전체 플로우](#전체-플로우)
3. [주소검색 구현](#주소검색-구현)
4. [좌표 변환 구현](#좌표-변환-구현)
5. [공인중개사 검색 구현](#공인중개사-검색-구현)
6. [공공데이터포털 API 구현 가이드](#공공데이터포털-api-구현-가이드)
7. [활성화 방법](#활성화-방법)
8. [데이터 모델](#데이터-모델)
9. [API 연동 상세](#api-연동-상세)
10. [에러 처리](#에러-처리)
11. [성능 최적화](#성능-최적화)
12. [주의사항](#주의사항)

---

## 개요

이 문서는 **주소검색부터 공인중개사 검색까지의 전체 로직**과 **상세한 구현 방법**을 설명합니다.

### 주요 기능

1. **주소검색**: 2가지 방법 제공 (주소 검색 탭에서 제공)
   - **GPS 기반 지도 검색**: GPS 위치 자동 감지 및 지도에서 위치 선택 (`GpsBasedSearchTab`)
   - **주소 입력 검색**: 텍스트 입력 기반 주소 검색 (`AddressInputTab`)
   
   **현재 구현 상태**: ✅
   - 히어로 배너의 검색창은 제거됨 (`showSearchBar: false`)
   - 주소 검색은 `AddressSearchTabs` 위젯을 통해 제공됨
   - GPS 기반 검색과 주소 입력 검색이 탭으로 분리되어 있음
2. **좌표 변환**: VWorld Geocoder API를 통한 주소 ↔ 좌표 변환
3. **공인중개사 검색**: 
   - VWorld WFS API를 통한 주변 공인중개사 검색
   - 공공데이터포털 전국공인중개사사무소 표준데이터 API 검색
4. **데이터 보강**: 
   - 서울시 공개 API를 통한 추가 정보 보강
   - 공공데이터 포털 전국공인중개사사무소표준데이터를 통한 등록번호 기반 정보 보강
   - Firestore 데이터 보강

---

## 전체 플로우

```
사용자 입력
    ↓
[1단계] 주소검색
    ├─ 방법 1: GPS 기반 지도 검색 (RegionSelectionMap)
    │   ├─ GPS 위치 자동 감지
    │   ├─ 지도에서 위치 선택
    │   └─ 좌표 → 주소 변환 (VWorld Reverse Geocoder)
    │
    └─ 방법 2: 주소 입력 검색 (AddressInputTab)
        ├─ 주소 검색 탭의 "주소 입력 검색" 탭에서 검색
        ├─ 사용자가 검색창에 주소 입력
        ├─ 디바운싱 적용 (500ms)
        ├─ 도로명주소 API 호출
        ├─ 검색 결과 목록 표시
        └─ 지도 및 반경 슬라이더 제공
    ↓
주소 선택
    ↓
[2단계] 좌표 변환 (VWorldService)
    ├─ 방법 1: GPS 기반인 경우 좌표 이미 보유
    └─ 방법 2: 주소 검색인 경우 주소 → 좌표 변환
    ↓
좌표 획득 (위도, 경도)
    ↓
[3단계] 공인중개사 검색 (BrokerService)
    ├─ VWorld WFS API 조회
    ├─ 공공데이터포털 전국공인중개사사무소 API 조회
    ├─ 반경 확장 재시도 (필요시)
    ├─ 서울시 글로벌공인중개사무소 API 보강
    ├─ 서울시 부동산 중개업소 API 보강
    ├─ 공공데이터 포털 전국공인중개사사무소표준데이터 보강 (비동기, 백그라운드)
    └─ 결과 병합 및 중복 제거
    ↓
[4단계] Firestore 데이터 보강
    ↓
공인중개사 목록 표시 (BrokerListPage)
```

### 플로우 상세 설명

#### 1단계: 주소검색

**방법 1: GPS 기반 지도 검색**
- GPS 위치 자동 감지 (`RegionSelectionMap`)
- 지도에서 위치 선택 및 반경 설정 (슬라이더: 300m, 500m, 1km, 1.5km)
- VWorld Reverse Geocoder API로 좌표 → 주소 변환
- 선택한 반경 정보가 공인중개사 검색에 반영됨
- 참고 문서: `_AI_Doc/REGION_SELECTION_MAP_IMPLEMENTATION.md`

**방법 2: 주소 입력 검색** (AddressInputTab)
- 주소 검색 탭의 "주소 입력 검색" 탭에서 검색
- 사용자가 검색창에 주소 입력
- 디바운싱 적용 (500ms)
- 도로명주소 API 호출
- 검색 결과 목록 표시
- **지도 통합**: 선택한 주소 위치로 지도 이동 (`AddressMapWidget`)
- **반경 설정**: 슬라이더로 검색 반경 설정 (300m, 500m, 1km, 1.5km)
- 선택한 반경 정보가 공인중개사 검색에 반영됨

#### 2단계: 좌표 변환
- **방법 1 (GPS 기반)**: 좌표를 이미 보유하고 있으므로 변환 불필요
- **방법 2 (주소 검색)**: 사용자가 주소 선택 후 VWorld Geocoder API 호출하여 주소 → 좌표 변환 (위도, 경도)

#### 3단계: 공인중개사 검색
- 좌표 기반 반경 검색
  - **사용자가 선택한 반경 사용** (GPS/주소 입력 탭에서 설정한 값)
  - 기본값: 1km (반경이 설정되지 않은 경우)
  - 선택 가능한 반경: 300m, 500m, 1km, 1.5km
  - VWorld WFS API 조회
  - 공공데이터포털 전국공인중개사사무소 API 조회
- 결과 병합 및 중복 제거 (등록번호 기준)
- 결과 없으면 반경 확장 (최대 10km)
- 서울 지역인 경우 서울시 API로 보강
- 공공데이터 포털 전국공인중개사사무소표준데이터로 추가 정보 보강 (비동기, 백그라운드 처리)

#### 4단계: Firestore 보강
- Firestore에서 추가 정보 조회
- 소개글, 전화번호 등 보강

---

## 주소검색 구현

### 개요

주소검색은 **2가지 방법**으로 구현됩니다:

1. **GPS 기반 지도 검색** (`RegionSelectionMap`)
   - GPS 위치를 자동으로 감지하고 지도에서 위치를 선택
   - VWorld Reverse Geocoder API로 좌표 → 주소 변환
   - 상세 구현: `_AI_Doc/REGION_SELECTION_MAP_IMPLEMENTATION.md` 참고

2. **주소 입력 검색** (`AddressInputTab`)
   - 주소 검색 탭의 "주소 입력 검색" 탭에서 제공
   - 사용자가 검색창에 주소를 직접 입력
   - 도로명주소 API를 통한 텍스트 기반 검색
   - 지도 및 반경 슬라이더 통합
   - 아래 섹션에서 상세 설명

---

### 방법 1: GPS 기반 지도 검색

**파일 위치:**
- `lib/widgets/region_selection_map.dart`
- `lib/widgets/region_selection/region_selection_section.dart`
- `lib/api_request/vworld_service.dart` (Reverse Geocoder)

**주요 기능:**
- GPS 위치 자동 감지 및 지도 표시
- 지도에서 위치 선택 및 반경 설정 (슬라이더: 300m, 500m, 1km, 1.5km)
- VWorld Reverse Geocoder API로 좌표 → 주소 변환
- "내 위치로 돌아가기" 기능
- 선택한 반경 정보가 공인중개사 검색에 자동 반영

**구현 상세:**
- GPS 위치 감지: `Geolocator.getCurrentLocation()`
- 지도 표시: VWorld OpenLayers 3.10.1 API
- 좌표 → 주소 변환: `VWorldService.reverseGeocode()`
- 상세 내용은 `_AI_Doc/REGION_SELECTION_MAP_IMPLEMENTATION.md` 참고

---

### 방법 2: 주소 입력 검색

**파일 위치:**
- `lib/api_request/address_service.dart`
- `lib/widgets/address_search/address_input_tab.dart` (주소 입력 검색 탭)
- `lib/widgets/address_search/address_search_tabs.dart` (탭 컨테이너)
- `lib/screens/home_page.dart` (UI 통합)

**핵심 클래스: AddressService**

```dart
class AddressService {
  Future<AddressSearchResult> searchRoadAddress(String keyword, {int page = 1})
}
```

**주요 기능:**
- 텍스트 기반 주소 검색 (도로명주소 API)
- 검색 결과 목록 표시
- **지도 통합**: 선택한 주소 위치로 지도 이동
- **반경 설정**: 슬라이더로 검색 반경 설정 (300m, 500m, 1km, 1.5km)
- 선택한 반경 정보가 공인중개사 검색에 자동 반영

### 구현 상세

#### 1. 검색 키워드 검증

```dart
// 최소 2글자 이상 검증
if (trimmedKeyword.length < 2) {
  return AddressSearchResult(
    fullData: [],
    addresses: [],
    totalCount: 0,
    errorMessage: '도로명, 건물명, 지번 등을 최소 2글자 이상 입력해 주세요.',
  );
}

// 비정상적인 키워드 필터링 (컴파일 에러 메시지 등)
if (trimmedKeyword.contains('error:') || 
    trimmedKeyword.contains('warning:') ||
    trimmedKeyword.length > 500) {
  return AddressSearchResult(
    fullData: [],
    addresses: [],
    totalCount: 0,
    errorMessage: '올바른 주소를 입력해주세요.',
  );
}
```

#### 2. API 요청 구성

```dart
final uri = Uri.parse(
  '${ApiConstants.baseJusoUrl}'
  '?currentPage=$page'
  '&countPerPage=${ApiConstants.pageSize}'
  '&keyword=${Uri.encodeComponent(trimmedKeyword)}'
  '&confmKey=$apiKey'
  '&resultType=json',
);

// 프록시를 통한 요청 (CORS 우회)
final proxyUri = Uri.parse(
  '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
);
```

**주요 파라미터:**
- `currentPage`: 현재 페이지 번호
- `countPerPage`: 페이지당 결과 수 (기본 20개)
- `keyword`: 검색 키워드 (URL 인코딩)
- `confmKey`: API 인증 키
- `resultType`: 응답 형식 (json)

#### 3. 응답 처리

```dart
if (response.statusCode == 200) {
  final data = json.decode(response.body);
  final results = data['results'] as Map<String, dynamic>;
  final common = results['common'] as Map<String, dynamic>;
  
  // 에러 코드 확인
  final errorCode = common['errorCode'];
  if (errorCode != '0') {
    return AddressSearchResult(
      errorMessage: 'API 오류: ${common['errorMessage']}',
    );
  }
  
  // 주소 목록 추출
  final juso = results['juso'] as List;
  final addressList = juso.map((e) {
    final road = e['roadAddr']?.toString() ?? '';
    final jibun = e['jibunAddr']?.toString() ?? '';
    if (road.isEmpty) return jibun;
    if (jibun.isEmpty) return road;
    return '$road\n지번 $jibun';
  }).toList();
  
  return AddressSearchResult(
    fullData: convertedFullData,
    addresses: addressList,
    totalCount: total,
  );
}
```

#### 4. 에러 처리

- **타임아웃**: 30초 초과 시 에러 반환
- **네트워크 오류**: 연결 실패 시 에러 메시지
- **서버 오류**: 5xx 에러 처리
- **응답 형식 오류**: JSON 파싱 실패 처리

### UI 통합 (home_page.dart)

#### 현재 구현 상태 ✅

**히어로 배너 검색창 제거됨:**
- 히어로 배너의 검색창은 제거되었고 (`showSearchBar: false`), 타이틀과 설명만 표시됨
- 주소 검색은 `AddressSearchTabs` 위젯을 통해 제공됨

**주소 검색 탭 사용:**
```dart
// 상단 타이틀 섹션
const HeroBanner(
  showSearchBar: false,  // ✅ 검색창 제거됨
),
const SizedBox(height: AppSpacing.lg), // 24px - 주요 섹션 전환

// 주소 검색 탭 (반응형 높이)
ConstrainedBox(
  constraints: BoxConstraints(
    minHeight: isSmallScreen ? 1000 : 1000,
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: AddressSearchTabs(
      onAddressSelected: (result) async {
        // 주소 선택 처리
        final cleanAddress = result.address;
        
        // 상태 업데이트
        setState(() {
          if (result.fullAddrAPIData != null) {
            selectedFullAddrAPIData = result.fullAddrAPIData!;
          }
          selectedRoadAddress = cleanAddress;
          selectedFullAddress = cleanAddress;
          selectedRadiusMeters = result.radiusMeters;
        });
        
        // 좌표 조회 (GPS 기반 검색의 경우 이미 좌표 보유)
        if (result.latitude != null && result.longitude != null) {
          // GPS 기반 검색: 좌표 이미 있음
          setState(() {
            vworldCoordinates = {
              'x': result.longitude.toString(),
              'y': result.latitude.toString(),
            };
          });
        } else {
          // 주소 입력 검색: 좌표 조회 필요
          await _loadVWorldData(
            cleanAddress,
            fullAddrAPIData: result.fullAddrAPIData,
          );
        }
      },
    ),
  ),
),
```

**주소 입력 검색 탭 내부 구현:**
- `AddressInputTab`에서 자체적으로 디바운싱 및 검색 로직 관리
- 검색 결과는 `RoadAddressList` 위젯으로 표시
- 지도 및 반경 슬라이더 통합 제공

### 주소 검색 탭 높이 측정 및 자동 확장

**파일 위치:**
- `lib/widgets/address_search/address_search_tabs.dart`

**구현 개요:**
- GPS 탭과 주소 입력 탭의 콘텐츠 높이를 동적으로 측정하여 탭 컨테이너 높이를 자동으로 조정
- 스크롤 없이 콘텐츠에 맞게 높이가 자동 확장되도록 구현
- overflow 에러 방지를 위한 여유 공간 설정

**핵심 기능:**

1. **높이 측정 로직**
   - `IntrinsicHeight`를 사용하여 실제 콘텐츠 높이 측정
   - GPS 탭과 주소 입력 탭 중 더 높은 높이 사용
   - 여러 번 측정하여 정확도 향상 (300ms, 600ms 지연 재측정)

2. **가변 높이 자동 확장**
   - maxHeight 제한 제거로 측정된 높이를 그대로 사용
   - 스크롤 없이 콘텐츠에 맞게 높이 자동 확장
   - 최소 높이만 보장 (500px)

3. **여유 공간 설정**
   - GPS 탭: 80px 여유 공간 (측정 오차 및 동적 콘텐츠 대응)
   - 주소 입력 탭: 40px 여유 공간
   - overflow 에러 방지를 위한 최소한의 여유 공간

4. **자동 높이 재측정**
   - 콘텐츠 변경 시 자동 높이 재측정 (`onContentChanged` 콜백)
   - 주소 선택 후 높이 재측정
   - 탭 전환 시 높이 재측정

**구현 코드:**
```dart
// 높이 측정 수행
void _performHeightMeasurement() {
  // IntrinsicHeight를 사용하여 실제 콘텐츠 높이 측정
  final gpsContext = _gpsTabContentKey.currentContext;
  if (gpsContext != null) {
    final renderBox = gpsContext.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      gpsHeight = renderBox.size.height;
    }
  }
  
  // 두 탭 중 더 높은 높이 사용 + 여유 공간 추가
  final padding = isGpsTab ? 80.0 : 40.0;
  final heightWithPadding = maxHeight + padding;
  
  setState(() {
    _tabHeight = heightWithPadding;
  });
}
```

**주의사항:**
- 높이 측정은 여러 번 수행되어 정확도 향상 (300ms, 600ms 지연 재측정)
- 동적 콘텐츠 변경(주소 로딩, 에러 메시지 등)을 고려하여 충분한 여유 공간 설정
- 스크롤 없이 높이가 자동 확장되므로 여유 공간이 중요

---

## 좌표 변환 구현

### 파일 위치
- `lib/api_request/vworld_service.dart`
- `lib/screens/home_page.dart` (`_loadVWorldData` 메서드)

### 핵심 메서드: VWorldService.getLandInfoFromAddress

```dart
static Future<Map<String, dynamic>?> getLandInfoFromAddress(
  String address, {
  Map<String, String>? fullAddrData,
})
```

### 구현 상세

#### 1. 건물관리번호 우선 시도

```dart
// 건물관리번호(bdMgtSn)가 있는 경우 우선 시도
final buildingId = fullAddrData?['bdMgtSn']?.trim();
if (buildingId != null && buildingId.isNotEmpty) {
  final baseAddress = fullAddrData?['roadAddrPart1'] ??
      fullAddrData?['roadAddr'] ??
      address;
  final inferredType = (fullAddrData?['roadAddrPart1']?.trim().isNotEmpty ?? false)
      ? 'road'
      : 'parcel';
  
  final buildingResult = await _requestGeocoderByBuildingId(
    buildingId,
    baseAddress,
    inferredType,
  );
  
  if (buildingResult != null) {
    return buildingResult;
  }
}
```

#### 2. 주소 후보 생성 및 시도

```dart
// 주소 후보 생성 (ROAD → PARCEL 순서)
final candidates = _buildAddressCandidates(address, fullAddrData);

for (final candidate in candidates.take(3)) {
  if (candidate.trim().isEmpty) continue;
  
  // ROAD 타입 시도
  final roadResult = await _requestGeocoder(candidate, type: 'ROAD');
  if (roadResult != null && _isReliableGeocode(roadResult, candidate)) {
    return roadResult;
  }
  
  // PARCEL 타입 시도
  final parcelResult = await _requestGeocoder(candidate, type: 'PARCEL');
  if (parcelResult != null && _isReliableGeocode(parcelResult, candidate)) {
    return parcelResult;
  }
}
```

#### 3. Geocoder API 요청

```dart
static Future<Map<String, dynamic>?> _requestGeocoder(
  String address,
  {required String type}
) async {
  final uri = Uri.parse(VWorldApiConstants.geocoderBaseUrl).replace(queryParameters: {
    'service': 'address',
    'request': 'getCoord',
    'version': '2.0',
    'crs': VWorldApiConstants.srsName,  // EPSG:4326
    'address': address,
    'type': type,  // 'ROAD' or 'PARCEL'
    'simple': 'true',
    'format': 'json',
    'key': VWorldApiConstants.geocoderApiKey,
  });
  
  // 프록시를 통한 요청
  final proxyUri = Uri.parse(VWorldApiConstants.vworldProxyUrl).replace(queryParameters: {
    'url': uri.toString(),
  });
  
  final response = await http.get(proxyUri).timeout(
    const Duration(seconds: ApiConstants.requestTimeoutSeconds),
  );
  
  if (response.statusCode == 200) {
    final data = json.decode(utf8.decode(response.bodyBytes));
    final responseData = data['response'];
    
    if (responseData['status'] == 'OK') {
      final result = responseData['result'];
      final point = result['point'];
      
      return {
        'x': point['x'],  // 경도
        'y': point['y'],  // 위도
        'level': result['level'],
        'text': result['text'],
      };
    }
  }
  
  return null;
}
```

#### 4. 좌표 신뢰도 검증

```dart
static bool _isReliableGeocode(Map<String, dynamic> result, String address) {
  final level = result['level']?.toString() ?? '';
  
  // 레벨이 너무 낮으면 신뢰할 수 없음
  // '8' (건물), '6' (도로명), '4' (법정동) 등
  final levelInt = int.tryParse(level) ?? 0;
  if (levelInt < 4) {
    return false;
  }
  
  return true;
}
```

### UI 통합

```dart
Future<void> _loadVWorldData(String address, {Map<String, String>? fullAddrAPIData}) async {
  setState(() {
    isVWorldLoading = true;
    vworldError = null;
    vworldCoordinates = null;
  });
  
  try {
    final result = await VWorldService.getLandInfoFromAddress(
      address,
      fullAddrData: fullAddrAPIData,
    );
    
    if (mounted) {
      if (result != null) {
        setState(() {
          vworldCoordinates = result['coordinates'];
          isVWorldLoading = false;
        });
      } else {
        setState(() {
          isVWorldLoading = false;
          vworldError = '선택한 주소에서 정확한 좌표를 찾지 못했습니다.';
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        isVWorldLoading = false;
        vworldError = 'VWorld API 오류: ${e.toString()}';
      });
    }
  }
}
```

---

## 공인중개사 검색 구현

### 파일 위치
- `lib/api_request/broker_service.dart`
- `lib/api_request/public_data_broker_service.dart` (공공데이터포털 API)
- `lib/api_request/broker_verification_service.dart` (공공데이터 포털 전국공인중개사사무소표준데이터 보강)
- `lib/screens/broker_list_page.dart`

### 핵심 메서드: BrokerService.searchNearbyBrokers

```dart
static Future<BrokerSearchResult> searchNearbyBrokers({
  required double latitude,
  required double longitude,
  int radiusMeters = 1000,
  bool shouldAutoRetry = true,
  bool includePublicData = true, // 공공데이터포털 API 포함 여부
})
```

### 구현 상세

#### 1단계: VWorld WFS API 조회

```dart
static Future<List<Broker>> _searchFromVWorld({
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) async {
  // BBOX 생성 (EPSG:4326 기준)
  final bbox = _generateEpsg4326Bbox(latitude, longitude, radiusMeters);
  
  final uri = Uri.parse(VWorldApiConstants.brokerQueryBaseUrl).replace(queryParameters: {
    'key': VWorldApiConstants.apiKey,
    'typename': VWorldApiConstants.brokerQueryTypeName,
    'bbox': bbox,  // 'ymin,xmin,ymax,xmax,EPSG:4326'
    'resultType': 'results',
    'srsName': VWorldApiConstants.srsName,  // EPSG:4326
    'output': 'application/json',
    'maxFeatures': VWorldApiConstants.brokerMaxFeatures.toString(),
  });
  
  // 프록시를 통한 요청
  final proxyUri = Uri.parse(
    '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
  );
  
  final response = await http.get(proxyUri).timeout(
    const Duration(seconds: ApiConstants.requestTimeoutSeconds),
  );
  
  if (response.statusCode == 200) {
    final jsonText = utf8.decode(response.bodyBytes);
    final brokers = _parseJSON(jsonText, latitude, longitude);
    return brokers;
  }
  
  return [];
}
```

#### BBOX 생성 로직

```dart
static String _generateEpsg4326Bbox(double lat, double lon, int radiusMeters) {
  // 위도 1도 ≈ 111km
  final latDelta = radiusMeters / 111000.0;
  // 경도 1도 ≈ 111km * cos(위도)
  final lonDelta = radiusMeters / (111000.0 * cos(lat * pi / 180));
  
  final ymin = lat - latDelta;
  final xmin = lon - lonDelta;
  final ymax = lat + latDelta;
  final xmax = lon + lonDelta;
  
  return '$ymin,$xmin,$ymax,$xmax,EPSG:4326';
}
```

#### JSON 파싱

```dart
static List<Broker> _parseJSON(String jsonText, double baseLat, double baseLon) {
  final brokers = <Broker>[];
  
  try {
    final data = json.decode(jsonText);
    final List<dynamic> features = data['features'] ?? [];
    
    for (final featureRaw in features) {
      final feature = featureRaw as Map<String, dynamic>;
      final properties = feature['properties'] as Map<String, dynamic>? ?? {};
      
      // 필드 추출
      final name = properties['bsnm_cmpnm']?.toString() ?? '';
      final roadAddr = properties['rdnmadr']?.toString() ?? '';
      final jibunAddr = properties['mnnmadr']?.toString() ?? '';
      final registNo = properties['brkpg_regist_no']?.toString() ?? '';
      
      // 좌표 추출 (geometry.coordinates에서 [lon, lat])
      final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
      final coordinates = geometry['coordinates'] as List?;
      
      double? brokerLat;
      double? brokerLon;
      double? distance;
      
      if (coordinates != null && coordinates.length >= 2) {
        brokerLon = double.parse(coordinates[0].toString());
        brokerLat = double.parse(coordinates[1].toString());
        distance = _calculateHaversineDistance(baseLat, baseLon, brokerLat, brokerLon);
      }
      
      brokers.add(Broker(
        name: name,
        roadAddress: roadAddr,
        jibunAddress: jibunAddr,
        registrationNumber: registNo,
        latitude: brokerLat,
        longitude: brokerLon,
        distance: distance,
      ));
    }
    
    // 거리순 정렬
    brokers.sort((a, b) {
      if (a.distance == null) return 1;
      if (b.distance == null) return -1;
      return a.distance!.compareTo(b.distance!);
    });
  } catch (e) {
    // 파싱 실패 시 빈 리스트 반환
  }
  
  return brokers;
}
```

#### 거리 계산 (Haversine 공식)

```dart
static double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
  // EPSG:5186 (TM 좌표)인 경우 유클리드 거리
  if (lon1 > 1000 && lon2 > 1000) {
    final dx = lon2 - lon1;
    final dy = lat2 - lat1;
    return sqrt(dx * dx + dy * dy);
  }
  
  // WGS84 좌표인 경우 Haversine 공식
  const R = 6371000.0; // 지구 반지름 (미터)
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  
  final a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
  
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}
```

#### 2단계: 반경 확장 재시도

```dart
static Future<BrokerSearchResult> _retryWithExpandedRadius({
  required double latitude,
  required double longitude,
  required int initialRadius,
}) async {
  const int maxRadius = 10000;  // 최대 10km
  const int retrySteps = 3;
  final int increment = (maxRadius - initialRadius) ~/ retrySteps;
  
  for (int attempt = 0; attempt < retrySteps; attempt++) {
    final int searchRadius = attempt < retrySteps - 1
        ? initialRadius + (attempt + 1) * increment
        : maxRadius;
    
    final brokers = await _searchFromVWorld(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: searchRadius,
    );
    
    if (brokers.isNotEmpty) {
      return BrokerSearchResult(
        brokers: brokers,
        radiusMetersUsed: searchRadius,
        wasExpanded: true,
      );
    }
  }
  
  return BrokerSearchResult(
    brokers: const [],
    radiusMetersUsed: maxRadius,
    wasExpanded: true,
  );
}
```

#### 3단계: 서울시 API 보강

##### 3-1. 글로벌공인중개사무소 정보 보강

```dart
static Future<List<Broker>> _enhanceWithSeoulGlobalBrokerData(List<Broker> brokers) async {
  if (brokers.isEmpty) return brokers;
  
  // 서울 지역인지 확인
  final seoulBrokers = brokers.where((b) {
    final address = b.roadAddress.isNotEmpty ? b.roadAddress : b.jibunAddress;
    return address.contains('서울') || b.sggCode?.startsWith('11') == true;
  }).toList();
  
  if (seoulBrokers.isEmpty) {
    return brokers;
  }
  
  // 서울시 글로벌공인중개사무소 데이터 조회
  final globalBrokerData = await _fetchSeoulGlobalBrokerData();
  
  if (globalBrokerData.isEmpty) {
    return brokers;
  }
  
  // 매칭 및 보강
  final enhancedBrokers = brokers.map((broker) {
    final matchedGlobalBroker = _findMatchingGlobalBroker(broker, globalBrokerData);
    
    if (matchedGlobalBroker == null) {
      return broker;
    }
    
    // 정보 보강 (기존 값이 없을 때만 채워넣기)
    return Broker(
      name: broker.name,
      roadAddress: broker.roadAddress,
      jibunAddress: broker.jibunAddress,
      registrationNumber: broker.registrationNumber,
      // ... 기존 필드들 ...
      ownerName: broker.ownerName ?? matchedGlobalBroker['RDEALER_NM']?.toString(),
      businessName: broker.businessName ?? matchedGlobalBroker['CMP_NM']?.toString(),
      phoneNumber: broker.phoneNumber ?? matchedGlobalBroker['TELNO']?.toString(),
      globalBrokerLanguage: matchedGlobalBroker['USE_LANG']?.toString(),
      globalBrokerAppnYear: matchedGlobalBroker['APPN_YEAR']?.toString(),
      // ... 기타 필드들 ...
    );
  }).toList();
  
  return enhancedBrokers;
}
```

##### 글로벌공인중개사무소 데이터 조회

```dart
static Future<List<Map<String, dynamic>>> _fetchSeoulGlobalBrokerData() async {
  try {
    final apiKey = ApiConstants.seoulOpenApiKey;
    if (apiKey.isEmpty) {
      return [];
    }
    
    // 1. 전체 데이터 개수 조회
    final countUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/brkPgGlobal/1/1/';
    final proxyUri = Uri.parse(
      '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(countUrl)}',
    );
    
    final countResponse = await http.get(proxyUri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
    );
    
    if (countResponse.statusCode != 200) {
      return [];
    }
    
    final countJson = json.decode(utf8.decode(countResponse.bodyBytes));
    final totalCount = int.tryParse(countJson['brkPgGlobal']?['list_total_count']?.toString() ?? '0') ?? 0;
    
    if (totalCount == 0) {
      return [];
    }
    
    // 2. 데이터 조회 (최대 1000건)
    final maxIndex = totalCount > 1000 ? 1000 : totalCount;
    final dataUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/brkPgGlobal/1/$maxIndex/';
    
    final dataProxyUri = Uri.parse(
      '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(dataUrl)}',
    );
    
    final dataResponse = await http.get(dataProxyUri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
    );
    
    if (dataResponse.statusCode != 200) {
      return [];
    }
    
    final dataJson = json.decode(utf8.decode(dataResponse.bodyBytes));
    final result = dataJson['brkPgGlobal'];
    
    if (result == null) {
      return [];
    }
    
    // RESULT 확인
    final resultCode = result['RESULT']?['CODE']?.toString() ?? '';
    if (resultCode != 'INFO-000') {
      return [];
    }
    
    // row 데이터 추출
    final rows = result['row'];
    if (rows == null) {
      return [];
    }
    
    List<Map<String, dynamic>> brokerList = [];
    if (rows is List) {
      brokerList = rows.cast<Map<String, dynamic>>().toList();
    } else if (rows is Map) {
      brokerList = [Map<String, dynamic>.from(rows)];
    }
    
    return brokerList;
  } catch (e) {
    return [];
  }
}
```

##### 매칭 로직 (등록번호 기준)

```dart
static Map<String, dynamic>? _findMatchingGlobalBroker(
  Broker broker,
  List<Map<String, dynamic>> globalBrokerData,
) {
  if (broker.registrationNumber.isEmpty) {
    return null;
  }
  
  final brokerRegNo = broker.registrationNumber.trim();
  
  // 등록번호로만 매칭 (등록번호는 절대적이고 중복이 없음)
  for (final globalBroker in globalBrokerData) {
    final raRegNo = globalBroker['RA_REGNO']?.toString().trim() ?? '';
    if (raRegNo.isNotEmpty && raRegNo == brokerRegNo) {
      return globalBroker;
    }
  }
  
  return null;
}
```

##### 3-2. 부동산 중개업소 정보 보강

```dart
static Future<List<Broker>> _enhanceWithSeoulBrokerData(List<Broker> brokers) async {
  if (brokers.isEmpty) return brokers;
  
  // 이미 글로벌공인중개사무소 정보가 있는 것은 제외
  final brokersToEnhance = brokers.where((b) {
    return b.globalBrokerLanguage == null && b.phoneNumber == null;
  }).toList();
  
  if (brokersToEnhance.isEmpty) {
    return brokers;
  }
  
  // 서울 지역인지 확인
  final seoulBrokers = brokersToEnhance.where((b) {
    final address = b.roadAddress.isNotEmpty ? b.roadAddress : b.jibunAddress;
    return address.contains('서울') || b.sggCode?.startsWith('11') == true;
  }).toList();
  
  if (seoulBrokers.isEmpty) {
    return brokers;
  }
  
  // 필요한 등록번호만 추출 (조기 종료를 위해)
  final requiredRegNos = seoulBrokers
      .map((b) => b.registrationNumber.trim())
      .where((regNo) => regNo.isNotEmpty)
      .toSet();
  
  // 필요한 등록번호만 찾으면 조기 종료되도록 최적화
  final brokerData = await _fetchSeoulBrokerData(
    requiredRegistrationNumbers: requiredRegNos,
  );
  
  if (brokerData.isEmpty) {
    return brokers;
  }
  
  // 매칭 및 보강
  final enhancedBrokers = brokers.map((broker) {
    // 이미 글로벌공인중개사무소 정보가 있으면 그대로 반환
    if (broker.globalBrokerLanguage != null) {
      return broker;
    }
    
    final matchedBroker = _findMatchingBroker(broker, brokerData);
    
    if (matchedBroker == null) {
      return broker;
    }
    
    // 정보 보강
    return Broker(
      name: broker.name,
      roadAddress: broker.roadAddress,
      // ... 기존 필드들 ...
      phoneNumber: broker.phoneNumber ?? matchedBroker['TELNO']?.toString(),
      businessStatus: broker.businessStatus ?? matchedBroker['STTS_SE']?.toString(),
      seoulAddress: broker.seoulAddress ?? matchedBroker['ADDR']?.toString(),
      district: broker.district ?? matchedBroker['CGG_CD']?.toString(),
      // ... 기타 필드들 ...
    );
  }).toList();
  
  return enhancedBrokers;
}
```

##### 부동산 중개업소 데이터 조회 (병렬 처리)

```dart
static Future<List<Map<String, dynamic>>> _fetchSeoulBrokerData({
  Set<String>? requiredRegistrationNumbers,
}) async {
  try {
    final apiKey = ApiConstants.seoulOpenApiKey;
    if (apiKey.isEmpty) {
      return [];
    }
    
    // 1. 전체 데이터 개수 조회
    final countUrl = '${ApiConstants.seoulGlobalBrokerBaseUrl}/$apiKey/json/landBizInfo/1/1/';
    final proxyUri = Uri.parse(
      '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(countUrl)}',
    );
    
    final countResponse = await http.get(proxyUri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
    );
    
    if (countResponse.statusCode != 200) {
      return [];
    }
    
    final countJson = json.decode(utf8.decode(countResponse.bodyBytes));
    final totalCount = int.tryParse(countJson['landBizInfo']?['list_total_count']?.toString() ?? '0') ?? 0;
    
    if (totalCount == 0) {
      return [];
    }
    
    // 2. 병렬 처리로 여러 페이지 동시 요청
    List<Map<String, dynamic>> allBrokerList = [];
    const int pageSize = 200;  // 200건씩 조회
    const int concurrentRequests = 10;  // 동시에 10개 요청
    final maxRequests = (totalCount / pageSize).ceil();
    
    // 필요한 등록번호가 있으면 조기 종료를 위한 Set 생성
    final requiredRegNos = requiredRegistrationNumbers?.toSet();
    final matchedRegNos = <String>{};
    
    // 병렬 처리로 여러 페이지 동시 요청
    for (int startPage = 0; startPage < maxRequests; startPage += concurrentRequests) {
      final endPage = (startPage + concurrentRequests) < maxRequests 
          ? startPage + concurrentRequests 
          : maxRequests;
      
      // 현재 배치의 병렬 요청 생성
      final futures = <Future<List<Map<String, dynamic>>>>[];
      
      for (int page = startPage; page < endPage; page++) {
        final startIndex = page * pageSize + 1;
        final endIndex = (startIndex + pageSize - 1) > totalCount 
            ? totalCount 
            : (startIndex + pageSize - 1);
        
        futures.add(_fetchSeoulBrokerPage(apiKey, startIndex, endIndex));
      }
      
      // 병렬 요청 실행
      final results = await Future.wait(futures);
      
      // 결과 병합 및 조기 종료 체크
      bool shouldEarlyExit = false;
      
      for (final pageBrokerList in results) {
        allBrokerList.addAll(pageBrokerList);
        
        // 필요한 등록번호가 있고, 아직 찾지 못한 것이 있으면 체크
        if (requiredRegNos != null && matchedRegNos.length < requiredRegNos.length) {
          for (final broker in pageBrokerList) {
            final regNo = broker['REST_BRKR_INFO']?.toString().trim();
            if (regNo != null && regNo.isNotEmpty && requiredRegNos.contains(regNo)) {
              matchedRegNos.add(regNo);
            }
          }
          
          // 모든 필요한 등록번호를 찾았으면 조기 종료
          if (matchedRegNos.length == requiredRegNos.length) {
            shouldEarlyExit = true;
            break;
          }
        }
      }
      
      // 조기 종료
      if (shouldEarlyExit) {
        break;
      }
    }
    
    return allBrokerList;
  } catch (e) {
    return [];
  }
}
```

#### 4단계: 공공데이터포털 API 조회

```dart
// 공공데이터포털 전국공인중개사사무소 표준데이터 API 조회
static Future<List<Broker>> _searchFromPublicData({
  required double latitude,
  required double longitude,
  required int radiusMeters,
}) async {
  try {
    final publicDataResult = await PublicDataBrokerService.searchBrokers(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
    
    if (publicDataResult.hasError) {
      print('공공데이터포털 API 오류: ${publicDataResult.errorMessage}');
      return [];
    }
    
    // PublicDataBroker를 Broker로 변환
    return publicDataResult.brokers
        .map((pd) => pd.toBroker())
        .toList();
  } catch (e) {
    print('공공데이터포털 API 예외: $e');
    return [];
  }
}
```

#### 5단계: 결과 병합 및 중복 제거

```dart
// VWorld API와 공공데이터포털 API 결과 병합
List<Broker> allBrokers = List<Broker>.from(vworldBrokers);

if (includePublicData) {
  final publicDataBrokers = await _searchFromPublicData(
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
  );
  
  if (publicDataBrokers.isNotEmpty) {
    // 중복 제거 (등록번호 기준)
    final existingRegNos = allBrokers
        .map((b) => b.registrationNumber)
        .where((r) => r.isNotEmpty)
        .toSet();
    
    final uniquePublicDataBrokers = publicDataBrokers
        .where((b) => !existingRegNos.contains(b.registrationNumber))
        .toList();
    
    allBrokers.addAll(uniquePublicDataBrokers);
  }
}

// 거리순 정렬
allBrokers.sort((a, b) {
  if (a.distance == null) return 1;
  if (b.distance == null) return -1;
  return a.distance!.compareTo(b.distance!);
});
```

#### 6단계: 공공데이터 포털 전국공인중개사사무소표준데이터 보강 (비동기 백그라운드)

공공데이터 포털 전국공인중개사사무소표준데이터를 사용하여 등록번호 기반으로 추가 정보를 보강합니다. 이 단계는 비동기로 처리되며, 화면이 먼저 표시된 후 백그라운드에서 정보를 업데이트합니다.

```dart
/// 공공데이터 포털 전국공인중개사사무소표준데이터로 공인중개사 정보 보강
/// 등록번호 기반으로 추가 정보 조회 및 보강
static Future<List<Broker>> _enhanceWithPublicDataBrokerAPI(List<Broker> brokers) async {
  if (brokers.isEmpty) return brokers;
  
  try {
    // 등록번호 목록 추출 (최대 100개 제한)
    final registrationNumbers = brokers
        .map((b) => b.registrationNumber.trim())
        .where((regNo) => regNo.isNotEmpty)
        .take(100) // 최대 100개 제한
        .toList();
    
    if (registrationNumbers.isEmpty) {
      return brokers;
    }
    
    // 공공데이터 포털 전국공인중개사사무소표준데이터로 정보 조회 (등록번호별)
    final enhancedBrokers = <Broker>[];
    
    for (final broker in brokers) {
      if (broker.registrationNumber.isEmpty) {
        enhancedBrokers.add(broker);
        continue;
      }
      
      try {
        // 공공데이터 포털 전국공인중개사사무소표준데이터 호출
        final publicDataBroker = await _fetchPublicDataBrokerByRegistrationNumber(
          broker.registrationNumber,
        );
        
        if (publicDataBroker != null) {
          // 정보 보강 (기존 값이 없을 때만 채워넣기)
          enhancedBrokers.add(Broker(
            name: broker.name.isNotEmpty ? broker.name : publicDataBroker['MED_OFFICE_NM'] ?? '',
            roadAddress: broker.roadAddress.isNotEmpty 
                ? broker.roadAddress 
                : (publicDataBroker['LCTN_ROAD_NM_ADDR'] ?? ''),
            jibunAddress: broker.jibunAddress.isNotEmpty 
                ? broker.jibunAddress 
                : (publicDataBroker['LCTN_LOTNO_ADDR'] ?? ''),
            registrationNumber: broker.registrationNumber,
            etcAddress: broker.etcAddress.isNotEmpty 
                ? broker.etcAddress 
                : '',
            employeeCount: broker.employeeCount.isNotEmpty 
                ? broker.employeeCount 
                : (publicDataBroker['MED_SPMBR_CNT'] ?? ''),
            registrationDate: broker.registrationDate.isNotEmpty 
                ? broker.registrationDate 
                : (publicDataBroker['ESTBL_REG_YMD'] ?? ''),
            latitude: broker.latitude,
            longitude: broker.longitude,
            distance: broker.distance,
            // 기타 필드들...
            ownerName: broker.ownerName ?? publicDataBroker['RPRSV_NM'],
            phoneNumber: broker.phoneNumber ?? publicDataBroker['TELNO'],
          ));
        } else {
          // API 조회 실패 시 원본 유지
          enhancedBrokers.add(broker);
        }
      } catch (e) {
        // 개별 항목 조회 실패 시 원본 유지
        enhancedBrokers.add(broker);
      }
    }
    
    return enhancedBrokers;
  } catch (e) {
    // 전체 보강 실패 시 원본 반환
    return brokers;
  }
}

/// 공공데이터 포털 전국공인중개사사무소표준데이터로 등록번호 기반 정보 조회
static Future<Map<String, dynamic>?> _fetchPublicDataBrokerByRegistrationNumber(
  String registrationNumber,
) async {
  try {
    final serviceKey = ApiConstants.publicDataServiceKey;
    
    final uri = Uri.parse('https://api.data.go.kr/openapi/tn_pubr_public_med_office_api').replace(
      queryParameters: {
        'serviceKey': serviceKey,
        'pageNo': '1', // 보강용이므로 첫 페이지만 조회
        'numOfRows': '10', // 등록번호가 고유하므로 1개면 충분하지만, 여유있게 10 설정
        'type': 'json',
        'ESTBL_REG_NO': registrationNumber, // 개설등록번호로 검색 (고유 식별자)
      },
    );
    
    // 프록시를 통한 요청 (다른 API와 동일한 패턴)
    final proxyUri = Uri.parse(
      '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
    );

    final response = await http.get(proxyUri).timeout(
      const Duration(seconds: ApiConstants.requestTimeoutSeconds),
      onTimeout: () => throw Exception('API 타임아웃'),
    );

    if (response.statusCode == 200) {
      final jsonText = utf8.decode(response.bodyBytes);
      final data = json.decode(jsonText);
      
      final responseData = data['response'];
      if (responseData != null) {
        final header = responseData['header'];
        if (header != null && header['resultCode'] == '00') {
          final body = responseData['body'];
          final items = body['items'] as List?;
          
          if (items != null && items.isNotEmpty) {
            final item = items.first as Map<String, dynamic>;
            
            return {
              'MED_OFFICE_NM': item['MED_OFFICE_NM']?.toString() ?? '', // 중개사무소명
              'ESTBL_REG_NO': item['ESTBL_REG_NO']?.toString() ?? '', // 개설등록번호
              'RPRSV_NM': item['RPRSV_NM']?.toString() ?? '', // 대표자명
              'LCTN_ROAD_NM_ADDR': item['LCTN_ROAD_NM_ADDR']?.toString() ?? '', // 도로명주소
              'LCTN_LOTNO_ADDR': item['LCTN_LOTNO_ADDR']?.toString() ?? '', // 지번주소
              'TELNO': item['TELNO']?.toString() ?? '', // 전화번호
              'ESTBL_REG_YMD': item['ESTBL_REG_YMD']?.toString() ?? '', // 개설등록일자
              'MED_SPMBR_CNT': item['MED_SPMBR_CNT']?.toString() ?? '', // 중개보조원수
              'LATITUDE': item['LATITUDE']?.toString() ?? '', // 위도
              'LONGITUDE': item['LONGITUDE']?.toString() ?? '', // 경도
            };
          }
        }
      }
    }
    
    return null;
  } catch (e) {
    return null;
  }
}
```

**보강 전략:**
- **비동기 처리**: 화면 먼저 표시 후 백그라운드에서 보강
- **점진적 업데이트**: 보강 완료된 항목부터 UI 업데이트
- **에러 처리**: 보강 실패해도 기존 결과 유지
- **성능 최적화**: 최대 100개 제한, 개별 항목 실패 시에도 전체 프로세스 계속 진행

**보강 타이밍 옵션:**
1. **즉시 보강**: 검색 직후 모든 항목 보강 (기본)
2. **지연 보강**: 화면 표시 후 몇 초 뒤 보강
3. **페이지네이션 보강**: 페이지 이동 시 해당 페이지 항목만 보강

#### 7단계: Firestore 데이터 보강

```dart
Future<void> _enhanceWithFirestoreData(List<Broker> brokers) async {
  try {
    // 등록번호 목록 추출
    final registrationNumbers = brokers
        .map((b) => b.registrationNumber.trim())
        .where((regNo) => regNo.isNotEmpty)
        .toList();
    
    if (registrationNumbers.isEmpty) {
      return;
    }
    
    // Firestore에서 일괄 조회
    final firestoreDataMap = await _firebaseService
        .getBrokersByRegistrationNumbers(registrationNumbers);
    
    // 보강
    final enhancedBrokers = brokers.map((broker) {
      if (broker.registrationNumber.isEmpty) {
        return broker;
      }
      
      final firestoreData = firestoreDataMap[broker.registrationNumber];
      if (firestoreData == null) {
        return broker;
      }
      
      return Broker(
        name: broker.name,
        roadAddress: broker.roadAddress,
        // ... 기존 필드들 ...
        phoneNumber: firestoreData['phoneNumber'] as String? ?? broker.phoneNumber,
        introduction: firestoreData['introduction'] as String? ?? broker.introduction,
        // ... 기타 필드들 ...
      );
    }).toList();
    
    if (!mounted) return;
    
    setState(() {
      propertyBrokers = enhancedBrokers;
      brokers = List<Broker>.from(propertyBrokers);
      _applyFilters();
    });
  } catch (e) {
    // Firestore 보강 실패 시 원본 데이터 유지
  }
}
```

### UI 통합 (broker_list_page.dart)

```dart
Future<void> _searchBrokers() async {
  if (!mounted) return;
  
  setState(() {
    isLoading = true;
    error = null;
  });
  
  try {
    // 1단계: VWorld API 결과 먼저 가져오기
    final response = await BrokerService.searchNearbyBrokers(
      latitude: widget.latitude,
      longitude: widget.longitude,
      radiusMeters: widget.radiusMeters.toInt(), // 사용자가 선택한 반경 사용
    );
    
    // 기본 결과 복사
    List<Broker> mergedBrokers = List<Broker>.from(response.brokers);
    
    // 2단계: Firestore 데이터 보강 (비동기)
    setState(() {
      propertyBrokers = mergedBrokers;
      _sortBySystemRegNo(propertyBrokers);
      brokers = List<Broker>.from(propertyBrokers);
      isLoading = false;
    });
    
    // 3단계: Firestore 보강 (백그라운드)
    _enhanceWithFirestoreData(mergedBrokers);
    
  } catch (e) {
    if (!mounted) return;
    
    setState(() {
      isLoading = false;
      error = '공인중개사 정보를 불러오는 중 오류가 발생했습니다.';
    });
  }
}
```

---

## 활성화 방법

### 1. 플래그 변경

`lib/screens/home_page.dart` 파일에서 플래그를 변경합니다:

```dart
// 현재 (비활성화)
static const bool isAddressSearchEnabled = false;

// 변경 후 (활성화)
static const bool isAddressSearchEnabled = true;
```

### 2. UI 확인

현재 구현된 UI 요소들:

- ✅ 히어로 배너 (타이틀 및 설명만 표시, 검색창 없음)
- ✅ 주소 검색 탭 (`AddressSearchTabs`)
  - GPS 기반 검색 탭 (`GpsBasedSearchTab`)
  - 주소 입력 검색 탭 (`AddressInputTab`)
- ✅ 주소 검색 결과 목록 (`RoadAddressList`)
- ✅ 페이지네이션 버튼 (이전/다음)
- ✅ 지도 및 반경 슬라이더 (각 탭에 통합)

### 3. 기능 테스트

1. **주소검색 테스트**
   - 주소 검색 탭의 "주소 입력 검색" 탭에서 주소 입력 (최소 2글자)
   - 검색 결과 목록 확인
   - 주소 선택
   - 지도에서 선택한 주소 위치 확인
   - 반경 슬라이더로 검색 반경 설정

2. **좌표 변환 테스트**
   - 주소 선택 후 좌표 조회 확인
   - `vworldCoordinates` 상태 확인

3. **공인중개사 검색 테스트**
   - "공인중개사 찾기" 버튼 클릭
   - `BrokerListPage`로 이동 확인
   - 공인중개사 목록 표시 확인

---

## 데이터 모델

### AddressSearchResult

```dart
class AddressSearchResult {
  final List<Map<String,String>> fullData;  // 전체 API 응답 데이터
  final List<String> addresses;              // 표시용 주소 목록
  final int totalCount;                      // 전체 검색 결과 수
  final String? errorMessage;                // 에러 메시지
}
```

### SelectedAddressResult

GPS 기반 검색과 주소 입력 검색 모두에서 사용되는 공통 결과 모델입니다.

```dart
class SelectedAddressResult {
  final String address;                      // 선택된 주소
  final double? latitude;                    // 위도 (GPS 기반 검색의 경우 필수)
  final double? longitude;                   // 경도 (GPS 기반 검색의 경우 필수)
  final Map<String, String>? fullAddrAPIData; // 전체 주소 API 데이터 (주소 입력 검색의 경우 포함)
  final double? radiusMeters;                // 검색 반경 (미터 단위, 슬라이더로 선택한 값)
}
```

**사용 위치:**
- `lib/widgets/address_search/address_search_result.dart`
- GPS 기반 검색 탭과 주소 입력 검색 탭 모두에서 이 모델을 사용하여 결과를 전달
- `home_page.dart`에서 이 모델을 받아 `BrokerListPage`로 전달

### BrokerSearchResult

```dart
class BrokerSearchResult {
  final List<Broker> brokers;                 // 공인중개사 목록
  final int radiusMetersUsed;                 // 사용된 검색 반경
  final bool wasExpanded;                     // 반경 확장 여부
}
```

### PublicDataBroker (공공데이터포털 API)

```dart
class PublicDataBroker {
  final String officeName;              // 중개사무소명 (MED_OFFICE_NM)
  final String registrationNumber;      // 개설등록번호 (ESTBL_REG_NO)
  final String brokerType;              // 개업공인중개사종별구분 (OPBIZ_LREA_CLSC_SE)
  final String roadAddress;              // 소재지도로명주소 (LCTN_ROAD_NM_ADDR)
  final String jibunAddress;            // 소재지지번주소 (LCTN_LOTNO_ADDR)
  final String phoneNumber;             // 전화번호 (TELNO)
  final String registrationDate;        // 개설등록일자 (ESTBL_REG_YMD)
  final String insuranceJoinYn;         // 공제가입유무 (DDC_JOIN_YN)
  final String representativeName;      // 대표자명 (RPRSV_NM)
  final double? latitude;                // 위도 (LATITUDE)
  final double? longitude;                // 경도 (LONGITUDE)
  final double? distance;                // 거리 (미터)
  final int? assistantCount;             // 중개보조원수 (MED_SPMBR_CNT)
  final int? brokerCount;                // 소속공인중개사수 (OGDP_LREA_CNT)
  final String homepage;                 // 홈페이지주소 (HMPG_ADDR)
  final String dataDate;                 // 데이터기준일자 (CRTR_YMD)
  final String institutionCode;         // 제공기관코드 (instt_code)
  final String institutionName;         // 제공기관명 (instt_nm)

  /// Broker 모델로 변환
  Broker toBroker() {
    return Broker(
      name: officeName,
      roadAddress: roadAddress,
      jibunAddress: jibunAddress,
      registrationNumber: registrationNumber,
      phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
      ownerName: representativeName.isNotEmpty ? representativeName : null,
      latitude: latitude,
      longitude: longitude,
      distance: distance,
      registrationDate: registrationDate,
      businessStatus: insuranceJoinYn == 'Y' ? '영업중' : null,
    );
  }
}

class PublicDataBrokerSearchResult {
  final List<PublicDataBroker> brokers;
  final int totalCount;
  final int pageNo;
  final int numOfRows;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
  bool get isEmpty => brokers.isEmpty && !hasError;
}
```

### Broker

```dart
class Broker {
  // 기본 정보
  final String name;                         // 상호명
  final String roadAddress;                  // 도로명주소
  final String jibunAddress;                 // 지번주소
  final String registrationNumber;           // 등록번호
  final String etcAddress;                   // 기타주소
  final String employeeCount;                // 고용인원
  final String registrationDate;             // 등록일
  
  // 위치 정보
  final double? latitude;                     // 위도
  final double? longitude;                    // 경도
  final double? distance;                     // 거리 (미터)
  
  // 서울시 API 추가 정보
  final String? systemRegNo;                 // 시스템등록번호
  final String? ownerName;                   // 중개업자명
  final String? businessName;                // 사업자상호
  final String? phoneNumber;                 // 전화번호
  final String? businessStatus;              // 상태구분
  final String? seoulAddress;                // 서울시 API 주소
  final String? district;                    // 자치구명
  final String? legalDong;                   // 법정동명
  final String? sggCode;                     // 시군구코드
  final String? stdgCode;                    // 법정동코드
  final String? lotnoSe;                     // 지번구분
  final String? mno;                         // 본번
  final String? sno;                         // 부번
  final String? roadCode;                    // 도로명코드
  final String? bldg;                        // 건물
  final String? bmno;                        // 건물 본번
  final String? bsno;                        // 건물 부번
  final String? penaltyStartDate;            // 행정처분 시작일
  final String? penaltyEndDate;              // 행정처분 종료일
  final String? inqCount;                    // 조회 개수
  
  // Firestore 추가 정보
  final String? introduction;                 // 공인중개사 소개
  
  // 글로벌공인중개사무소 정보
  final String? globalBrokerLanguage;        // 사용언어
  final String? globalBrokerAppnYear;         // 지정연도
  final String? globalBrokerAppnNo;           // 지정번호
  final String? globalBrokerAppnDe;          // 지정일
}
```

---

## API 연동 상세

### 1. 도로명주소 API

**엔드포인트:**
```
${ApiConstants.baseJusoUrl}
```

**파라미터:**
- `currentPage`: 현재 페이지 번호
- `countPerPage`: 페이지당 결과 수 (기본 20개)
- `keyword`: 검색 키워드
- `confmKey`: API 인증 키
- `resultType`: 응답 형식 (json)

**응답 형식:**
```json
{
  "results": {
    "common": {
      "errorCode": "0",
      "errorMessage": "정상",
      "totalCount": "100"
    },
    "juso": [
      {
        "roadAddr": "서울특별시 강남구 테헤란로 123",
        "jibunAddr": "서울특별시 강남구 역삼동 123-45",
        "bdMgtSn": "1168010100101230001",
        "roadAddrPart1": "서울특별시 강남구 테헤란로",
        "roadAddrPart2": "123",
        "admCd": "1168010100",
        "rnMgtSn": "1168010100101230001",
        ...
      }
    ]
  }
}
```

### 2. VWorld Geocoder API

**엔드포인트:**
```
${VWorldApiConstants.geocoderBaseUrl}
```

**파라미터:**
- `service`: "address"
- `request`: "getCoord"
- `version`: "2.0"
- `crs`: "EPSG:4326"
- `address`: 주소 문자열
- `type`: "ROAD" 또는 "PARCEL"
- `simple`: "true"
- `format`: "json"
- `key`: API 인증 키

**응답 형식:**
```json
{
  "response": {
    "status": "OK",
    "result": {
      "point": {
        "x": "127.1234567",
        "y": "37.1234567"
      },
      "level": "8",
      "text": "서울특별시 강남구 테헤란로 123"
    }
  }
}
```

### 3. VWorld WFS API (공인중개사)

**엔드포인트:**
```
${VWorldApiConstants.brokerQueryBaseUrl}
```

**파라미터:**
- `key`: API 인증 키
- `typename`: "lt_c_adsido_info" (공인중개사 레이어)
- `bbox`: "ymin,xmin,ymax,xmax,EPSG:4326"
- `resultType`: "results"
- `srsName`: "EPSG:4326"
- `output`: "application/json"
- `maxFeatures`: 최대 결과 수

**응답 형식:**
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [127.1234567, 37.1234567]
      },
      "properties": {
        "bsnm_cmpnm": "○○공인중개사",
        "rdnmadr": "서울특별시 강남구 테헤란로 123",
        "mnnmadr": "서울특별시 강남구 역삼동 123-45",
        "brkpg_regist_no": "12345678901234",
        "emplym_co": "5",
        "frst_regist_dt": "2020-01-01T00:00:00Z",
        ...
      }
    }
  ]
}
```

### 4. 서울시 글로벌공인중개사무소 API

**엔드포인트:**
```
${ApiConstants.seoulGlobalBrokerBaseUrl}/{apiKey}/json/brkPgGlobal/{startIndex}/{endIndex}/
```

**응답 형식:**
```json
{
  "brkPgGlobal": {
    "list_total_count": 100,
    "RESULT": {
      "CODE": "INFO-000",
      "MESSAGE": "정상 처리되었습니다"
    },
    "row": [
      {
        "RA_REGNO": "12345678901234",
        "RDEALER_NM": "홍길동",
        "CMP_NM": "○○공인중개사",
        "TELNO": "02-1234-5678",
        "USE_LANG": "영어,중국어",
        "APPN_YEAR": "2020",
        "APPN_NO": "123",
        "APPN_DE": "20200101",
        ...
      }
    ]
  }
}
```

### 5. 서울시 부동산 중개업소 API

**엔드포인트:**
```
${ApiConstants.seoulGlobalBrokerBaseUrl}/{apiKey}/json/landBizInfo/{startIndex}/{endIndex}/
```

**응답 형식:**
```json
{
  "landBizInfo": {
    "list_total_count": 1000,
    "RESULT": {
      "CODE": "INFO-000",
      "MESSAGE": "정상 처리되었습니다"
    },
    "row": [
      {
        "REST_BRKR_INFO": "12345678901234",
        "MDT_BSNS_NM": "홍길동",
        "BZMN_CONM": "○○공인중개사",
        "TELNO": "02-1234-5678",
        "STTS_SE": "정상",
        "ADDR": "서울특별시 강남구 테헤란로 123",
        "CGG_CD": "11680",
        "LGL_DONG_NM": "역삼동",
        "SGG_CD": "11680",
        "STDG_CD": "1168010100",
        ...
      }
    ]
  }
}
```

### 6. 공공데이터 포털 전국공인중개사사무소표준데이터 (공인중개사 정보 보강)

**용도**: 등록번호 기반 공인중개사 정보 보강 (검증이 아닌 정보 보강)

**엔드포인트:**
```
https://api.data.go.kr/openapi/tn_pubr_public_med_office_api
```

**파라미터:**
- `serviceKey`: 공공데이터포털 서비스 키 (Encoding 또는 Decoding)
- `pageNo`: `1` (보강용이므로 첫 페이지만 조회)
- `numOfRows`: `10` (등록번호가 고유하므로 1개면 충분하지만, 여유있게 10 설정)
- `type`: `json` (JSON 형식)
- `ESTBL_REG_NO`: 개설등록번호 (등록번호 필터, 고유 식별자이므로 이것만으로 검색 가능)

**프록시 사용:**
- 다른 API와 동일한 패턴 사용
- `ApiConstants.proxyRequstAddr`를 통한 프록시 요청

**JSON 응답 형식:**
```json
{
  "response": {
    "header": {
      "resultCode": "00",
      "resultMsg": "NORMAL_CODE"
    },
    "body": {
      "items": [
        {
          "MED_OFFICE_NM": "서전공인중개사무소",
          "ESTBL_REG_NO": "46910-2019-00003",
          "OPBIZ_LREA_CLSC_SE": "공인중개사",
          "LCTN_ROAD_NM_ADDR": "전라남도 신안군 압해읍 압해로 881",
          "LCTN_LOTNO_ADDR": "",
          "TELNO": "",
          "ESTBL_REG_YMD": "2019-11-14",
          "DDC_JOIN_YN": "Y",
          "RPRSV_NM": "이명심",
          "LATITUDE": "34.86510562",
          "LONGITUDE": "126.3127646",
          "MED_SPMBR_CNT": "",
          "OGDP_LREA_CNT": "",
          "HMPG_ADDR": "",
          "CRTR_YMD": "2023-07-03",
          "instt_code": "5010000",
          "instt_nm": "전라남도 신안군"
        }
      ],
      "numOfRows": 100,
      "pageNo": 1,
      "totalCount": 1
    }
  }
}
```

**응답 필드 상세:**

| 필드명 | 타입 | 설명 | 비고 |
|--------|------|------|------|
| `MED_OFFICE_NM` | String | 중개사무소명 | - |
| `ESTBL_REG_NO` | String | 개설등록번호 | 형식: `{지역코드}-{연도}-{일련번호}` |
| `RPRSV_NM` | String | 대표자명 | - |
| `LCTN_ROAD_NM_ADDR` | String | 소재지도로명주소 | - |
| `LCTN_LOTNO_ADDR` | String | 소재지지번주소 | - |
| `TELNO` | String | 전화번호 | - |
| `ESTBL_REG_YMD` | String | 개설등록일자 | 형식: `YYYY-MM-DD` |
| `LATITUDE` | String | 위도 | - |
| `LONGITUDE` | String | 경도 | - |
| `MED_SPMBR_CNT` | String | 중개보조원수 | - |
| `OGDP_LREA_CNT` | String | 소속공인중개사수 | - |

**에러 처리:**
- **타임아웃**: 5초 초과 시 `null` 반환
- **HTTP 오류**: statusCode != 200 시 `null` 반환
- **파싱 오류**: JSON 파싱 실패 시 `null` 반환
- **전체 보강 실패**: 원본 데이터 반환 (보강 실패해도 기존 결과 유지)
- **에러 코드**: `00` (정상), `22` (일일 트래픽 초과), `31` (서비스키 만료) 등

### 7. 공공데이터포털 전국공인중개사사무소 표준데이터 API (검색용)

**서비스 정보:**
- **데이터명**: 전국공인중개사사무소표준데이터
- **서비스유형**: REST
- **심의여부**: 자동승인
- **활용기간**: 2025-12-29 ~ 2027-12-29
- **데이터포맷**: JSON+XML
- **일일 트래픽**: 1,000건
- **활용목적**: 웹 사이트 개발
- **라이센스**: 저작자표시

**엔드포인트:**
```
https://api.data.go.kr/openapi/tn_pubr_public_med_office_api
```

**인증키:**
- **Encoding**: `lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh%2BTl1KORZJXQTqih1BTBLpxfdixxY0mUQ%3D%3D`
- **Decoding**: `lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==`

⚠️ **중요**: API 환경 또는 API 호출 조건에 따라 인증키가 적용되는 방식이 다를 수 있습니다. 포털에서 제공되는 Encoding/Decoding 된 인증키를 적용하면서 구동되는 키를 사용하시기 바랍니다.

**필수 파라미터:**
- `serviceKey`: 공공데이터포털 서비스 키 (Encoding 또는 Decoding)
- `pageNo`: 페이지 번호
- `numOfRows`: 한 페이지 결과 수
- `type`: 응답 형식 (xml/json)

**선택 파라미터 (검색 조건):**
- `MED_OFFICE_NM`: 중개사무소명
- `ESTBL_REG_NO`: 개설등록번호
- `OPBIZ_LREA_CLSC_SE`: 개업공인중개사종별구분
- `LCTN_ROAD_NM_ADDR`: 소재지도로명주소
- `LCTN_LOTNO_ADDR`: 소재지지번주소
- `TELNO`: 전화번호
- `ESTBL_REG_YMD`: 개설등록일자
- `DDC_JOIN_YN`: 공제가입유무 (Y/N)
- `RPRSV_NM`: 대표자명
- `LATITUDE`: 위도
- `LONGITUDE`: 경도
- `MED_SPMBR_CNT`: 중개보조원수
- `OGDP_LREA_CNT`: 소속공인중개사수
- `HMPG_ADDR`: 홈페이지주소
- `CRTR_YMD`: 데이터기준일자
- `instt_code`: 제공기관코드
- `instt_nm`: 제공기관명

**응답 형식 (JSON):**
```json
{
  "response": {
    "header": {
      "resultCode": "00",
      "resultMsg": "NORMAL_CODE"
    },
    "body": {
      "items": [
        {
          "MED_OFFICE_NM": "서전공인중개사무소",
          "ESTBL_REG_NO": "46910-2019-00003",
          "OPBIZ_LREA_CLSC_SE": "공인중개사",
          "LCTN_ROAD_NM_ADDR": "전라남도 신안군 압해읍 압해로 881",
          "LCTN_LOTNO_ADDR": "",
          "TELNO": "",
          "ESTBL_REG_YMD": "2019-11-14",
          "DDC_JOIN_YN": "Y",
          "RPRSV_NM": "이명심",
          "LATITUDE": "34.86510562",
          "LONGITUDE": "126.3127646",
          "MED_SPMBR_CNT": "",
          "OGDP_LREA_CNT": "",
          "HMPG_ADDR": "",
          "CRTR_YMD": "2023-07-03",
          "instt_code": "5010000",
          "instt_nm": "전라남도 신안군"
        }
      ],
      "numOfRows": 100,
      "pageNo": 1,
      "totalCount": 1
    }
  }
}
```

**에러 코드:**
- `00`: 정상
- `22`: 서비스 요청제한횟수 초과에러 (일일 1,000건 초과)
- `31`: 기한만료된 서비스키 (활용기간 만료)
- 기타 에러 코드는 공공데이터포털 표준 에러 코드 참조

---

## 에러 처리

### 1. 주소검색 에러 처리

```dart
// 타임아웃
if (e is TimeoutException) {
  return AddressSearchResult(
    errorMessage: '주소 검색 시간이 초과되었습니다.',
  );
}

// 네트워크 오류
if (e is SocketException) {
  return AddressSearchResult(
    errorMessage: '네트워크 연결을 할 수 없습니다.',
  );
}

// 서버 오류
if (response.statusCode >= 500 && response.statusCode < 600) {
  return AddressSearchResult(
    errorMessage: '주소 검색 서비스가 일시적으로 사용할 수 없습니다.',
  );
}

// API 에러 코드
if (errorCode != '0') {
  return AddressSearchResult(
    errorMessage: 'API 오류: $errorMsg',
  );
}
```

### 2. 좌표 변환 에러 처리

```dart
try {
  final result = await VWorldService.getLandInfoFromAddress(address);
  if (result == null) {
    setState(() {
      vworldError = '선택한 주소에서 정확한 좌표를 찾지 못했습니다.';
    });
  }
} catch (e) {
  setState(() {
    vworldError = 'VWorld API 오류: ${e.toString()}';
  });
}
```

### 3. 공인중개사 검색 에러 처리

```dart
try {
  final response = await BrokerService.searchNearbyBrokers(
    latitude: lat,
    longitude: lon,
  );
  
  if (response.brokers.isEmpty) {
    setState(() {
      error = '주변에 공인중개사를 찾을 수 없습니다.';
    });
  }
} catch (e) {
  setState(() {
    error = '공인중개사 정보를 불러오는 중 오류가 발생했습니다.';
  });
}
```

### 4. 공공데이터 포털 전국공인중개사사무소표준데이터 보강 에러 처리

```dart
// 타임아웃 처리
final response = await http.get(proxyUri).timeout(
  const Duration(seconds: ApiConstants.requestTimeoutSeconds),
  onTimeout: () => throw Exception('API 타임아웃'),
);

// HTTP 오류 처리
if (response.statusCode != 200) {
  return null; // 보강 실패 시 null 반환
}

// 파싱 오류 처리
try {
  final jsonText = utf8.decode(response.bodyBytes);
  final data = json.decode(jsonText);
  // 파싱 로직...
} catch (e) {
  return null; // 파싱 실패 시 null 반환
}

// 전체 보강 실패 처리
try {
  // 보강 로직...
} catch (e) {
  return brokers; // 오류 발생 시 원본 반환
}
```

**에러 처리 원칙:**
- 보강 실패해도 기존 검색 결과는 유지
- 개별 항목 보강 실패 시에도 전체 프로세스 계속 진행
- 사용자에게 에러 메시지 표시하지 않음 (백그라운드 처리)

---

## 성능 최적화

### 1. 디바운싱

주소검색 시 디바운싱을 적용하여 불필요한 API 호출을 방지합니다:

```dart
_addressSearchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
  _performAddressSearch(keyword, page: page);
});
```

### 2. 중복 요청 방지

같은 키워드로 이미 검색 중이면 요청을 취소합니다:

```dart
if (_lastSearchKeyword == keyword.trim() && isSearchingRoadAddr) {
  return;
}
```

### 3. 병렬 처리

서울시 부동산 중개업소 API 조회 시 병렬 처리로 성능을 향상시킵니다:

```dart
const int concurrentRequests = 10;  // 동시에 10개 요청
final futures = <Future<List<Map<String, dynamic>>>>[];

for (int page = startPage; page < endPage; page++) {
  futures.add(_fetchSeoulBrokerPage(apiKey, startIndex, endIndex));
}

final results = await Future.wait(futures);
```

### 4. 조기 종료

필요한 등록번호를 모두 찾으면 조기 종료합니다:

```dart
if (requiredRegNos != null && matchedRegNos.length == requiredRegNos.length) {
  shouldEarlyExit = true;
  break;
}
```

### 5. 캐싱

Firestore 데이터는 한 번 조회하면 재사용합니다:

```dart
final firestoreDataMap = await _firebaseService
    .getBrokersByRegistrationNumbers(registrationNumbers);
```

### 6. 반경 확장 최적화

결과가 없을 때만 반경을 확장합니다:

```dart
if (shouldAutoRetry && brokers.isEmpty && radiusMeters < 10000) {
  final retryResult = await _retryWithExpandedRadius(...);
}
```

### 7. 공공데이터 포털 전국공인중개사사무소표준데이터 보강 최적화

공공데이터 포털 전국공인중개사사무소표준데이터 보강은 비동기 백그라운드 처리로 사용자 경험을 저하시키지 않습니다:

**최적화 전략:**

1. **최대 항목 수 제한**
```dart
final registrationNumbers = brokers
    .map((b) => b.registrationNumber.trim())
    .where((regNo) => regNo.isNotEmpty)
    .take(100) // 최대 100개 제한
    .toList();
```

2. **비동기 백그라운드 보강**
```dart
// 화면 먼저 표시
setState(() {
  brokers = initialBrokers;
  isLoading = false;
});

// 백그라운드에서 보강
_enhanceWithPublicDataBrokerAPI(initialBrokers).then((enhancedBrokers) {
  if (mounted) {
    setState(() {
      brokers = enhancedBrokers;
    });
  }
});
```

3. **보강 타이밍 옵션**

**옵션 A: 즉시 보강 (기본)**
- 검색 직후 모든 항목 보강
- 장점: 빠른 정보 업데이트
- 단점: 초기 로딩 시간 증가 가능

**옵션 B: 지연 보강**
```dart
// 화면 표시 후 2초 뒤 보강
Future.delayed(const Duration(seconds: 2), () {
  _enhanceWithPublicDataBrokerAPI(brokers);
});
```
- 장점: 초기 화면 표시 빠름
- 단점: 정보 업데이트 지연

**옵션 C: 페이지네이션 보강**
```dart
// 페이지 이동 시 해당 페이지 항목만 보강
void _onPageChanged(int page) {
  final pageItems = _getPageItems(page);
  _enhanceWithPublicDataBrokerAPI(pageItems);
}
```
- 장점: 필요한 항목만 보강, 효율적
- 단점: 페이지 이동 시마다 보강 필요

4. **개별 항목 실패 처리**
```dart
for (final broker in brokers) {
  try {
    final publicDataBroker = await _fetchPublicDataBrokerByRegistrationNumber(
      broker.registrationNumber,
    );
    // 보강 로직...
  } catch (e) {
    // 개별 항목 실패해도 계속 진행
    enhancedBrokers.add(broker);
  }
}
```

**성능 테스트 시나리오:**

1. **100개 항목 즉시 보강 테스트**
   - 측정 항목: 전체 보강 완료 시간
   - 목표: 10초 이내 완료

2. **지연 보강 테스트**
   - 측정 항목: 화면 표시 시간, 보강 완료 시간
   - 목표: 화면 표시 1초 이내, 보강 완료 5초 이내

3. **페이지네이션 보강 테스트**
   - 측정 항목: 페이지당 보강 시간
   - 목표: 페이지당 1초 이내

4. **에러 처리 테스트**
   - 시나리오: 일부 항목 API 실패
   - 확인: 전체 프로세스 중단 없이 계속 진행

---

## 주요 상수 및 설정

### API 엔드포인트

```dart
// 도로명주소 API
ApiConstants.baseJusoUrl
ApiConstants.jusoApiKey

// VWorld API
VWorldApiConstants.geocoderBaseUrl
VWorldApiConstants.geocoderApiKey
VWorldApiConstants.brokerQueryBaseUrl
VWorldApiConstants.apiKey

// 서울시 API
ApiConstants.seoulGlobalBrokerBaseUrl
ApiConstants.seoulOpenApiKey

// 공공데이터포털 API
ApiConstants.publicDataServiceKey
ApiConstants.publicDataBrokerApiUrl

// 프록시
ApiConstants.proxyRequstAddr
VWorldApiConstants.vworldProxyUrl
```

### 검색 설정

```dart
// 기본 검색 반경
int radiusMeters = 1000;  // 1km

// 최대 검색 반경
const int maxRadius = 10000;  // 10km

// 페이지당 결과 수
ApiConstants.pageSize  // 기본 20개

// 최대 결과 수
VWorldApiConstants.brokerMaxFeatures

// 타임아웃
ApiConstants.requestTimeoutSeconds  // 기본 30초
```

---

## 테스트 시나리오

### 시나리오 1: 정상 플로우 (주소 입력 검색)

1. 사용자가 주소 검색 탭의 "주소 입력 검색" 탭에서 "강남구 테헤란로" 입력
2. 디바운싱 후 주소검색 API 호출 (`AddressInputTab`)
3. 검색 결과 목록 표시 (`RoadAddressList`)
4. 사용자가 주소 선택
5. 선택한 주소 위치로 지도 이동
6. 반경 슬라이더로 검색 반경 설정 (예: 1km)
7. VWorld Geocoder API 호출하여 좌표 획득 (주소 입력 검색의 경우)
8. "공인중개사 찾기" 버튼 클릭
9. BrokerService로 공인중개사 검색 (설정한 반경 사용)
10. VWorld WFS API 호출
11. 공공데이터포털 전국공인중개사사무소 API 호출
12. 결과 병합 및 중복 제거
13. 서울 지역이면 서울시 API로 보강
14. 공인중개사 목록 표시 (화면 먼저 표시)
15. 공공데이터 포털 전국공인중개사사무소표준데이터로 백그라운드 보강 (비동기)
16. Firestore 데이터로 추가 보강
17. 보강 완료된 정보로 UI 업데이트

### 시나리오 1-2: 정상 플로우 (GPS 기반 검색)

1. 사용자가 주소 검색 탭의 "GPS 기반 검색" 탭 선택
2. GPS 위치 자동 감지 (`GpsBasedSearchTab`)
3. 지도에서 위치 선택 및 반경 설정 (슬라이더: 300m, 500m, 1km, 1.5km)
4. VWorld Reverse Geocoder API로 좌표 → 주소 변환
5. 선택한 주소 및 반경 정보 확인
6. "공인중개사 찾기" 버튼 클릭
7. BrokerService로 공인중개사 검색 (GPS 좌표 및 설정한 반경 사용)
8. 이후 플로우는 시나리오 1과 동일

### 시나리오 2: 검색 결과 없음

1. 사용자가 주소 검색 탭의 "주소 입력 검색" 탭에서 "존재하지않는주소123" 입력
2. 주소검색 API 호출
3. 검색 결과 없음 메시지 표시
4. 사용자가 다른 주소 입력

### 시나리오 3: 좌표 변환 실패

1. 사용자가 주소 선택
2. VWorld Geocoder API 호출
3. 좌표 변환 실패
4. 에러 메시지 표시
5. 사용자가 다른 주소 선택

### 시나리오 4: 공인중개사 없음

1. 사용자가 주소 선택
2. 좌표 획득
3. 공인중개사 검색 (1km 반경)
4. 결과 없음
5. 반경 확장 (최대 10km)
6. 여전히 결과 없음
7. "주변에 공인중개사를 찾을 수 없습니다" 메시지 표시

### 시나리오 5: 공공데이터 포털 전국공인중개사사무소표준데이터 보강 테스트

**5-1. 즉시 보강 테스트**
1. 공인중개사 검색 완료 (100개 이하)
2. 화면 표시
3. 공공데이터 포털 전국공인중개사사무소표준데이터 즉시 보강 시작
4. 각 항목별 등록번호로 API 호출
5. 보강 완료된 항목부터 UI 업데이트
6. 전체 보강 완료 시간 측정 (목표: 10초 이내)

**5-2. 지연 보강 테스트**
1. 공인중개사 검색 완료
2. 화면 즉시 표시 (1초 이내)
3. 2초 후 공공데이터 포털 전국공인중개사사무소표준데이터 보강 시작
4. 백그라운드에서 보강 진행
5. 보강 완료 시 UI 업데이트

**5-3. 페이지네이션 보강 테스트**
1. 공인중개사 검색 완료 (100개 이상)
2. 첫 페이지 표시
3. 사용자가 다음 페이지로 이동
4. 해당 페이지 항목만 공공데이터 포털 전국공인중개사사무소표준데이터 보강
5. 페이지당 보강 시간 측정 (목표: 1초 이내)

**5-4. 에러 처리 테스트**
1. 공인중개사 검색 완료
2. 공공데이터 포털 전국공인중개사사무소표준데이터 보강 시작
3. 일부 항목 API 호출 실패 (네트워크 오류, 타임아웃 등)
4. 실패한 항목은 원본 데이터 유지
5. 성공한 항목만 보강되어 UI 업데이트
6. 전체 프로세스 중단 없이 계속 진행 확인

---

## 주의사항

### 1. API 키 관리

- 모든 API 키는 환경 변수로 관리
- `.env` 파일에 저장
- Git에 커밋하지 않음

### 2. 프록시 사용

- CORS 우회를 위해 프록시 사용
- `ApiConstants.proxyRequstAddr` 설정 확인

### 3. 타임아웃 설정

- 모든 API 호출에 타임아웃 설정
- 기본 30초, 필요시 조정

### 4. 에러 처리

- 모든 API 호출에 try-catch 적용
- 사용자 친화적인 에러 메시지 제공

### 5. 성능 고려

- 디바운싱으로 불필요한 요청 방지
- 병렬 처리로 성능 향상
- 조기 종료로 불필요한 데이터 조회 방지

### 6. 공공데이터포털 API 주의사항

- **트래픽 제한**: 일일 1,000건 제한 (개발계정)
- **활용기간**: 2025-12-29 ~ 2027-12-29 (만료 전 갱신 필요)
- **인증키**: Encoding/Decoding 방식에 따라 다르게 적용될 수 있음
- **라이센스**: 저작자표시 필요
- **에러 처리**: 트래픽 초과 시 에러 코드 `22` 반환, 기존 결과는 유지

### 7. 공공데이터 포털 전국공인중개사사무소표준데이터 보강 주의사항

- **비동기 처리**: 화면 먼저 표시 후 백그라운드에서 보강 (필수)
- **최대 항목 수**: 100개 제한 (검색 결과가 많아도 100개까지만 보강)
- **보강 실패 처리**: 보강 실패해도 기존 검색 결과는 유지
- **개별 항목 실패**: 일부 항목 보강 실패해도 전체 프로세스 계속 진행
- **프록시 사용**: 다른 API와 동일한 프록시 패턴 사용
- **타임아웃**: 5초 (ApiConstants.requestTimeoutSeconds)
- **에러 표시**: 사용자에게 에러 메시지 표시하지 않음 (백그라운드 처리)
- **성능 테스트**: 보강 타이밍 옵션별 성능 테스트 필요
- **일일 트래픽 제한**: 1,000건 (공공데이터포털 API 제한)

---

## 공공데이터포털 API 구현 가이드

### 1. 서비스 클래스 생성

**파일 위치**: `lib/api_request/public_data_broker_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/public_data_broker.dart';

class PublicDataBrokerService {
  /// 공공데이터포털 API로 공인중개사 검색
  static Future<PublicDataBrokerSearchResult> searchBrokers({
    double? latitude,
    double? longitude,
    int radiusMeters = 1000,
    int pageNo = 1,
    int numOfRows = 100,
    String? officeName,
    String? registrationNumber,
    String? roadAddress,
    String? representativeName,
  }) async {
    try {
      // 서비스 키 (Encoding 또는 Decoding 방식에 따라 선택)
      final serviceKey = ApiConstants.publicDataServiceKey;
      
      // API 요청 URL 구성 (HTTPS 사용)
      final uri = Uri.parse('https://api.data.go.kr/openapi/tn_pubr_public_med_office_api').replace(
        queryParameters: {
          'serviceKey': serviceKey,
          'pageNo': pageNo.toString(),
          'numOfRows': numOfRows.toString(),
          'type': 'json',
          if (officeName != null && officeName.isNotEmpty)
            'MED_OFFICE_NM': officeName,
          if (registrationNumber != null && registrationNumber.isNotEmpty)
            'ESTBL_REG_NO': registrationNumber,
          if (roadAddress != null && roadAddress.isNotEmpty)
            'LCTN_ROAD_NM_ADDR': roadAddress,
          if (representativeName != null && representativeName.isNotEmpty)
            'RPRSV_NM': representativeName,
        },
      );

      // 프록시를 통한 요청 (CORS 우회)
      final proxyUri = Uri.parse(
        '${ApiConstants.proxyRequstAddr}?q=${Uri.encodeComponent(uri.toString())}',
      );

      final response = await http.get(proxyUri).timeout(
        const Duration(seconds: ApiConstants.requestTimeoutSeconds),
      );

      if (response.statusCode == 200) {
        final jsonText = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonText);
        
        return _parseResponse(data, latitude, longitude, radiusMeters);
      } else {
        return PublicDataBrokerSearchResult(
          brokers: [],
          errorMessage: 'API 요청 실패: ${response.statusCode}',
        );
      }
    } catch (e) {
      return PublicDataBrokerSearchResult(
        brokers: [],
        errorMessage: '공공데이터 API 오류: ${e.toString()}',
      );
    }
  }

  /// 응답 파싱
  static PublicDataBrokerSearchResult _parseResponse(
    Map<String, dynamic> data,
    double? baseLat,
    double? baseLon,
    int radiusMeters,
  ) {
    try {
      final response = data['response'] as Map<String, dynamic>?;
      if (response == null) {
        return PublicDataBrokerSearchResult(
          brokers: [],
          errorMessage: '응답 형식 오류',
        );
      }

      final header = response['header'] as Map<String, dynamic>?;
      final resultCode = header?['resultCode']?.toString() ?? '';
      
      // 에러 코드 확인
      if (resultCode != '00') {
        final resultMsg = header?['resultMsg']?.toString() ?? '알 수 없는 오류';
        return PublicDataBrokerSearchResult(
          brokers: [],
          errorMessage: 'API 오류 ($resultCode): $resultMsg',
        );
      }

      final body = response['body'] as Map<String, dynamic>?;
      if (body == null) {
        return PublicDataBrokerSearchResult(
          brokers: [],
          errorMessage: '응답 본문 없음',
        );
      }

      final items = body['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) {
        return PublicDataBrokerSearchResult(
          brokers: [],
          totalCount: int.tryParse(body['totalCount']?.toString() ?? '0') ?? 0,
        );
      }

      final brokers = <PublicDataBroker>[];
      
      for (final item in items) {
        final brokerData = item as Map<String, dynamic>;
        
        // 좌표 추출
        final latStr = brokerData['LATITUDE']?.toString();
        final lonStr = brokerData['LONGITUDE']?.toString();
        
        double? latitude;
        double? longitude;
        double? distance;
        
        if (latStr != null && lonStr != null && 
            latStr.isNotEmpty && lonStr.isNotEmpty) {
          latitude = double.tryParse(latStr);
          longitude = double.tryParse(lonStr);
          
          // 거리 계산 (기준 좌표가 있는 경우)
          if (baseLat != null && baseLon != null && 
              latitude != null && longitude != null) {
            distance = _calculateHaversineDistance(
              baseLat, baseLon, latitude, longitude,
            );
            
            // 반경 이내만 포함
            if (distance > radiusMeters) {
              continue;
            }
          }
        }

        brokers.add(PublicDataBroker(
          officeName: brokerData['MED_OFFICE_NM']?.toString() ?? '',
          registrationNumber: brokerData['ESTBL_REG_NO']?.toString() ?? '',
          brokerType: brokerData['OPBIZ_LREA_CLSC_SE']?.toString() ?? '',
          roadAddress: brokerData['LCTN_ROAD_NM_ADDR']?.toString() ?? '',
          jibunAddress: brokerData['LCTN_LOTNO_ADDR']?.toString() ?? '',
          phoneNumber: brokerData['TELNO']?.toString() ?? '',
          registrationDate: brokerData['ESTBL_REG_YMD']?.toString() ?? '',
          insuranceJoinYn: brokerData['DDC_JOIN_YN']?.toString() ?? '',
          representativeName: brokerData['RPRSV_NM']?.toString() ?? '',
          latitude: latitude,
          longitude: longitude,
          distance: distance,
          assistantCount: int.tryParse(brokerData['MED_SPMBR_CNT']?.toString() ?? ''),
          brokerCount: int.tryParse(brokerData['OGDP_LREA_CNT']?.toString() ?? ''),
          homepage: brokerData['HMPG_ADDR']?.toString() ?? '',
          dataDate: brokerData['CRTR_YMD']?.toString() ?? '',
          institutionCode: brokerData['instt_code']?.toString() ?? '',
          institutionName: brokerData['instt_nm']?.toString() ?? '',
        ));
      }

      // 거리순 정렬
      brokers.sort((a, b) {
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return a.distance!.compareTo(b.distance!);
      });

      final totalCount = int.tryParse(body['totalCount']?.toString() ?? '0') ?? 0;

      return PublicDataBrokerSearchResult(
        brokers: brokers,
        totalCount: totalCount,
        pageNo: int.tryParse(body['pageNo']?.toString() ?? '1') ?? 1,
        numOfRows: int.tryParse(body['numOfRows']?.toString() ?? '100') ?? 100,
      );
    } catch (e) {
      return PublicDataBrokerSearchResult(
        brokers: [],
        errorMessage: '응답 파싱 오류: ${e.toString()}',
      );
    }
  }

  /// Haversine 공식으로 거리 계산 (미터 단위)
  static double _calculateHaversineDistance(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const R = 6371000.0; // 지구 반지름 (미터)
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLon = (lon2 - lon1) * 3.141592653589793 / 180;

    final a = (dLat / 2).sin() * (dLat / 2).sin() +
        (lat1 * 3.141592653589793 / 180).cos() *
        (lat2 * 3.141592653589793 / 180).cos() *
        (dLon / 2).sin() * (dLon / 2).sin();

    final c = 2 * (a.sqrt()).atan2((1 - a).sqrt());
    return R * c;
  }
}
```

### 2. 데이터 모델 파일 생성

**파일 위치**: `lib/models/public_data_broker.dart`

```dart
import '../models/broker.dart';

class PublicDataBroker {
  final String officeName;
  final String registrationNumber;
  final String brokerType;
  final String roadAddress;
  final String jibunAddress;
  final String phoneNumber;
  final String registrationDate;
  final String insuranceJoinYn;
  final String representativeName;
  final double? latitude;
  final double? longitude;
  final double? distance;
  final int? assistantCount;
  final int? brokerCount;
  final String homepage;
  final String dataDate;
  final String institutionCode;
  final String institutionName;

  PublicDataBroker({
    required this.officeName,
    required this.registrationNumber,
    required this.brokerType,
    required this.roadAddress,
    required this.jibunAddress,
    required this.phoneNumber,
    required this.registrationDate,
    required this.insuranceJoinYn,
    required this.representativeName,
    this.latitude,
    this.longitude,
    this.distance,
    this.assistantCount,
    this.brokerCount,
    required this.homepage,
    required this.dataDate,
    required this.institutionCode,
    required this.institutionName,
  });

  /// Broker 모델로 변환
  Broker toBroker() {
    return Broker(
      name: officeName,
      roadAddress: roadAddress,
      jibunAddress: jibunAddress,
      registrationNumber: registrationNumber,
      phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : null,
      ownerName: representativeName.isNotEmpty ? representativeName : null,
      latitude: latitude,
      longitude: longitude,
      distance: distance,
      registrationDate: registrationDate,
      businessStatus: insuranceJoinYn == 'Y' ? '영업중' : null,
    );
  }

  /// 전체 주소 (도로명 우선)
  String get fullAddress {
    if (roadAddress.isNotEmpty) {
      return jibunAddress.isNotEmpty 
          ? '$roadAddress\n지번 $jibunAddress'
          : roadAddress;
    }
    return jibunAddress;
  }

  /// 거리 텍스트 포맷
  String get distanceText {
    if (distance == null) return '';
    if (distance! >= 1000) {
      final km = distance! / 1000;
      return km == km.roundToDouble() 
          ? '${km.toStringAsFixed(0)}km'
          : '${km.toStringAsFixed(1)}km';
    }
    return '${distance!.toStringAsFixed(0)}m';
  }
}

class PublicDataBrokerSearchResult {
  final List<PublicDataBroker> brokers;
  final int totalCount;
  final int pageNo;
  final int numOfRows;
  final String? errorMessage;

  PublicDataBrokerSearchResult({
    required this.brokers,
    this.totalCount = 0,
    this.pageNo = 1,
    this.numOfRows = 100,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
  bool get isEmpty => brokers.isEmpty && !hasError;
}
```

### 3. 상수 추가

**파일 위치**: `lib/constants/app_constants.dart`

```dart
class ApiConstants {
  // ... 기존 상수들 ...
  
  /// 공공데이터포털 서비스 키
  /// Encoding 또는 Decoding 방식에 따라 선택하여 사용
  /// Encoding: lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh%2BTl1KORZJXQTqih1BTBLpxfdixxY0mUQ%3D%3D
  /// Decoding: lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==
  static const String publicDataServiceKey = String.fromEnvironment(
    'PUBLIC_DATA_SERVICE_KEY',
    defaultValue: '',
  );
  
  /// 공공데이터포털 API 엔드포인트
  static const String publicDataBrokerApiUrl = 
      'https://api.data.go.kr/openapi/tn_pubr_public_med_office_api';
}
```

---

## 참고 파일

- `lib/api_request/address_service.dart` - 주소검색 서비스
- `lib/api_request/vworld_service.dart` - VWorld API 서비스
- `lib/api_request/broker_service.dart` - 공인중개사 검색 서비스
- `lib/api_request/public_data_broker_service.dart` - 공공데이터포털 API 서비스
- `lib/api_request/broker_verification_service.dart` - 공공데이터 포털 전국공인중개사사무소표준데이터 보강 서비스
- `lib/models/public_data_broker.dart` - 공공데이터포털 API 데이터 모델
- `lib/screens/home_page.dart` - 홈 화면 (주소검색 UI)
- `lib/screens/broker_list_page.dart` - 공인중개사 목록 화면
- `lib/constants/app_constants.dart` - API 상수 정의
- `lib/widgets/address_search/address_search_tabs.dart` - 주소 검색 탭 컨테이너 (GPS/주소 입력)
- `lib/widgets/address_search/gps_based_search_tab.dart` - GPS 기반 검색 탭
- `lib/widgets/address_search/address_input_tab.dart` - 주소 입력 검색 탭
- `lib/widgets/address_search/address_search_result.dart` - 주소 검색 결과 모델 (`SelectedAddressResult`)
- `lib/widgets/region_selection/region_selection_section.dart` - GPS 기반 지역 선택 섹션
- `lib/widgets/region_selection/distance_slider_widget.dart` - 반경 슬라이더 위젯
- `lib/widgets/region_selection_map.dart` - 지역 선택 지도 위젯

---

## 변경 이력

- 2025-01-XX: 용어 통일 및 게스트 모드 개선
  - 모든 문의 기능을 "문의"로 통일
  - 비대면 문의(개별 문의) 게스트 모드 지원 추가
  - 계정 생성 실패 시 문의 중단 처리 개선
  - SubmitSuccessPage에서 게스트 모드 계정 처리 개선
  - 세 가지 문의 방법의 로직 통일 (transactionType, 확인할 견적 정보 등)
- 2025-01-XX: 초기 문서 작성
- 2025-01-XX: 공공데이터포털 전국공인중개사사무소 표준데이터 API 통합 추가
- 2025-01-XX: 공공데이터 포털 전국공인중개사사무소표준데이터 보강 기능 추가 (등록번호 기반 정보 보강)
- 2025-01-XX: 주소 입력 검색 탭에 지도 및 반경 슬라이더 추가
  - 주소 입력 검색 탭에 `RegionSelectionMap` 통합
  - 선택한 주소 위치로 지도 자동 이동
  - GPS 탭과 동일한 반경 슬라이더 추가 (300m, 500m, 1km, 1.5km)
  - `SelectedAddressResult` 모델에 `radiusMeters` 필드 추가
- 2025-01-XX: 사용자 선택 반경이 공인중개사 검색에 반영되도록 개선
  - `BrokerListPage`에 `radiusMeters` 파라미터 추가
  - `home_page.dart`에서 선택한 반경을 `BrokerListPage`로 전달
  - 하드코딩된 1km 반경 대신 사용자가 선택한 반경 사용
- 2025-01-XX: 지도 이동 시 주소 자동 업데이트 기능 개선
  - JavaScript 객체를 Dart Map으로 변환하는 로직 추가
  - 메시지 리스너 디버깅 로그 추가
  - 지도 이동(`moveend` 이벤트) 시 주소 자동 조회 기능 안정화
- 2025-01-XX: GPS 탭 가변 높이 측정 및 overflow 문제 해결
  - `AddressSearchTabs`의 높이 측정 로직 개선
  - `IntrinsicHeight`를 사용한 정확한 콘텐츠 높이 측정
  - maxHeight 제한 제거로 가변 높이 자동 확장 지원
  - 스크롤 없이 높이가 콘텐츠에 맞게 자동 확장되도록 개선
  - GPS 탭 여유 공간 80px, 주소 입력 탭 40px로 설정하여 overflow 방지
  - 높이 측정을 여러 번 수행하여 정확도 향상 (300ms, 600ms 지연 재측정)
  - 콘텐츠 변경 시 자동 높이 재측정 기능 추가

---

## 문의

구현 관련 문의사항이 있으면 개발팀에 문의하세요.

