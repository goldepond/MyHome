# MyHome - 부동산 중개 플랫폼

매도자와 공인중개사를 직접 연결하는 MLS(Multiple Listing Service) 기반 부동산 중개 플랫폼입니다.

## 주요 기능

### 매도자 ✅
- **빠른 매물 등록**: 주소 → 가격 → 사진 3단계로 30초 등록
- **자동 중개사 매칭**: 지역 기반 공인중개사 자동 배포
- **방문 요청 관리**: 중개사 방문 요청 승인/거절
- **매물 상태 관리**: 등록/배포중/협의중/계약완료 상태 관리

### 공인중개사 ✅
- **MLS 대시보드**: 지역별 매물 탐색 및 관리
- **방문 요청**: 매도자에게 직접 방문 요청
- **견적 제안**: 중개수수료 제안 기능
- **성과 관리**: 계약 완료 매물 통계

### 일반 사용자 ✅
- **매물 탐색**: 지역/가격대별 매물 검색
- **중개사 찾기**: 지역 기반 공인중개사 검색
- **견적 비교**: 여러 중개사 견적 비교

### 인증 ✅
- 이메일/비밀번호 로그인
- Google 소셜 로그인
- 카카오 소셜 로그인
- 게스트 모드

### 미구현 ❌
- 실시간 채팅 (화면만 존재)
- 푸시 알림
- 결제 시스템
- 네이버/Apple 로그인

## 기술 스택

- **Frontend**: Flutter (iOS, Android, Web, Windows, macOS, Linux)
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Authentication**: Firebase Auth + Google/Kakao SDK
- **Design System**: Apple HIG 기반 디자인 시스템
- **CI/CD**: GitHub Actions

## 브랜드 컬러

- **Primary**: 코랄/테라코타 (#E07A5F)

## 시작하기

```bash
# 의존성 설치
flutter pub get

# .env 파일 생성 (API 키 설정)
cp .env.example .env

# 개발 서버 실행
flutter run
```

## 빌드

```bash
# Android APK (Release)
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# Windows
flutter build windows --release
```

## 프로젝트 구조

```
lib/
├── api_request/          # Firebase/API 서비스
│   ├── firebase_service.dart
│   ├── mls_property_service.dart
│   ├── google_sign_in_service.dart
│   └── kakao_sign_in_service.dart
├── constants/            # 상수, 디자인 시스템
│   ├── apple_design_system.dart
│   └── responsive_constants.dart
├── models/               # 데이터 모델
├── screens/              # 화면 (페이지)
│   ├── auth/             # 인증 (로그인, 회원가입)
│   ├── broker/           # 중개사 기능
│   │   ├── mls_broker_dashboard_page.dart
│   │   └── quote/        # 견적 관련
│   ├── seller/           # 판매자 MLS 기능
│   └── admin/            # 관리자 페이지
├── utils/                # 유틸리티
└── widgets/              # 재사용 위젯
    └── broker/           # 중개사 관련 위젯

_AI_Doc/                  # AI 컨텍스트 문서
├── HELLO_CLAUDE.md       # AI 컨텍스트 요약
├── FEATURES_IMPLEMENTED_CATALOG.md  # 구현 기능 목록
└── RECENT_CHANGES_*.md   # 변경사항 기록
```

## 문서

- `_AI_Doc/HELLO_CLAUDE.md` - 프로젝트 개요 및 AI 컨텍스트
- `_AI_Doc/FEATURES_IMPLEMENTED_CATALOG.md` - 구현된 기능 전체 목록

## 환경 변수

`.env` 파일에 다음 API 키가 필요합니다:
- `VWORLD_API_KEY` - VWorld 지도 API
- `VWORLD_GEOCODER_API_KEY` - VWorld 지오코더 API
- `JUSO_API_KEY` - 도로명주소 API
- `DATA_GO_KR_SERVICE_KEY` - 공공데이터포털 API

## 라이선스

Private - All rights reserved
