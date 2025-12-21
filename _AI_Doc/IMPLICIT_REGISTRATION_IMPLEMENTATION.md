# 암묵적 회원가입 (Implicit Registration) 구현 가이드

> 작성일: 2025-01-XX  
> 프로젝트: MyHome - 암묵적 회원가입 시스템  
> **목적**: MVP에서 회원가입 페이지 없이, 상담 요청 시 자동으로 계정 생성

---

## 📋 개요

기존 회원가입 프로세스를 제거하고, 사용자가 상담 요청을 할 때 자동으로 계정이 생성되도록 합니다. 이를 통해 사용자 진입 장벽을 낮추고 자연스러운 사용자 경험을 제공합니다.

---

## 🎯 핵심 원칙

### 1. 회원가입 페이지 제거
- 별도의 회원가입 페이지는 없음 (선택 사항으로 유지 가능)
- 사용자는 명시적으로 회원가입을 하지 않아도 서비스 이용 가능

### 2. 게스트 모드 지원
- 로그인하지 않은 사용자도 모든 핵심 기능 사용 가능
  - ✅ AI 추천 (상위 10개 일괄 요청)
  - ✅ 다중 선택 요청
  - ✅ 비대면 문의 (개별 견적 요청)

### 3. 자동 계정 생성
- 상담 요청 시 이메일 + 전화번호 입력
- 전화번호를 비밀번호로 사용 (이메일 = ID)
- 계정이 이미 있으면 로그인, 없으면 자동 생성

### 4. 사용자 안내
- 내집관리 접속 시 게스트 모드 안내
- 상담 요청 폼에서 자동 계정 생성 안내

---

## ✅ 구현 사항

### 1. 상담 요청 폼에 연락처 입력 필드 추가

**파일**: `lib/screens/broker/quote_request_form_page.dart`

**변경 내용**:
- 게스트 모드일 때만 이메일/전화번호 입력 필드 표시
- 이메일, 전화번호 필수 입력
- 안내 문구: "입력하신 정보로 계정이 자동 생성됩니다. 이후 내집관리에서는 이메일과 전화번호로 로그인하시면 됩니다."

### 2. 로그인 체크 제거

**파일**: `lib/screens/broker_list_page.dart`

**변경 내용**:
- `_requestQuoteToTop10()`: 로그인 체크 제거
- `_requestQuoteToMultiple()`: 로그인 체크 제거
- `_requestQuote()`: 로그인 체크 제거
- UI 버튼 활성화 조건 수정 (`canBulkTop10`, `canManual`)
- `requiresLogin`, `onTapDisabled` 제거 또는 false로 변경

### 3. 계정 자동 생성 로직

**파일**: `lib/screens/broker_list_page.dart`, `lib/screens/broker/quote_request_form_page.dart`

**기능**:
- 게스트 모드일 때 연락처 입력 다이얼로그 표시
- 이메일에서 ID 추출 (`email.split('@')[0]`)
- 전화번호를 비밀번호로 사용
- 계정 존재 여부 확인 (로그인 시도)
  - 성공: 이미 존재하는 계정, 로그인 상태 유지
  - 실패: 새 계정 생성 후 자동 로그인

### 4. 내집관리 페이지 안내 메시지

**파일**: `lib/screens/propertyMgmt/house_management_page.dart`

**변경 내용**:
- `_buildEmptyCard()` 수정
- 게스트 모드일 때: "게스트 모드입니다. 내집관리를 이용하려면 매물상담을 먼저 진행해주세요"
- 정식 사용자일 때: "관리 중인 견적이 없습니다. 공인중개사에게 문의를 보내보세요!"

---

## 🔧 상세 구현 내용

### 1. 게스트 모드 연락처 입력 다이얼로그

**함수**: `_showGuestContactDialog()`

```dart
Future<Map<String, String>?> _showGuestContactDialog() async {
  // 이메일, 전화번호 입력 필드
  // 안내 문구: "입력하신 정보로 계정이 자동 생성됩니다..."
  // 확인 버튼 클릭 시 이메일/전화번호 반환
}
```

### 2. 계정 자동 생성/로그인 함수

**함수**: `_createOrLoginAccount(String email, String phone)`

**로직**:
1. 이메일에서 ID 추출 (`email.split('@')[0]`)
2. 전화번호를 비밀번호로 사용 (`password = phone`)
3. 로그인 시도 (`signInWithEmailAndPassword`)
   - 성공 → 계정 존재, 로그인 완료
   - 실패 → 새 계정 생성 (`registerUser`) → 자동 로그인

### 3. 일괄 요청 시 계정 처리

**`_requestQuoteToTop10()`, `_requestQuoteToMultiple()` 수정**:
- 로그인 체크 제거
- 게스트 모드일 때 연락처 입력 다이얼로그 표시
- 계정 생성/로그인 처리 (한 번만)
- 이후 요청 저장은 정식 사용자로 처리

### 4. 개별 요청 시 계정 처리

**`quote_request_form_page.dart`의 `_submitRequest()` 수정**:
- 게스트 모드일 때 이메일/전화번호 검증
- 계정 생성/로그인 처리
- 견적 요청 저장 시 정식 사용자 정보 사용

---

## 📝 파일별 수정 내역

### 1. `lib/screens/broker_list_page.dart`

#### 수정 항목:
1. `_buildBulkActionButtons()`: UI 버튼 활성화 조건 수정
   - `canBulkTop10 = filteredBrokers.isNotEmpty` (로그인 체크 제거)
   - `canManual = true` (로그인 체크 제거)
   - `requiresLogin: false`
   - `onTapDisabled` 제거

2. `_requestQuoteToTop10()`: 로그인 체크 제거, 게스트 모드 처리 추가
   - `_ensureLoggedInOrRedirect()` 제거
   - 게스트 모드일 때 연락처 입력 다이얼로그
   - 계정 자동 생성/로그인 처리

3. `_requestQuoteToMultiple()`: 로그인 체크 제거, 게스트 모드 처리 추가
   - 동일한 처리

4. `_requestQuote()`: 로그인 체크 제거
   - `_showLoginRequiredDialog()` 제거
   - 바로 상담 요청 폼으로 이동

5. 새로 추가할 함수:
   - `_showGuestContactDialog()`: 게스트 모드 연락처 입력 다이얼로그
   - `_createOrLoginAccount()`: 계정 자동 생성/로그인

### 2. `lib/screens/broker/quote_request_form_page.dart`

#### 수정 항목:
1. 게스트 모드일 때 연락처 입력 필드 추가
   - 이메일 필드
   - 전화번호 필드
   - 안내 문구

2. `_submitRequest()` 수정:
   - 게스트 모드일 때 이메일/전화번호 검증
   - 계정 자동 생성/로그인 처리
   - 견적 요청 저장 시 정식 사용자 정보 사용

### 3. `lib/screens/propertyMgmt/house_management_page.dart`

#### 수정 항목:
1. `_buildEmptyCard()` 수정:
   - 게스트 모드 여부 확인 (`widget.userId == null || widget.userId!.isEmpty`)
   - 게스트 모드일 때 다른 메시지 표시
   - "게스트 모드입니다. 내집관리를 이용하려면 매물상담을 먼저 진행해주세요"

---

## 🔍 주의사항

### 1. 일괄 요청 시 계정 생성
- 여러 중개사에게 요청할 때 계정 생성은 **한 번만** 수행
- 루프 전에 계정 생성/로그인 처리 완료

### 2. 에러 처리
- 계정 생성 실패 시 사용자에게 명확한 안내
- 상담 요청 자체는 가능하도록 (게스트 모드로 저장)

### 3. 기존 게스트 모드 시스템과의 호환
- 기존 게스트 모드 로직은 유지
- 정식 로그인 사용자는 기존과 동일하게 작동

### 4. 비밀번호 = 전화번호
- MVP 단계에서는 보안 취약점 수용
- 나중에 비밀번호 변경 기능 추가 고려

---

## ✅ 구현 체크리스트

### 우선순위 1 (필수)
- [ ] `broker_list_page.dart`: `_buildBulkActionButtons()` UI 수정
- [ ] `broker_list_page.dart`: `_requestQuoteToTop10()` 로그인 체크 제거 및 게스트 모드 처리
- [ ] `broker_list_page.dart`: `_requestQuoteToMultiple()` 로그인 체크 제거 및 게스트 모드 처리
- [ ] `broker_list_page.dart`: `_requestQuote()` 로그인 체크 제거
- [ ] `broker_list_page.dart`: `_showGuestContactDialog()` 추가
- [ ] `broker_list_page.dart`: `_createOrLoginAccount()` 추가

### 우선순위 2 (필수)
- [ ] `quote_request_form_page.dart`: 게스트 모드 연락처 입력 필드 추가
- [ ] `quote_request_form_page.dart`: `_submitRequest()` 계정 자동 생성 로직 추가

### 우선순위 3 (UI 개선)
- [ ] `house_management_page.dart`: `_buildEmptyCard()` 게스트 모드 안내 메시지 수정

### 우선순위 4 (버그 수정 및 추가 개선)
- [ ] `broker_list_page.dart`: `_showGuestContactDialog()` TextEditingController dispose 타이밍 수정
- [ ] `broker_list_page.dart`: 안내 문구 개선 ("공인중개사의 상담 응답을 받을 연락처를 적어주세요...")
- [ ] `broker_list_page.dart`: "로그인하고 상위 10곳 빠른 요청" 문구 제거
- [ ] `quote_request_form_page.dart`: 안내 문구 개선 ("공인중개사의 상담 응답을 받을 연락처를 적어주세요...")

---

## 📊 예상 효과

### 사용자 경험 개선
- 회원가입 장벽 제거
- 자연스러운 서비스 이용 흐름
- 즉시 서비스 체험 가능

### 전환율 개선
- 상담 요청까지의 단계 감소
- 사용자 이탈률 감소
- 서비스 이용자 증가

---

**작성일**: 2025-01-XX  
**마지막 업데이트**: 2025-01-XX  
**상태**: 구현 준비 완료

