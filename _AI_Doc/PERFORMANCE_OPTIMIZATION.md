# 🚀 성능 최적화 가이드

> **최종 업데이트**: 2025-01-27  
> **작성일**: 2025-01-27  
> **상태**: 주요 최적화 완료, 추가 최적화 계획 수립

---

## 📊 현재 상태 요약

### ✅ 완료된 최적화

#### 1. Firebase 초기화 최적화 ✅
- Firebase 초기화 비동기 처리
- 즉시 UI 표시 (2초 타임아웃)
- Firestore 쿼리 비동기 처리
- 웹 로딩 타임아웃 단축 (5초)

#### 2. 이미지 최적화 구현 ✅
- `OptimizedNetworkImage` 위젯 생성 및 적용 완료
- `OptimizedImageGallery` 위젯 생성 및 적용 완료
- 웹 최적화: `cacheWidth`, `cacheHeight` 설정
- 자동 캐싱 지원
- 로딩 상태 및 에러 처리

**적용 위치:**
- ✅ `lib/widgets/optimized_image.dart` (위젯 구현)
- ✅ `lib/screens/broker/broker_property_detail_page.dart` (OptimizedImageGallery 사용)
- ✅ `lib/screens/propertySale/buyer_property_detail_page.dart` (OptimizedImageGallery 사용)
- ✅ `lib/screens/broker/property_edit_form_page.dart` (OptimizedNetworkImage 사용)

**실제 효과:**
- 이미지 로딩 시간: **-30~50%** (예상)
- 메모리 사용량: **-40~60%** (예상)
- 대역폭 사용: **-50~70%** (예상)

#### 3. 이미지 캐시 크기 제한 ✅
- `lib/main.dart`에 이미지 캐시 제한 추가
- 최대 캐시 이미지 수: 100개
- 최대 캐시 크기: 50MB

**코드:**
```dart
PaintingBinding.instance.imageCache.maximumSize = 100;
PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
```

**예상 효과:**
- 메모리 사용량: **-30~50%**
- 앱 안정성: **향상**

#### 4. 불필요한 파일 제거 ✅
- `web/gocleansetup153.exe` 제거
- `web/VisualStudioSetup.exe` 제거

**예상 효과:**
- 웹 번들 크기: **-수 MB**
- 배포 속도: **향상**

---

## 🔴 긴급 최적화 필요 (높은 영향도)

### 1. 이미지 최적화 추가 작업 ⚠️

**남은 작업:**
- `web/BigLogo.jpg`, `web/SmallLogo.jpg`, `web/icon.jpg` 압축
- WebP 형식으로 변환
- 이미지 lazy loading 미적용

**해결 방안:**
```dart
// 이미지 캐싱 추가
Image.network(
  imageUrl,
  cacheWidth: 800,  // 웹 최적화
  cacheHeight: 600,
  loadingBuilder: (context, child, progress) {
    if (progress == null) return child;
    return ShimmerPlaceholder(); // 스켈레톤 UI
  },
)
```

**예상 개선:**
- 초기 로딩 시간: **-30~50%**
- 대역폭 사용: **-60~70%**

### 2. ListView 성능 이슈 ⚠️

**문제점:**
```dart
// lib/screens/propertySale/house_market_page.dart:403
ListView.builder(
  shrinkWrap: true,  // ❌ 성능 저하
  physics: const NeverScrollableScrollPhysics(),
  itemCount: _properties.length,
)
```

**영향:**
- `shrinkWrap: true`는 모든 아이템을 한 번에 렌더링
- 스크롤 성능 저하
- 메모리 사용량 증가

**해결 방안:**
```dart
// Column 내부가 아닌 경우
Expanded(
  child: ListView.builder(
    // shrinkWrap 제거
    itemCount: _properties.length,
    itemBuilder: (context, index) => _buildPropertyCard(_properties[index]),
  ),
)

// 또는 SliverList 사용
CustomScrollView(
  slivers: [
    SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildPropertyCard(_properties[index]),
        childCount: _properties.length,
      ),
    ),
  ],
)
```

**예상 개선:**
- 스크롤 성능: **+200~300%**
- 메모리 사용: **-40~50%**

**남은 작업 위치 (확인됨):**
- ⚠️ `lib/screens/propertySale/house_market_page.dart:404` (shrinkWrap: true)
- ⚠️ `lib/screens/propertyMgmt/house_management_page.dart:1840` (확인 필요)
- ⚠️ `lib/screens/quote_history_page.dart:1473` (shrinkWrap: true)
- ⚠️ `lib/screens/broker/property_registration_form_page.dart:1012` (확인 필요)
- ⚠️ `lib/screens/broker/property_edit_form_page.dart:915, 978` (확인 필요)

**참고:** 일부 위치에서는 `shrinkWrap: true`가 Column 내부에서 필요할 수 있으므로, 각 위치를 개별적으로 검토하여 최적화 여부를 결정해야 합니다.

### 3. setState 과다 호출 ⚠️

**문제점:**
- 전체 프로젝트에서 `setState` 호출 **262회**
- 불필요한 전체 위젯 트리 리빌드 발생

**영향:**
- UI 프레임 드롭
- 배터리 소모 증가
- 사용자 경험 저하

**해결 방안:**
```dart
// 1. const 위젯 사용
const Text('고정 텍스트')

// 2. ValueNotifier 사용 (부분 업데이트)
final _counter = ValueNotifier<int>(0);
ValueListenableBuilder<int>(
  valueListenable: _counter,
  builder: (context, value, child) => Text('$value'),
)

// 3. setState 범위 최소화
setState(() {
  // 최소한의 상태만 업데이트
  _isLoading = false;
});
```

**예상 개선:**
- 프레임 레이트: **+30~50%**
- 배터리 수명: **+20~30%**

### 4. 웹 번들 크기 최적화 부족 ⚠️

**문제점:**
- Tree-shaking 미확인
- 코드 스플리팅 없음
- 불필요한 패키지 포함 가능성

**빌드 최적화:**
```bash
# 웹 빌드 최적화
flutter build web --release --tree-shake-icons --web-renderer canvaskit

# 또는 HTML 렌더러 사용 (더 작은 번들)
flutter build web --release --web-renderer html
```

**예상 개선:**
- 번들 크기: **-20~40%**
- 초기 로딩: **-15~25%**

---

## 🟡 중요 최적화 (중간 영향도)

### 5. API 요청 최적화

**현재 상태:**
- `AptInfoService`에 캐싱 구현됨 ✅
- `AddressService`에 캐싱 없음 ❌

**개선 방안:**
```dart
// AddressService에 캐싱 추가
class AddressService {
  static final Map<String, CachedResult> _cache = {};
  static const Duration _cacheTTL = Duration(minutes: 5);
  
  Future<AddressSearchResult> searchRoadAddress(String keyword) async {
    final cacheKey = keyword.toLowerCase().trim();
    final cached = _cache[cacheKey];
    
    if (cached != null && !cached.isExpired) {
      return cached.result;
    }
    
    final result = await _fetchAddress(keyword);
    _cache[cacheKey] = CachedResult(result, DateTime.now());
    return result;
  }
}
```

**예상 개선:**
- API 호출 감소: **-40~60%**
- 응답 시간: **-50~80%** (캐시 히트 시)

### 6. 이미지 Lazy Loading 부족

**문제점:**
- 모든 이미지가 즉시 로드됨
- 화면 밖 이미지도 다운로드

**해결 방안:**
```dart
// Lazy loading 구현
class LazyImage extends StatelessWidget {
  final String imageUrl;
  final bool isVisible;
  
  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return Container(); // 플레이스홀더
    }
    return Image.network(imageUrl);
  }
}
```

**예상 개선:**
- 초기 로딩: **-20~30%**
- 대역폭: **-50~70%**

### 7. Service Worker 없음

**문제점:**
- 오프라인 지원 없음
- 리소스 캐싱 없음
- 재방문 시 모든 리소스 재다운로드

**해결 방안:**
```dart
// workbox 또는 flutter service worker 사용
// web/sw.js 생성 필요
```

**예상 개선:**
- 재방문 로딩: **-80~90%**
- 오프라인 지원: ✅

### 8. 폰트 최적화

**현재 상태:**
- NotoSansKR 6개 weight 사용 (400, 500, 600, 700, 800, 900)
- 모든 weight가 번들에 포함됨

**개선 방안:**
```yaml
# pubspec.yaml
fonts:
  - family: NotoSansKR
    fonts:
      # 실제 사용하는 weight만 유지
      - asset: assets/fonts/static/NotoSansKR-Regular.ttf
        weight: 400
      - asset: assets/fonts/static/NotoSansKR-Bold.ttf
        weight: 700
      # 500, 600, 800, 900 제거 (사용하지 않는 경우)
```

**예상 개선:**
- 번들 크기: **-2~5MB** (폰트 파일)

---

## 🟢 선택적 최적화 (낮은 영향도)

### 9. 빌드 설정 최적화

**추가 설정:**
```dart
// main.dart
void main() {
  // 디버그 모드에서만 로깅
  if (kDebugMode) {
    Logger.setLevel(LogLevel.debug);
  } else {
    Logger.setLevel(LogLevel.warning);
  }
}
```

### 10. 웹 리소스 최적화

**문제점:**
- `web/sqflite_sw.js`, `web/sql-wasm.js` 사용 여부 미확인

**해결 방안:**
```bash
# 사용하지 않는 JS 파일 확인 후 제거
```

---

## 📋 우선순위별 작업 계획

### Phase 1: 긴급 (1주일 내)
1. ✅ Firebase 초기화 최적화 (완료)
2. ✅ 이미지 최적화 기본 구현 (완료)
3. ⚠️ 이미지 압축 및 WebP 변환
4. ⚠️ ListView `shrinkWrap` 제거
5. ⚠️ setState 최적화 (const 위젯, ValueNotifier)

### Phase 2: 중요 (2주일 내)
6. API 요청 캐싱 강화
7. 이미지 Lazy Loading 구현
8. 웹 번들 크기 최적화

### Phase 3: 선택적 (1개월 내)
9. Service Worker 구현
10. 폰트 서브셋팅
11. 메모리 최적화
12. 불필요한 파일 제거

---

## 📊 예상 성능 개선 효과

| 항목 | 현재 | 개선 후 | 개선율 |
|------|------|---------|--------|
| 초기 로딩 시간 | 60초+ | 3~5초 | **-92~95%** |
| 번들 크기 | 미측정 | -20~40% | **-20~40%** |
| 스크롤 성능 | 느림 | 부드러움 | **+200~300%** |
| API 호출 | 많음 | 최소화 | **-40~60%** |
| 메모리 사용 | 높음 | 최적화 | **-40~50%** |
| 이미지 로딩 시간 | 느림 | 빠름 | **-30~50%** |
| 대역폭 사용 | 많음 | 최적화 | **-50~70%** |

---

## 🔧 사용 방법

### OptimizedNetworkImage 사용
```dart
OptimizedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  width: 300,
  height: 200,
  fit: BoxFit.cover,
  borderRadius: BorderRadius.circular(12),
)
```

### OptimizedImageGallery 사용
```dart
OptimizedImageGallery(
  imageUrls: ['url1', 'url2', 'url3'],
  height: 300,
  borderRadius: BorderRadius.circular(12),
)
```

### 이미지 최적화 스크립트
```bash
# 이미지 압축 (TinyPNG API 사용)
# 또는 Squoosh CLI 사용
npx @squoosh/cli --webp auto web/*.jpg

# WebP 변환
cwebp -q 80 web/BigLogo.jpg -o web/BigLogo.webp
```

### 빌드 최적화 명령어
```bash
# 최적화된 웹 빌드
flutter build web --release \
  --web-renderer html \
  --tree-shake-icons \
  --dart-define=FLUTTER_WEB_USE_SKIA=false

# 번들 크기 분석
flutter build web --release --analyze-size
```

---

## 📝 체크리스트

### 즉시 수행
- [x] 이미지 최적화 기본 구현
- [x] 이미지 캐시 크기 제한
- [x] 불필요한 파일 제거 (`web/*.exe`)
- [ ] 이미지 파일 압축 (WebP 변환)
- [ ] ListView `shrinkWrap` 제거
- [ ] 빌드 크기 분석 실행

### 단기 (1주일)
- [ ] setState 최적화 (const 위젯 추가)
- [ ] 이미지 압축 및 WebP 변환
- [ ] API 캐싱 강화
- [ ] 웹 번들 최적화 빌드 테스트

### 중기 (1개월)
- [ ] Service Worker 구현
- [ ] 폰트 서브셋팅
- [ ] Lazy Loading 구현
- [ ] 성능 모니터링 설정

---

**최종 업데이트**: 2025-01-27  
**상태**: 주요 최적화 완료, 추가 최적화 계획 수립

