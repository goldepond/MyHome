# 문서 목록 및 구조

> **최종 업데이트**: 2026-01-01

---

## 📚 문서 구조

### 🎨 디자인 관련 문서

#### 1. **MAIN_PAGE_DESIGN_REVIEW.md** ⭐ 통합 문서
- 메인페이지 디자인 에어비엔비 스타일 점검 보고서
- 디자인 철학 부합도 분석 (4가지 원칙)
- 레이아웃 및 배치 분석
- 색상 및 타이포그래피 분석
- 컴포넌트별 상세 분석
- 개선 권장 사항
- **통합 전**: AIRBNB_DESIGN_ANALYSIS.md + MAIN_PAGE_DESIGN_REVIEW.md

#### 2. **WEB_DESIGN_SUMMARY.md**
- 전체 디자인 시스템 총정리
- 디자인 시스템, 웹 최적화, 반응형 디자인
- UI 컴포넌트, HTML/CSS 템플릿
- 주요 화면 구성 및 기능

#### 3. **IMPROVEMENTS_STATUS.md**
- 개선 사항 진행 상황 총정리
- 완료된 개선 내역
- 색상 대비 검증 결과 및 개선 내역
- WCAG AA 기준 준수 여부
- 문서별 완료 상태

---

### 🚀 배포 및 운영 문서

#### 4. **DEPLOYMENT_GUIDE.md** ⭐ 통합 문서
- GitHub Pages 배포 가이드
- 자동/수동 배포 방법
- 문제 해결 (GitHub Actions 권한 오류 포함)
- **통합 전**: DEPLOYMENT_GUIDE.md + GITHUB_ACTIONS_PERMISSIONS_FIX.md

#### 5. **PRODUCTION_CHECKLIST.md**
- 프로덕션 출시 전 필수 작업
- 보안 설정, 빌드 설정, 테스트 실행
- 모니터링 설정

#### 6. **PROJECT_SUMMARY.md** ⭐ 통합 문서
- 프로젝트 현황 및 개요
- 기술 스택, 주요 기능
- 배포 현황 및 프로덕션 체크리스트 (요약)
- **통합 내용**: 프로덕션 체크리스트 요약 포함

---

### 🛠️ 개발 문서

#### 7. **SETUP.md**
- 프로젝트 설치 및 실행 가이드
- 사전 요구사항 및 설정
- 개발 환경 설정

#### 8. **README.md**
- 프로젝트 개요
- 빠른 시작 가이드
- 주요 기능 소개

#### 9. **ADMIN_SEPARATION_GUIDE.md**
- 관리자 페이지 분리 및 배포 가이드
- 개발 환경 실행 방법
- 배포(Build) 방법

---

### 🔐 보안 및 설정 문서

#### 10. **FIRESTORE_RULES_COMPLETE.md**
- Firestore 보안 규칙 완전 검증
- 모든 컬렉션 규칙 포함
- 검증 완료 사항

---

### 🚀 성능 최적화 문서

#### 11. **PERFORMANCE_OPTIMIZATION.md** ⭐ 통합 문서
- 성능 최적화 가이드
- 완료된 최적화 항목
- 긴급/중요/선택적 최적화 계획
- 우선순위별 작업 계획
- 예상 성능 개선 효과
- **통합 전**: OPTIMIZATION_COMPLETED.md + PERFORMANCE_OPTIMIZATION_ANALYSIS.md

---

### 📍 기능 구현 문서

#### 12. **ADDRESS_TO_BROKER_SEARCH_IMPLEMENTATION.md**
- 주소 검색부터 중개사 검색까지 전체 구현 가이드
- API 통합, 지도 구현, UI 구성

#### 13. **REGION_SELECTION_MAP_IMPLEMENTATION.md**
- 지역 선택 지도 구현 가이드
- GPS 기반 검색, 반경 선택 기능

#### 14. **MAP_IMPLEMENTATION_GUIDE.md**
- 지도 구현 가이드
- VWorld API 연동, 마커 및 폴리곤 구현

#### 15. **GUEST_MODE_IMPLEMENTATION.md**
- 게스트 모드 구현 가이드
- 비로그인 사용자 접근 제어

#### 16. **IMPLICIT_REGISTRATION_IMPLEMENTATION.md**
- 암묵적 회원가입 구현 가이드
- 자동 사용자 생성 로직

---

## 📊 통합 현황

### ✅ 통합 완료

1. **MAIN_PAGE_DESIGN_REVIEW.md** (2025-01-27 통합)
   - AIRBNB_DESIGN_ANALYSIS.md + MAIN_PAGE_DESIGN_REVIEW.md

2. **PERFORMANCE_OPTIMIZATION.md** (2025-01-27 통합)
   - OPTIMIZATION_COMPLETED.md + PERFORMANCE_OPTIMIZATION_ANALYSIS.md

3. **DEPLOYMENT_GUIDE.md** (이전 통합)
   - GITHUB_ACTIONS_PERMISSIONS_FIX.md 내용 통합

4. **PROJECT_SUMMARY.md** (이전 통합)
   - 프로덕션 체크리스트 요약 포함

### ❌ 삭제된 문서

- AIRBNB_DESIGN_ANALYSIS.md → MAIN_PAGE_DESIGN_REVIEW.md로 통합 (2025-01-27)
- OPTIMIZATION_COMPLETED.md → PERFORMANCE_OPTIMIZATION.md로 통합 (2025-01-27)
- PERFORMANCE_OPTIMIZATION_ANALYSIS.md → PERFORMANCE_OPTIMIZATION.md로 통합 (2025-01-27)
- AIRBNB_LAYOUT_ANALYSIS.md → AIRBNB_DESIGN_ANALYSIS.md로 통합 (이전)
- AIRBNB_DESIGN_PHILOSOPHY_ANALYSIS.md → AIRBNB_DESIGN_ANALYSIS.md로 통합 (이전)
- GITHUB_ACTIONS_PERMISSIONS_FIX.md → DEPLOYMENT_GUIDE.md로 통합 (이전)
- DOCUMENT_INTEGRATION_ANALYSIS.md → 통합 완료 후 삭제 (이전)
- COLOR_CONTRAST_VALIDATION.md → IMPROVEMENTS_STATUS.md로 통합 (이전)
- cloud_functions_proposal.js → 사용되지 않는 제안 파일 삭제 (2026-01-01)

---

## 📋 문서 수 변화

**통합 전**: 18개 문서  
**현재**: 20개 문서 (MD 파일 19개 + 요약 문서 1개)  
**변화**: 통합 2개 + 신규 4개 추가 - 불필요한 파일 1개 삭제 (2026-01-01)

---

## 🔍 문서 찾기 가이드

### 디자인 관련 질문
→ **MAIN_PAGE_DESIGN_REVIEW.md** (통합 문서)  
→ **WEB_DESIGN_SUMMARY.md** (전체 시스템)  
→ **IMPROVEMENTS_STATUS.md** (색상 대비 검증 포함)

### 성능 최적화 관련 질문
→ **PERFORMANCE_OPTIMIZATION.md** (통합 문서)

### 배포 관련 질문
→ **DEPLOYMENT_GUIDE.md** (배포 가이드, 권한 문제 해결 포함)

### 프로젝트 현황
→ **PROJECT_SUMMARY.md** (프로젝트 개요, 체크리스트 요약)  
→ **PRODUCTION_CHECKLIST.md** (상세 체크리스트)

### 개발 시작
→ **SETUP.md** (설치 및 실행)  
→ **README.md** (프로젝트 개요)

### 기능 구현
→ **ADDRESS_TO_BROKER_SEARCH_IMPLEMENTATION.md** (주소 검색 → 중개사 검색)
→ **REGION_SELECTION_MAP_IMPLEMENTATION.md** (지역 선택 지도)
→ **MAP_IMPLEMENTATION_GUIDE.md** (지도 구현)
→ **GUEST_MODE_IMPLEMENTATION.md** (게스트 모드)
→ **IMPLICIT_REGISTRATION_IMPLEMENTATION.md** (암묵적 회원가입)

### 개선 상태 확인
→ **IMPROVEMENTS_STATUS.md** (개선 진행 상황)  
→ **CODE_QUALITY_REVIEW.md** (코드 품질 점검)  
→ **RECENT_IMPROVEMENTS_7DAYS.md** (최근 7일 개선 내역)  
→ **PROJECT_REVIEW_CHECKLIST.md** (프로젝트 전체 점검)

---

## 📋 최근 추가된 문서

#### 17. **CODE_QUALITY_REVIEW.md** (2026-01-01)
- 코드 품질 및 스타일 가이드 점검 리포트
- 캡슐화, 네이밍 컨벤션, 타입 안정성 평가
- Google Dart Style Guide 준수도 분석
- 개선 권장 사항 및 수정 완료 내역

#### 18. **RECENT_IMPROVEMENTS_7DAYS.md** (2026-01-01)
- 최근 7일간 개선된 기능 정리
- 커밋별 변경사항 상세 분석
- GPS 기반 검색, 주소 입력 검색 등 신규 기능 문서화

#### 19. **PROJECT_REVIEW_CHECKLIST.md** (2026-01-01)
- 프로젝트 전체 점검 리포트
- 용어 일관성, 코드 품질, 문서화 상태 점검
- 우선순위별 조치 사항

---

**최종 업데이트**: 2026-01-01
