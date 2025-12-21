# 📋 프로젝트 현황

> **작성일**: 2025-01-XX  
> **프로젝트명**: MyHome - 쉽고 빠른 부동산 상담

---

## 🎯 프로젝트 개요

**MyHome**은 부동산 거래(매매/전세/월세) 및 관리를 위한 종합 플랫폼입니다.

### 핵심 기능
- 📍 주소 기반 부동산 정보 조회
- 🏘️ 공인중개사 매칭 및 견적 요청
- 💰 투명한 견적 비교
- 🔐 Firebase 기반 실시간 데이터 동기화

---

## 📊 프로젝트 준비도: **87%** ✅

| 항목 | 준비도 | 상태 |
|------|--------|------|
| 보안 설정 | 90% | ✅ 거의 완료 |
| 빌드 설정 | 85% | ✅ 거의 완료 |
| 테스트 실행 | 90% | ✅ 자동화 + 코드 분석 완료 |
| 모니터링 | 50% | ⚠️ 준비됨 |
| 문서화 | 100% | ✅ 완료 |

---

## 🏗️ 프로젝트 구조

```
lib/
├── screens/          # UI 화면 (37개)
├── api_request/      # API 서비스 (9개)
├── models/           # 데이터 모델 (8개)
├── utils/            # 유틸리티 (17개)
├── widgets/          # 재사용 위젯 (13개)
├── constants/        # 상수 정의 (3개)
└── How/              # 기술 문서 (11개)
```

---

## 🔧 기술 스택

### 프레임워크
- **Flutter**: 3.35.4
- **Dart**: 3.9.2+
- **Firebase**: 인증, Firestore, Storage

### 주요 패키지
- `firebase_core` / `firebase_auth` / `cloud_firestore`
- `http` - REST API 통신
- `geolocator` / `geocoding` - 위치 기반 서비스
- `fl_chart` - 데이터 시각화
- `url_launcher` - 외부 링크 연결

### 외부 API
- **Juso API** (도로명주소 검색)
- **VWorld API** (좌표 변환, 공인중개사 검색)
- **Data.go.kr** (공동주택 정보)
- **CODEF API** (등기부등본 조회)

---

## ✨ 주요 기능

### 1. 사용자 인증 ✅
- 이메일/비밀번호 로그인
- 회원가입 (일반 사용자, 공인중개사)
- 비밀번호 재설정

### 2. 부동산 정보 조회 ✅
- 주소 검색 (Juso API)
- 아파트 정보 자동 조회
- 등기부등본 조회 (CODEF API)
- 토지 정보 조회

### 3. 공인중개사 매칭 ✅
- 위치 기반 중개사 검색
- 개별/다중 견적 요청
- 견적 비교 기능

### 4. 견적 관리 ✅
- 견적 요청 생성 및 관리
- 실시간 상태 업데이트
- 중개사 답변 수신

### 5. 부동산 관리 ✅
- 부동산 등록 및 관리
- 전자 체크리스트
- 관리비 내역 시각화

### 6. 공인중개사 대시보드 ✅
- 견적 요청 확인
- 답변 작성 및 제출
- 부동산 매물 관리

### 7. 관리자 시스템 ✅
- 견적 요청 모니터링
- 중개사 관리
- 사용자 로그 확인

### 8. 고객센터/문의하기 ✅
- 홈 화면 배너
- AppBar 아이콘
- 외부 SNS 채널 연결 (카카오톡, 인스타그램, 스레드, 밴드, 이메일)

---

## 📱 지원 플랫폼

| 플랫폼 | 상태 | 비고 |
|--------|------|------|
| **Android** | ✅ 완료 | 프로덕션 빌드 준비 완료 |
| **Web** | ✅ 완료 | GitHub Pages 배포 가능 |
| **Windows** | ✅ 완료 | 데스크톱 앱 지원 |
| **iOS** | ⚠️ 설정 필요 | Mac 환경 필요 |

---

## 🧪 테스트 현황

### 단위 테스트
- ✅ **82개 테스트 통과**

### QA 테스트
- ✅ **자동화 테스트 완료 (100%)**
- ✅ **코드 분석 테스트 완료 (100%)**
- ⚠️ **수동 테스트 필요** (실제 사용자 플로우)

---

## 🚀 배포 현황

### 웹 배포
- ✅ **GitHub Pages 자동 배포 설정 완료**
  - URL: https://goldepond.github.io/TESTHOME/
  - GitHub Actions 워크플로우 구성
  - 자세한 내용: [배포 가이드](DEPLOYMENT_GUIDE.md)

### Android 배포
- ⚠️ **Keystore 설정 필요**
  - keystore 파일 생성 필요
  - `android/key.properties` 파일 생성 필요

### iOS 배포
- ⚠️ **Mac 환경 필요**

---

## 📋 프로덕션 출시 체크리스트

### 즉시 수행 필요 (출시 전 필수) 🔴

1. [ ] **Firestore 보안 규칙 배포**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. [ ] **Android Keystore 설정**
   - keystore 파일 생성
   - `android/key.properties` 파일 생성

3. [ ] **프로덕션 API 키 검증**
   - 모든 API 키가 환경 변수로 설정되었는지 확인
   - 기본값이 사용되지 않는지 확인

4. [ ] **필수 QA 테스트 실행**
   - TC-001, TC-008, TC-025, TC-039, TC-050, TC-053, TC-067, TC-068, TC-119

5. [ ] **프로덕션 빌드 테스트**
   - 웹: 실제 서버에 배포 테스트
   - Android: 실제 디바이스에서 테스트

### 출시 직후 필수 (1주일 내) 🟡

1. [ ] **배포 확인**
   - GitHub Actions 배포 성공 확인
   - 사이트 접속 및 주요 기능 동작 확인
   - 브라우저 콘솔 에러 확인

2. [ ] **Crashlytics 연동 확인**
   - Firebase Console에서 Crashlytics 활성화
   - 테스트 크래시 발생 및 확인

3. [ ] **모니터링 설정 완료**
   - Firebase Analytics 활성화
   - 에러 로깅 확인
   - 일일 모니터링 루틴 설정

자세한 내용: [프로덕션 체크리스트](PRODUCTION_CHECKLIST.md)

---

## 📚 문서

### 핵심 문서
- [프로덕션 체크리스트](PRODUCTION_CHECKLIST.md) - 출시 전 필수 작업
- [배포 가이드](DEPLOYMENT_GUIDE.md) - 웹 배포 방법
- [설치 가이드](SETUP.md) - 개발 환경 설정
- [개선 작업 요약](IMPROVEMENTS_SUMMARY.md) - 완료된 개선 사항

---

## 🔗 주요 링크

- **웹 사이트**: https://goldepond.github.io/TESTHOME/
- **GitHub Actions**: https://github.com/goldepond/TESTHOME/actions
- **Firebase Console**: https://console.firebase.google.com

---

**작성일**: 2025-01-XX  
**마지막 업데이트**: 2025-01-XX  
**프로젝트 상태**: 출시 준비 중 (87%)
