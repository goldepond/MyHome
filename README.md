# 🏠 House MVP - 부동산 검색 웹 애플리케이션

> **한국의 공공 API를 활용한 부동산 검색 MVP 웹 애플리케이션**

## 📋 프로젝트 개요

House MVP는 한국의 공공 데이터 포털 API를 활용하여 부동산 정보를 검색하고 상세 정보를 제공하는 웹 애플리케이션입니다. 사용자가 주소를 입력하면 해당 지역의 건물 정보, 토지 특성, 주변 공인중개사 정보를 자동으로 조회하여 제공합니다.

## ✨ 주요 기능

### 🔍 **스마트 주소 검색**
- 도로명주소 검색 API를 활용한 정확한 주소 검색
- **최근 검색 5개** 자동 저장 및 빠른 접근
- **즐겨찾기** 기능 (최대 20개 저장)
- **공유 링크** 생성 (주소가 미리 채워진 URL)
- Enter 키 지원 및 실시간 검색 결과 표시

### 📊 **상세 정보 제공**
- **주소 요약 카드**: 도로명주소, 지번주소, 우편번호, 좌표, PNU(필지고유번호)
- **건물 정보**: 용도, 구조, 면적, 규모, 주차, 건축 정보
- **토지 특성**: VWorld API를 통한 토지이용계획, 공시지가, 용도지역
- **리스크 배지**: 📏 면적, 🗺️ 용도지역, 💰 공시지가 (연도 포함)
- **데이터 기준일** 표시: 📅 YYYY년 MM월

### 🏘️ **주변 공인중개사 찾기**
- **거리순 정렬**: Haversine 공식으로 실제 거리 계산
- **상위 3곳 우선 표시**: 가장 가까운 중개사 먼저
- **전체 보기**: 최대 30곳까지 확인 가능
- **액션 버튼**: 📞 전화하기, 🗺️ 길찾기(카카오맵), ⭐ 저장하기

### 🎨 **사용자 인터페이스**
- 깔끔하고 현대적인 디자인
- 하늘색-보라색 그라데이션 배경
- 반응형 디자인으로 모바일 최적화
- 로딩 애니메이션 및 점진적 데이터 로드

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
- **도로명주소 검색 API** (Juso): 주소 검색
- **건축물대장 정보조회 API** (Data.go.kr): 건물 정보
- **VWorld Geocoder API**: 좌표 변환
- **VWorld 토지특성 공간정보 API**: 토지 이용계획, 공시지가
- **VWorld 부동산중개업 WFS API**: 주변 공인중개사 정보

## 📁 프로젝트 구조

```
houseMvpProject/
├── index.html              # 메인 페이지 (검색)
├── result.html             # 결과 페이지 (상세정보)
├── broker.html             # 공인중개사 페이지
├── styles.css              # 통합 스타일시트
├── script.js               # 메인 JavaScript
├── result.js               # 결과 페이지 JavaScript
├── broker.js               # 공인중개사 JavaScript
├── proxy-server.js         # CORS 프록시 서버
├── package.json            # 프로젝트 설정
└── README.md               # 프로젝트 문서
```

## 🚀 설치 및 실행

### **1. 의존성 설치**
```bash
npm install
```

### **2. 서버 실행 (필수!)**

⚠️ **중요**: Firebase 인증을 사용하려면 반드시 HTTP 서버로 실행해야 합니다.
`file://` 프로토콜에서는 Firebase가 작동하지 않습니다!

#### **옵션 1: 추천! (모든 서버 동시 실행)**
```bash
# 터미널 1: 프록시 서버 (포트 3001)
npm run proxy

# 터미널 2: 웹 서버 (포트 8080)
npm start
```

#### **옵션 2: 프록시만 실행 (Firebase 없이 테스트)**
```bash
npm run proxy
```

## 🌐 접속 방법

### **Firebase 인증 사용 시 (로그인/회원가입)**
- **메인 페이지**: http://localhost:8080
- **프록시 서버**: http://localhost:3001

⚠️ **주의**: `file:///D:/houseMvpProject/index.html`로 직접 열면 Firebase 인증이 작동하지 않습니다!

### **Firebase 없이 테스트**
- 프록시 서버만 실행하고 HTML 파일을 직접 열어도 됩니다.
- 단, 로그인/회원가입 기능은 사용할 수 없습니다.

## 📡 API 엔드포인트

### **프록시 서버 엔드포인트**
- `/api/juso` - 도로명주소 검색
- `/api/building` - 건물 정보 조회
- `/api/land` - 토지특성 공간정보 조회
- `/api/broker` - 부동산중개업 조회

## 🔧 설정

### **Firebase 설정 (필수)**

Firebase Authentication을 사용하려면 다음 단계를 따라주세요:

#### **1. Firebase 프로젝트 생성**
1. [Firebase Console](https://console.firebase.google.com/) 접속
2. "프로젝트 추가" 클릭
3. 프로젝트 이름 입력 (예: "HouseMVP")
4. Google Analytics 설정 (선택사항)

#### **2. 웹 앱 등록**
1. 프로젝트 개요 > 웹 앱 추가 (`</>` 아이콘)
2. 앱 닉네임 입력 (예: "HouseMVP Web")
3. Firebase Hosting 설정 (선택사항)

#### **3. 구성 정보 복사**
1. 표시되는 `firebaseConfig` 객체 복사
2. `firebase-config.js` 파일 열기
3. `firebaseConfig` 객체를 실제 값으로 교체

```javascript
const firebaseConfig = {
    apiKey: "YOUR_ACTUAL_API_KEY",
    authDomain: "your-project-id.firebaseapp.com",
    projectId: "your-project-id",
    storageBucket: "your-project-id.appspot.com",
    messagingSenderId: "123456789",
    appId: "1:123456789:web:abcdef123456"
};
```

#### **4. Authentication 활성화**
1. 좌측 메뉴 > **Authentication** > **시작하기**
2. **Sign-in method** 탭 선택
3. **이메일/비밀번호** 활성화
4. **Google** 활성화 (프로젝트 지원 이메일 입력 필요)

#### **5. Firestore Database 생성**
1. 좌측 메뉴 > **Firestore Database** > **데이터베이스 만들기**
2. 보안 규칙: **테스트 모드**로 시작 (개발용)
3. 위치: `asia-northeast3 (서울)` 권장

#### **6. 보안 규칙 설정** (중요!)
Firestore Database > 규칙 탭에서 다음 규칙 적용:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 사용자는 자신의 데이터만 읽기/쓰기 가능
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

#### **7. 도메인 승인**
1. Authentication > **Settings** > **승인된 도메인**
2. `localhost` (자동 추가됨)
3. GitHub Pages 도메인 추가 (예: `username.github.io`)

---

### **API 키 설정**
각 API의 인증키는 다음과 같이 설정되어 있습니다:

```javascript
// 도로명주소 검색 API
const JUSO_API_CONFIG = {
    confmKey: 'devU01TX0FVVEgyMDI1MDkwNDE5NDkzNDExNjE1MTQ='
};

// 공공 데이터 포털 API
const API_KEY = 'lkFNy5FKYttNQrsdPfqBSmg8frydGZUlWeH5sHrmuILv0cwLvMSCDh+Tl1KORZJXQTqih1BTBLpxfdixxY0mUQ==';

// VWorld API
const VWORLD_API_KEY = 'FA0D6750-3DC2-3389-B8F1-0385C5976B96';
```

## 📱 사용 방법

### **1. 주소 검색**
1. 메인 페이지에서 원하는 주소를 입력 (또는 최근 검색/즐겨찾기 선택)
2. Enter 키 또는 "검색" 버튼 클릭
3. 검색 결과에서 원하는 주소 클릭
4. 동/호수 정보 입력 (선택사항)

### **2. 상세 정보 확인**
1. **주소 요약 카드**: 기본 정보 즉시 표시
   - 도로명주소, 지번주소, 우편번호
   - 좌표 (위도, 경도) - 로딩 후 업데이트
   - PNU (필지고유번호) - 자동 계산
   - 데이터 기준일 표시
2. **액션 버튼**:
   - ⭐ 즐겨찾기: 자주 찾는 주소 저장
   - 📋 복사: 주소 정보 클립보드 복사
   - 🔗 공유: 공유 링크 생성
3. **토지 배지**: 면적, 용도지역, 공시지가 표시
4. **상세정보 보기/닫기**: 원본 API 데이터 토글

### **3. 공인중개사 찾기**
1. "공인중개사 찾기" 버튼 클릭
2. 거리순 정렬된 주변 중개사 목록 확인
3. **가까운 3곳** 또는 **전체 보기 (최대 30곳)** 선택
4. 각 중개사 카드에서:
   - 📞 전화하기
   - 🗺️ 길찾기 (카카오맵 연동)
   - ⭐ 저장하기 (북마크)

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

### **스마트 주소 검색**
- 실시간 검색어 유효성 검사
- 특수문자 및 SQL 예약어 필터링
- **최근 검색 기록**: localStorage에 자동 저장 (최대 10개)
- **즐겨찾기**: 자주 찾는 주소 북마크 (최대 20개)
- **공유 링크**: 주소가 미리 채워진 URL 생성
- Enter 키 지원 및 로딩 상태 표시

### **API 연동**
- **환경 자동 감지**: 로컬(프록시) / 웹(직접 호출) 자동 전환
- **HTTPS 지원**: 모든 VWorld API HTTPS 사용
- 비동기 API 호출 (async/await)
- 에러 핸들링 및 재시도 로직
- 상세한 로깅 및 디버깅
- **5개 공공 API 통합 연동**:
  1. 도로명주소 검색 API
  2. 건축물대장 정보조회 API
  3. VWorld Geocoder API
  4. VWorld 토지특성 공간정보 API
  5. VWorld 부동산중개업 WFS API

### **데이터 처리**
- JSON/XML 데이터 파싱 및 변환
- **PNU (필지고유번호) 자동 생성**: 19자리 (법정동코드 + 산여부 + 본번 + 부번)
- **BBOX 생성**: 좌표 기반 검색 영역 계산
- **Haversine 거리 계산**: 정확한 실거리 측정
- 동적 HTML 생성 및 DOM 조작
- localStorage 활용한 데이터 영속성
- URL 파라미터를 통한 페이지 간 데이터 전달

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

## 🎯 최근 업데이트 (v2.0)

### **새로운 기능**
- ✅ 최근 검색 5개 자동 저장
- ✅ 즐겨찾기 기능 (⭐ 버튼)
- ✅ 공유 링크 생성 (주소 미리 채워진 URL)
- ✅ 주소 요약 카드 (즉시 표시)
- ✅ 데이터 기준일 배지
- ✅ 토지 리스크 배지 (면적, 용도지역, 공시지가)
- ✅ VWorld 토지특성 API 통합
- ✅ 공인중개사 찾기 (거리순 정렬)
- ✅ 상세정보 토글 (접기/펼치기)
- ✅ 로딩 애니메이션
- ✅ 모바일 최적화

### **기술 개선**
- ✅ HTTPS 지원 (모든 VWorld API)
- ✅ 환경 자동 감지 (로컬/웹)
- ✅ PNU 자동 생성
- ✅ BBOX 계산
- ✅ Haversine 거리 측정
- ✅ localStorage 활용

---

**House MVP** - 한국의 공공 API를 활용한 부동산 검색 플랫폼 🏠