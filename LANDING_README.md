# 🎯 랜딩 페이지 가이드

## 📋 개요

새로운 랜딩 페이지가 생성되었습니다. 기획서에 따라 Hero, Problem, Solution, Process, Benefit, Final CTA 섹션을 포함하고 있습니다.

## 📁 파일 구조

```
landing.html    # 랜딩 페이지 HTML
landing.css     # 랜딩 페이지 스타일시트
landing.js      # 랜딩 페이지 JavaScript
```

## 🚀 사용 방법

### 1. 구글 시트 URL 설정

`landing.js` 파일의 `GOOGLE_SHEET_URL` 변수를 실제 구글 시트 URL로 변경하세요:

```javascript
const GOOGLE_SHEET_URL = 'https://docs.google.com/forms/d/YOUR_FORM_ID/viewform';
```

### 2. 서버 실행

```bash
npm start
```

### 3. 접속

- **랜딩 페이지**: http://localhost:8080
- **검색 페이지**: http://localhost:8080/search

## 🎨 디자인 특징

- **컬러**: Deep Blue (#1e3a8a) + White + Light Gray
- **폰트**: Pretendard (고딕 계열)
- **반응형**: 모바일 최적화 완료
- **애니메이션**: 스크롤 시 부드러운 fade-in 효과

## 📱 섹션 구성

1. **Hero**: 메인 헤드라인 + CTA 버튼
2. **Problem**: 고통 포인트 3가지
3. **Solution**: 서비스 메커니즘 시각화
4. **Process**: 3단계 프로세스
5. **Benefit**: 신뢰 및 편의성 4가지
6. **Final CTA**: 마지막 행동 유도

## ⚙️ 커스터마이징

### 구글 시트 연결

`landing.js`의 `goToConditionForm()` 함수를 수정하여 원하는 동작을 설정할 수 있습니다:

```javascript
function goToConditionForm() {
    // 옵션 1: 새 창에서 열기
    window.open(GOOGLE_SHEET_URL, '_blank');
    
    // 옵션 2: 현재 창에서 열기
    // window.location.href = GOOGLE_SHEET_URL;
    
    // 옵션 3: 기존 검색 페이지로 이동
    // window.location.href = '/search';
}
```

### 통계 숫자 변경

`landing.html`의 `.hero-stats` 섹션에서 숫자를 변경할 수 있습니다:

```html
<div class="stat-number">0</div>  <!-- 허위 매물 -->
<div class="stat-number">100%</div>  <!-- 검증된 중개사 -->
<div class="stat-number">1회</div>  <!-- 조건 입력 -->
```

## 🔧 추가 기능

### 스크롤 애니메이션

- Intersection Observer API 사용
- 요소가 화면에 보일 때 자동으로 fade-in 애니메이션 실행

### 반응형 디자인

- 모바일: 480px 이하
- 태블릿: 768px 이하
- 데스크톱: 768px 이상

## 📝 TODO

- [ ] 실제 구글 시트 URL 설정
- [ ] 통계 숫자 실제 데이터로 업데이트
- [ ] A/B 테스트를 위한 CTA 버튼 텍스트 변경 옵션 추가
- [ ] Google Analytics 연동 (선택사항)

## 🎯 다음 단계

1. 구글 시트 폼 생성 및 URL 설정
2. 랜딩 페이지 테스트
3. 실제 데이터로 통계 업데이트
4. SEO 최적화 (meta 태그 추가)

---

**작성일**: 2025년
**버전**: 1.0.0


