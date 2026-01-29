# MyHome - 부동산 중개 플랫폼

매도자와 공인중개사를 직접 연결하는 MLS(Multiple Listing Service) 기반 부동산 중개 플랫폼입니다.

## 주요 기능

### 매도자
- **빠른 매물 등록**: 주소 → 가격 → 사진 3단계로 30초 등록
- **자동 중개사 매칭**: 지역 기반 공인중개사 자동 배포
- **방문 요청 관리**: 중개사 방문 요청 승인/거절
- **실시간 알림**: 매물 상태 변경 및 방문 요청 알림

### 공인중개사
- **MLS 대시보드**: 지역별 매물 탐색 및 관리
- **방문 요청**: 매도자에게 직접 방문 요청
- **성과 관리**: 계약 완료 매물 통계

### 공통
- **실시간 채팅**: 1:1 채팅 기능
- **알림 시스템**: 푸시 알림 지원

## 기술 스택

- **Frontend**: Flutter (iOS, Android, Web)
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Authentication**: Google, Kakao 소셜 로그인
- **Design System**: Apple HIG 기반 디자인 시스템

## 브랜드 컬러

- **Primary**: 코랄/테라코타 (#E07A5F)

## 시작하기

```bash
# 의존성 설치
flutter pub get

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
```

## 프로젝트 구조

```
lib/
├── api_request/          # Firebase/API 서비스
├── constants/            # 상수, 디자인 시스템
├── models/               # 데이터 모델
├── screens/              # 화면 (페이지)
│   ├── auth/             # 인증 관련
│   ├── broker/           # 중개사 기능
│   ├── seller/           # 판매자 MLS 기능
│   └── ...
├── utils/                # 유틸리티
└── widgets/              # 재사용 위젯

_AI_Doc/                  # AI 컨텍스트 문서
├── HELLO_CLAUDE.md       # AI 컨텍스트 요약
├── FEATURES_IMPLEMENTED_CATALOG.md  # 구현 기능 목록
├── RECENT_CHANGES_*.md   # 변경사항 기록
└── ...
```

## 문서

- `_AI_Doc/HELLO_CLAUDE.md` - 프로젝트 개요 및 AI 컨텍스트
- `_AI_Doc/FEATURES_IMPLEMENTED_CATALOG.md` - 구현된 기능 전체 목록
- `_AI_Doc/RECENT_CHANGES_2026_01_29.md` - 최근 변경사항

## 라이선스

Private - All rights reserved
