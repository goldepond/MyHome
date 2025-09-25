# 🏠 House MVP - 부동산 검색 웹 애플리케이션

> **한국의 공공 API를 활용한 부동산 검색 MVP 웹 애플리케이션**

## 📋 프로젝트 개요

House MVP는 한국의 공공 데이터 포털 API를 활용하여 부동산 정보를 검색하고 상세 정보를 제공하는 웹 애플리케이션입니다. 사용자가 주소를 입력하면 해당 지역의 아파트 정보와 상세 정보를 자동으로 조회하여 제공합니다.

## ✨ 주요 기능

### 🔍 **주소 검색**
- 도로명주소 검색 API를 활용한 정확한 주소 검색
- 실시간 검색 결과 표시
- 검색 결과 클릭 시 상세 정보 페이지로 이동

### 📊 **상세 정보 제공**
- **선택된 주소 정보**: 도로명주소, 지번주소, 우편번호 등
- **행정구역 정보**: 행정안전부 행정표준코드 API 활용
- **아파트 목록**: 해당 주소의 아파트 단지 목록
- **아파트 상세 정보**: 관리 정보, 시설 정보, 교통 정보 등

### 🎨 **사용자 인터페이스**
- 깔끔하고 현대적인 디자인
- 하늘색-보라색 그라데이션 배경
- 반응형 디자인으로 모바일 지원
- 직관적인 사용자 경험

## 🛠️ 기술 스택

### **Frontend**
- **HTML5**: 시맨틱 마크업
- **CSS3**: Flexbox, Grid, 애니메이션
- **Vanilla JavaScript**: ES6+ 문법, async/await
- **Font**: Noto Sans KR (한글 최적화)

### **Backend**
- **Node.js**: 서버 런타임
- **Express.js**: 웹 프레임워크
- **http-proxy-middleware**: CORS 프록시
- **cors**: Cross-Origin Resource Sharing

### **API 연동**
- **도로명주소 검색 API**: 주소 검색
- **행정안전부 행정표준코드 API**: 행정구역 정보
- **공동주택 단지 목록제공 서비스 API**: 아파트 목록
- **공동주택 상세 정보제공 서비스 API**: 아파트 상세 정보
- **건물등기정보제공 서비스 API**: 건물 정보

## 📁 프로젝트 구조

```
houseMvpProject/
├── index.html              # 메인 페이지
├── result.html              # 결과 페이지
├── styles.css               # 스타일시트
├── script.js                # 메인 JavaScript
├── result.js                # 결과 페이지 JavaScript
├── proxy-server.js          # 프록시 서버
├── package.json             # 프로젝트 설정
└── README.md               # 프로젝트 문서
```

## 🚀 설치 및 실행

### **1. 의존성 설치**
```bash
npm install
```

### **2. 프록시 서버 실행**
```bash
npm run proxy
```

### **3. 웹 서버 실행**
```bash
npm run dev
```

### **4. 개발 환경 (동시 실행)**
```bash
npm run dev:full
```

## 🌐 접속 방법

- **메인 페이지**: http://localhost:3000
- **프록시 서버**: http://localhost:3001

## 📡 API 엔드포인트

### **프록시 서버 엔드포인트**
- `/api/juso` - 도로명주소 검색
- `/api/region` - 행정구역코드 조회
- `/api/apt` - 아파트 목록 조회
- `/api/apt-detail` - 아파트 상세 정보 조회
- `/api/building` - 건물 정보 조회

## 🔧 설정

### **API 키 설정**
각 API의 인증키는 다음과 같이 설정되어 있습니다:

```javascript
// 도로명주소 검색 API
const JUSO_API_CONFIG = {
    confmKey: 'devU01TX0FVVEgyMDI1MDkwNDE5NDkzNDExNjE1MTQ='
};

// 공공 데이터 포털 API
const API_KEY = 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==';
```

## 📱 사용 방법

### **1. 주소 검색**
1. 메인 페이지에서 원하는 주소를 입력
2. "검색" 버튼 클릭
3. 검색 결과에서 원하는 주소 클릭

### **2. 상세 정보 확인**
1. 결과 페이지에서 선택된 주소 정보 확인
2. 행정구역 정보 자동 표시
3. 해당 주소의 아파트 목록 확인
4. 첫 번째 아파트의 상세 정보 자동 표시
5. 건물 정보 자동 표시 (용도, 구조, 면적, 규모, 주차, 건축 정보, 인증 정보)

## 🎨 디자인 특징

### **색상 팔레트**
- **주 색상**: 하늘색 (#87CEEB) → 보라색 (#8b5cf6) 그라데이션
- **보조 색상**: 흰색, 회색 계열
- **강조 색상**: 보라색 (#8b5cf6)

### **타이포그래피**
- **한글 폰트**: Noto Sans KR
- **가중치**: 300, 400, 500, 700
- **반응형 폰트 크기**

### **레이아웃**
- **Flexbox**: 유연한 레이아웃
- **CSS Grid**: 카드형 정보 표시
- **반응형 디자인**: 모바일 최적화

## 🔍 주요 기능 상세

### **주소 검색 기능**
- 실시간 검색어 유효성 검사
- 특수문자 및 SQL 예약어 필터링
- 로딩 상태 표시
- 에러 처리 및 사용자 피드백

### **API 연동**
- CORS 문제 해결을 위한 프록시 서버
- 비동기 API 호출 (async/await)
- 에러 핸들링 및 재시도 로직
- 상세한 로깅 및 디버깅
- 5개 공공 API 통합 연동

### **데이터 처리**
- JSON 데이터 파싱 및 변환
- 주소 정보 필터링 및 매칭
- 동적 HTML 생성 및 DOM 조작
- URL 파라미터를 통한 데이터 전달
- 행정구역코드 분할 처리 (시군구코드 + 법정동코드)

## 🚀 배포

### **GitHub Pages 배포**
```bash
npm run deploy
```

### **로컬 서버 배포**
```bash
npm run build
npm start
```

## 📝 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다.

## 🤝 기여

프로젝트 개선을 위한 기여를 환영합니다!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📞 문의

프로젝트에 대한 문의사항이 있으시면 언제든지 연락주세요.

---

**House MVP** - 한국의 공공 API를 활용한 부동산 검색 플랫폼 🏠