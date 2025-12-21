# 문서 목록 및 구조

> **최종 업데이트**: 2025-01-XX

---

## 📚 문서 구조

### 🎨 디자인 관련 문서

#### 1. **AIRBNB_DESIGN_ANALYSIS.md** ⭐ 통합 문서
- 에어비엔비 디자인 철학 분석 (4가지 원칙)
- 레이아웃 및 배치 분석
- 종합 평가 및 완료 상태
- **통합 전**: AIRBNB_LAYOUT_ANALYSIS.md + AIRBNB_DESIGN_PHILOSOPHY_ANALYSIS.md

#### 2. **색상 대비 검증** (IMPROVEMENTS_STATUS.md에 통합)
- 색상 대비 검증 결과 및 개선 내역
- WCAG AA 기준 준수 여부
- ColorContrastChecker 유틸리티 사용법

#### 3. **WEB_DESIGN_SUMMARY.md**
- 전체 디자인 시스템 총정리
- 디자인 시스템, 웹 최적화, 반응형 디자인
- UI 컴포넌트, HTML/CSS 템플릿
- 주요 화면 구성 및 기능

#### 4. **IMPROVEMENTS_STATUS.md**
- 개선 사항 진행 상황 총정리
- 완료된 개선 내역
- 문서별 완료 상태

---

### 🚀 배포 및 운영 문서

#### 5. **DEPLOYMENT_GUIDE.md** ⭐ 통합 문서
- GitHub Pages 배포 가이드
- 자동/수동 배포 방법
- 문제 해결 (GitHub Actions 권한 오류 포함)
- **통합 전**: DEPLOYMENT_GUIDE.md + GITHUB_ACTIONS_PERMISSIONS_FIX.md

#### 6. **PRODUCTION_CHECKLIST.md**
- 프로덕션 출시 전 필수 작업
- 보안 설정, 빌드 설정, 테스트 실행
- 모니터링 설정

#### 7. **PROJECT_SUMMARY.md** ⭐ 통합 문서
- 프로젝트 현황 및 개요
- 기술 스택, 주요 기능
- 배포 현황 및 프로덕션 체크리스트 (요약)
- **통합 내용**: 프로덕션 체크리스트 요약 포함

---

### 🛠️ 개발 문서

#### 8. **SETUP.md**
- 프로젝트 설치 및 실행 가이드
- 사전 요구사항 및 설정
- 개발 환경 설정

#### 9. **README.md**
- 프로젝트 개요
- 빠른 시작 가이드
- 주요 기능 소개

#### 10. **ADMIN_SEPARATION_GUIDE.md**
- 관리자 페이지 분리 및 배포 가이드
- 개발 환경 실행 방법
- 배포(Build) 방법

---

### 🔐 보안 및 설정 문서

#### 11. **FIRESTORE_RULES_COMPLETE.md**
- Firestore 보안 규칙 완전 검증
- 모든 컬렉션 규칙 포함
- 검증 완료 사항

---

## 📊 통합 현황

### ✅ 통합 완료

1. **AIRBNB_DESIGN_ANALYSIS.md** (신규 통합)
   - AIRBNB_LAYOUT_ANALYSIS.md + AIRBNB_DESIGN_PHILOSOPHY_ANALYSIS.md

2. **DEPLOYMENT_GUIDE.md** (업데이트)
   - GITHUB_ACTIONS_PERMISSIONS_FIX.md 내용 통합

3. **PROJECT_SUMMARY.md** (업데이트)
   - 프로덕션 체크리스트 요약 포함

### ❌ 삭제된 문서

- AIRBNB_LAYOUT_ANALYSIS.md → AIRBNB_DESIGN_ANALYSIS.md로 통합
- AIRBNB_DESIGN_PHILOSOPHY_ANALYSIS.md → AIRBNB_DESIGN_ANALYSIS.md로 통합
- GITHUB_ACTIONS_PERMISSIONS_FIX.md → DEPLOYMENT_GUIDE.md로 통합
- DOCUMENT_INTEGRATION_ANALYSIS.md → 통합 완료 후 삭제
- COLOR_CONTRAST_VALIDATION.md → IMPROVEMENTS_STATUS.md로 통합

---

## 📋 문서 수 변화

**통합 전**: 14개 문서  
**통합 후**: 10개 문서  
**감소**: 4개 문서 통합 완료 ✅

---

## 🔍 문서 찾기 가이드

### 디자인 관련 질문
→ **AIRBNB_DESIGN_ANALYSIS.md** (통합 문서)  
→ **WEB_DESIGN_SUMMARY.md** (전체 시스템)  
→ **IMPROVEMENTS_STATUS.md** (색상 대비 검증 포함)

### 배포 관련 질문
→ **DEPLOYMENT_GUIDE.md** (배포 가이드, 권한 문제 해결 포함)

### 프로젝트 현황
→ **PROJECT_SUMMARY.md** (프로젝트 개요, 체크리스트 요약)  
→ **PRODUCTION_CHECKLIST.md** (상세 체크리스트)

### 개발 시작
→ **SETUP.md** (설치 및 실행)  
→ **README.md** (프로젝트 개요)

### 개선 상태 확인
→ **IMPROVEMENTS_STATUS.md** (개선 진행 상황)

---

**최종 업데이트**: 2025-01-XX
