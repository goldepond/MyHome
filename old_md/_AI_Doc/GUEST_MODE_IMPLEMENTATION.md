# 게스트 모드 구현 가이드

> 작성일: 2025-01-XX  
> 프로젝트: MyHome - 게스트 모드 및 이메일/전화번호 기반 견적 조회 시스템  
> **최종 업데이트**: 2025-01-XX - 전체 구현 완료 ✅ (내집관리 탭 게스트 접근 허용 포함, 비대면 문의 게스트 모드 지원 추가)

---

## 📋 개요

로그인 기능을 유지하면서, 게스트 모드(비로그인) 사용자도 이메일/전화번호를 통해 견적 내역을 조회할 수 있도록 구현합니다.

---

## 🎯 핵심 원칙

### 1. 로그인 기능 유지
- 기존 로그인 시스템은 그대로 유지
- 정식 로그인 사용자는 userId로 자동 조회
- 로그인 페이지는 계속 사용 가능

### 2. 게스트 모드 동작
- **자동 조회 없음**: 게스트 모드는 자동으로 견적을 조회하지 않음
- **이메일/전화번호 검색 UI 표시**: 게스트 모드일 때만 검색 UI 표시
- **개인정보 보호**: 이메일/전화번호를 입력하지 않으면 견적 내역이 표시되지 않음

### 3. 견적 요청 시 필수 정보
- 이메일: 필수 입력
- 전화번호: 필수 입력
- 고유 링크 ID: 자동 생성 및 저장

---

## ✅ 구현 완료 사항

### 1. 게스트 UID 로컬 스토리지 저장
- **파일**: `lib/utils/guest_storage.dart`
- **기능**: 같은 컴퓨터에서 다음 방문 시 이전 게스트 UID 복원
- **상태**: ✅ 완료

### 2. Firebase 서비스 확장
- **파일**: `lib/api_request/firebase_service.dart`
- **추가된 함수**:
  - `getQuoteRequestsByEmail(String email)`: 이메일로 견적 조회
  - `getQuoteRequestsByPhone(String phone)`: 전화번호로 견적 조회
  - `getQuoteRequestByLinkId(String linkId)`: 고유 링크 ID로 견적 조회
  - `getQuoteRequestsMulti(...)`: 통합 조회 (모든 방식 지원)
- **개선 사항**: 저장된 게스트 UID도 함께 조회하도록 수정
- **상태**: ✅ 완료

### 3. 견적 요청 폼 개선
- **파일**: `lib/screens/broker/quote_request_form_page.dart`
- **추가된 기능**:
  - 이메일 필수 입력 필드
  - 전화번호 필수 입력 필드
  - 고유 링크 ID 자동 생성 및 저장
- **상태**: ✅ 완료

### 4. 내집관리 페이지 개선
- **파일**: `lib/screens/propertyMgmt/house_management_page.dart`
- **추가된 기능**:
  - 이메일/전화번호 검색 UI (게스트 모드일 때 자동 표시)
  - 게스트 모드에서 자동 조회 방지
- **상태**: ✅ 완료

### 5. main.dart 개선
- **파일**: `lib/main.dart`
- **추가된 기능**:
  - 게스트 UID 자동 저장
  - 익명 사용자도 게스트로 처리
- **상태**: ✅ 완료

---

## 🔧 수정 필요 사항

### 1. 내집관리 페이지 - 개인정보 보호 강화 ⚠️

**문제점**: 게스트 모드에서 이메일/전화번호를 입력하지 않으면 빈 화면이 표시되거나, 자동 조회가 시도될 수 있음

**수정 내용**:
```dart
// lib/screens/propertyMgmt/house_management_page.dart

/// 견적문의 목록 로드
Future<void> _loadQuotes() async {
  if (!mounted) return;

  setState(() {
    isLoading = true;
    error = null;
  });

  try {
    // 🔥 게스트 모드(userId 없음)는 자동 조회하지 않음
    final isGuestMode = widget.userId == null || widget.userId!.isEmpty;
    
    if (isGuestMode) {
      // 게스트 모드: 자동 조회하지 않고 검색 UI만 표시
      setState(() {
        isLoading = false;
        quotes = []; // 빈 리스트로 시작
      });
      return;
    }
    
    // 정식 로그인 사용자: userId로 자동 조회
    final queryId = widget.userId!;
    
    // Stream으로 실시간 데이터 수신
    _quoteSubscription?.cancel();
    _quoteSubscription = _firebaseService.getQuoteRequestsByUser(queryId).listen((loadedQuotes) {
      if (mounted) {
        setState(() {
          quotes = loadedQuotes;
          isLoading = false;
        });
        _applyFilter(source: 'auto_sync');
      }
    });
  } catch (e) {
    // ... existing error handling ...
  }
}
```

**UI 수정**:
```dart
// build 메서드 내부
child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    // 이메일/전화번호 검색 섹션
    if (_showEmailPhoneSearch) ...[
      // ... existing search UI ...
    ],
    
    // 🔥 게스트 모드이고 견적이 없으면 내역 표시 안 함
    if (_showEmailPhoneSearch && quotes.isEmpty) ...[
      // 검색 전 안내 메시지만 표시
      Container(
        padding: EdgeInsets.all(cardPadding),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: AirbnbColors.textSecondary),
              SizedBox(height: AppSpacing.md),
              Text(
                '이메일 또는 전화번호를 입력하여\n견적 내역을 조회해주세요',
                textAlign: TextAlign.center,
                style: AppTypography.body,
              ),
            ],
          ),
        ),
      ),
    ] else if (!_showEmailPhoneSearch || quotes.isNotEmpty) ...[
      // 정식 로그인 사용자 또는 검색 결과가 있을 때만 내역 표시
      // ... existing quote list UI ...
    ],
  ],
),
```

**상태**: ⚠️ 수정 필요

---

### 2. broker_list_page - 게스트 모드에서도 문의 가능 ✅

**상태**: ✅ 완료 (2025-01-XX)

**구현 내용**: 
- `_requestQuoteToTop10()`: 게스트 모드 지원 완료
- `_requestQuoteToMultiple()`: 게스트 모드 지원 완료
- `_requestQuote()`: 게스트 모드 지원 완료 (비대면 문의)
- 계정 생성 실패 시 문의 중단 처리 (데이터 불일치 방지)
- 용어 통일: "문의"로 통일

**수정 내용**:
```dart
// lib/screens/broker_list_page.dart

/// 상위 10개 공인중개사에게 자동 견적 요청
Future<void> _requestQuoteToTop10() async {
  // 🔥 로그인 체크 제거 - 게스트 모드도 가능
  // if (!await _ensureLoggedInOrRedirect()) return;
  
  if (filteredBrokers.isEmpty) {
    // ... existing code ...
  }
  
  // 🔥 게스트 모드일 때는 이메일/전화번호 입력 다이얼로그 표시
  final isGuestMode = widget.userId == null || widget.userId!.isEmpty;
  String? userEmail;
  String? userPhone;
  
  if (isGuestMode) {
    final contactInfo = await _showGuestContactDialog();
    if (contactInfo == null) return; // 취소됨
    userEmail = contactInfo['email'];
    userPhone = contactInfo['phone'];
  } else {
    userEmail = await _getUserEmail();
    // 정식 로그인 사용자는 users 컬렉션에서 전화번호 가져오기
    final userData = await _firebaseService.getUser(widget.userId!);
    userPhone = userData?['phone'] as String?;
  }
  
  // ... existing quote request code ...
  // userEmail과 userPhone 사용
}

/// 게스트 모드 연락처 입력 다이얼로그
Future<Map<String, String>?> _showGuestContactDialog() async {
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  
  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('연락처 정보'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: emailController,
            decoration: InputDecoration(labelText: '이메일 *'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '이메일을 입력해주세요';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return '올바른 이메일 형식을 입력해주세요';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: phoneController,
            decoration: InputDecoration(labelText: '전화번호 *'),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '전화번호를 입력해주세요';
              }
              final cleanPhone = value.replaceAll('-', '').replaceAll(' ', '').trim();
              if (cleanPhone.length < 10 || cleanPhone.length > 11) {
                return '올바른 전화번호 형식을 입력해주세요';
              }
              return null;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            if (emailController.text.trim().isEmpty || 
                phoneController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('이메일과 전화번호를 모두 입력해주세요')),
              );
              return;
            }
            Navigator.pop(context, {
              'email': emailController.text.trim(),
              'phone': phoneController.text.trim().replaceAll('-', '').replaceAll(' ', ''),
            });
          },
          child: Text('확인'),
        ),
      ],
    ),
  );
  
  emailController.dispose();
  phoneController.dispose();
  return result;
}
```

**동일하게 수정할 함수**:
- `_requestQuoteToMultiple()`: 여러 공인중개사에게 일괄 견적 요청

**상태**: ✅ 완료

---

### 3. assignQuoteToBroker - 게스트 모드 전화번호 처리 ✅

**문제점**: `assignQuoteToBroker()`가 `getUser(userId)`로만 전화번호를 가져오는데, 게스트 모드에서는 `users` 컬렉션에 없을 수 있음

**수정 내용**:
```dart
// lib/api_request/firebase_service.dart

Future<bool> assignQuoteToBroker({
  required String requestId,
  required String userId,
}) async {
  try {
    // 🔥 먼저 견적 요청 문서에서 userPhone 가져오기 (게스트 모드 대응)
    final quoteDoc = await _firestore
        .collection(_quoteRequestsCollectionName)
        .doc(requestId)
        .get();
    
    String? phone;
    if (quoteDoc.exists) {
      final quoteData = quoteDoc.data();
      phone = quoteData?['userPhone'] as String?;
    }
    
    // 🔥 견적 요청에 전화번호가 없으면 users 컬렉션에서 조회 (정식 로그인 사용자)
    if ((phone == null || phone.isEmpty) && userId.isNotEmpty) {
      final userData = await getUser(userId);
      phone = userData?['phone'] as String?;
    }

    final updateData = <String, dynamic>{
      'isSelectedByUser': true,
      'selectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (phone != null && phone.isNotEmpty) {
      updateData['userPhone'] = phone;
    }

    await _firestore
        .collection(_quoteRequestsCollectionName)
        .doc(requestId)
        .update(updateData);

    // ... existing notification code ...
  } catch (e) {
    return false;
  }
}
```

**상태**: ✅ 완료

---

### 4. 견적 비교 페이지 - 게스트 모드 체크 ✅

**파일**: `lib/screens/quote_comparison_page.dart`

**수정 내용**:
- 게스트 모드에서도 견적 비교 가능하도록 수정
- `assignQuoteToBroker()` 호출 시 quote.userId 사용하도록 수정

**상태**: ✅ 완료

---

## 📝 구현 체크리스트

### 우선순위 1 (개인정보 보호 - 필수)
- [x] **내집관리 페이지**: 게스트 모드에서 자동 조회 방지 ✅
- [x] **내집관리 페이지**: 이메일/전화번호 입력 전 내역 표시 안 함 ✅
- [x] **내집관리 페이지**: 검색 전 안내 메시지 표시 ✅

### 우선순위 2 (기능 활성화)
- [x] **broker_list_page**: `_requestQuoteToTop10()` - 게스트 모드 지원 ✅
- [x] **broker_list_page**: `_requestQuoteToMultiple()` - 게스트 모드 지원 ✅
- [x] **broker_list_page**: 게스트 모드 연락처 입력 다이얼로그 추가 ✅

### 우선순위 3 (데이터 전달 확인)
- [x] **firebase_service**: `assignQuoteToBroker()` - 게스트 모드 전화번호 처리 ✅
- [x] **견적 비교 페이지**: 게스트 모드 체크 및 처리 ✅

### 우선순위 4 (UI 개선)
- [ ] **broker_list_page**: UI 로그인 체크 제거
- [ ] **request_info_card**: 전화번호 표시 추가
- [ ] **admin_quote_requests_page**: 전화번호 표시 추가
- [ ] **broker_dashboard_page**: 전화번호 표시 확인
- [ ] **quote_history_page**: 게스트 모드 처리 추가

### 우선순위 5 (테스트 및 검증)
- [ ] 게스트 모드에서 견적 요청 → 이메일/전화번호 저장 확인
- [ ] 게스트 모드에서 이메일/전화번호로 견적 조회 확인
- [ ] 공인중개사 선택 시 전화번호 전달 확인
- [ ] 공인중개사 대시보드에서 전화번호 표시 확인
- [ ] 관리자 페이지에서 전화번호 표시 확인
- [ ] 정식 로그인 사용자 기능 정상 작동 확인

---

## 🔍 전체 로직 점검 결과 (2025-01-XX)

### 📋 점검 범위
게스트 모드 구현과 관련하여 전체 플로우를 추적하며 모든 페이지와 영향받는 부분을 점검했습니다.

---

### ✅ 완료된 항목 (영향 없음)

#### 1. 인증 및 초기화 플로우 (`main.dart`)
- ✅ 게스트 모드 자동 초기화
- ✅ 익명 사용자 처리
- ✅ 게스트 UID 로컬 스토리지 저장
- **영향받는 부분**: 없음

#### 2. 견적 요청 폼 (`quote_request_form_page.dart`)
- ✅ 이메일/전화번호 필수 입력
- ✅ validator 구현
- ✅ 게스트 모드에서도 정상 작동
- **영향받는 부분**: 없음

#### 3. 내집관리 페이지 (`house_management_page.dart`)
- ✅ 게스트 모드 자동 조회 방지
- ✅ 이메일/전화번호 검색 UI
- ✅ 개인정보 보호 처리
- **영향받는 부분**: 없음

#### 4. 견적 비교 페이지 (`quote_comparison_page.dart`)
- ✅ 게스트 모드에서도 공인중개사 선택 가능
- ✅ `quote.userId` fallback 처리
- **영향받는 부분**: 없음

#### 5. Firebase 서비스 (`firebase_service.dart`)
- ✅ `getQuoteRequestsByEmail()`: 완료
- ✅ `getQuoteRequestsByPhone()`: 완료
- ✅ `getQuoteRequestByLinkId()`: 완료
- ✅ `getQuoteRequestsMulti()`: 완료
- ✅ `assignQuoteToBroker()`: 게스트 모드 처리 완료
- **영향받는 부분**: 없음

#### 6. 성공 페이지 (`submit_success_page.dart`)
- ✅ 게스트 모드 안내 메시지
- ✅ 로그인 유도 버튼
- **영향받는 부분**: 없음

#### 7. 선택된 견적 카드 (`selected_quote_card.dart`)
- ✅ 전화번호 표시
- ✅ 전화 걸기 기능
- **영향받는 부분**: 없음

---

### ⚠️ 수정 필요 항목

#### 우선순위 1 (필수) - UI 및 표시

##### 1. `broker_list_page.dart` - UI 로그인 체크 제거
**파일**: `lib/screens/broker_list_page.dart`

**수정 필요 사항**:
1. 버튼 활성화 조건 수정 (235-236줄)
   ```dart
   // 현재
   final bool canBulkTop10 = _isLoggedIn && filteredBrokers.isNotEmpty;
   final bool canManual = _isLoggedIn;
   
   // 수정 필요
   final bool canBulkTop10 = filteredBrokers.isNotEmpty; // 로그인 체크 제거
   final bool canManual = true; // 로그인 체크 제거
   ```

2. 로그인 안내 메시지 제거 (185-226줄)
   ```dart
   // if (!_isLoggedIn) ...[ ... ] 전체 제거
   ```

3. 버튼 설명 수정 (269-271줄)
   ```dart
   description: canBulkTop10
       ? '정렬 기준 Top10 중개사에게\n원클릭으로 견적을 보냅니다'
       : '먼저 주소 주변 중개사를\n불러온 뒤 사용 가능합니다', // 로그인 체크 제거
   ```

4. requiresLogin 플래그 제거 (278, 292줄)
   ```dart
   requiresLogin: false, // 게스트 모드도 가능
   ```

**상태**: ⚠️ 수정 필요

---

##### 2. `request_info_card.dart` - 전화번호 표시 추가
**파일**: `lib/widgets/broker_quote/request_info_card.dart`

**문제점**: 공인중개사 상세 페이지에서 사용자 전화번호가 표시되지 않음

**수정 내용**:
```dart
// 63줄 이후에 전화번호 추가
if (quote.userPhone != null && quote.userPhone!.isNotEmpty) ...[
  const SizedBox(height: 12),
  Row(
    children: [
      Icon(Icons.phone, size: 20, color: AirbnbColors.textSecondary),
      SizedBox(width: 12),
      Text(
        '전화번호',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AirbnbColors.textSecondary,
        ),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Text(
          quote.userPhone!,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AirbnbColors.textPrimary,
          ),
        ),
      ),
    ],
  ),
],
```

**상태**: ⚠️ 수정 필요

---

##### 3. `admin_quote_requests_page.dart` - 전화번호 표시 추가
**파일**: `lib/screens/admin/admin_quote_requests_page.dart`

**문제점**: 관리자 페이지에서 사용자 전화번호가 표시되지 않음

**수정 내용**:
```dart
// 423줄 이후에 전화번호 추가
_buildInfoRow(Icons.email, '이메일', request.userEmail),
const SizedBox(height: 8),
if (request.userPhone != null && request.userPhone!.isNotEmpty) ...[
  _buildInfoRow(Icons.phone, '전화번호', request.userPhone!),
  const SizedBox(height: 8),
],
```

**상태**: ⚠️ 수정 필요

---

#### 우선순위 2 (권장) - 추가 개선

##### 4. `broker_dashboard_page.dart` - 카드에 전화번호 표시 확인
**파일**: `lib/screens/broker/broker_dashboard_page.dart`

**확인 필요**: `_buildQuoteCard` (393줄)에서 전화번호 표시 여부 확인

**상태**: ⚠️ 확인 필요

---

##### 5. `quote_history_page.dart` - 게스트 모드 처리 추가
**파일**: `lib/screens/quote_history_page.dart`

**문제점**: 게스트 모드 체크 없이 자동 조회 시도

**수정 내용**:
```dart
// 78-109줄: 게스트 모드 체크 추가
Future<void> _loadQuotes() async {
  // 🔥 게스트 모드 체크 추가 필요
  final isGuestMode = widget.userId == null || widget.userId!.isEmpty;
  if (isGuestMode) {
    // 게스트 모드 처리
    setState(() {
      isLoading = false;
      quotes = [];
    });
    return;
  }
  // ... 기존 코드
}
```

**상태**: ⚠️ 수정 필요

---

#### 우선순위 3 (선택) - 추가 확인

##### 6. `home_page.dart` - 게스트 모드 확인
**파일**: `lib/screens/home_page.dart`

**확인 필요**: 게스트 모드에서도 공인중개사 찾기 가능한지 확인

**상태**: ⚠️ 확인 필요

---

##### 7. `personal_info_page.dart` - 게스트 모드 처리 확인
**파일**: `lib/screens/userInfo/personal_info_page.dart`

**확인 필요**: 게스트 모드에서 접근 시 적절한 처리 확인

**상태**: ⚠️ 확인 필요

---

### 📊 영향도 분석

#### 높은 영향도 (즉시 수정 필요)
1. `broker_list_page.dart` - UI 로그인 체크 제거
2. `request_info_card.dart` - 전화번호 표시 추가
3. `admin_quote_requests_page.dart` - 전화번호 표시 추가

#### 중간 영향도 (권장 수정)
4. `broker_dashboard_page.dart` - 전화번호 표시 확인
5. `quote_history_page.dart` - 게스트 모드 처리 추가

#### 낮은 영향도 (선택적 확인)
6. `home_page.dart` - 게스트 모드 확인
7. `personal_info_page.dart` - 게스트 모드 처리 확인

---

## 🔍 추가 확인 사항

### 1. 로그인 체크가 있는 모든 기능
다음 파일들에서 로그인 체크를 확인하고 게스트 모드 지원 여부 결정:
- ✅ `lib/screens/broker_list_page.dart`: `_isLoggedIn` 사용하는 모든 곳 (UI 수정 필요)
- ✅ `lib/screens/quote_comparison_page.dart`: userId 체크 (완료)
- ⚠️ `lib/screens/home_page.dart`: `isLoggedIn` 사용하는 곳 (확인 필요)

### 2. 견적 요청 시 이메일/전화번호 저장 확인
- ✅ `lib/screens/broker/quote_request_form_page.dart`: 이미 필수 입력으로 구현됨
- ✅ `lib/screens/broker_list_page.dart`: 일괄 요청 시에도 이메일/전화번호 포함 완료

### 3. 공인중개사 대시보드
- ✅ 게스트 모드 사용자의 견적 요청이 제대로 표시됨
- ⚠️ 전화번호가 제대로 표시되는지 확인 필요 (`request_info_card.dart` 수정 필요)

### 4. 관리자 페이지
- ✅ 게스트 모드 사용자의 견적 요청이 제대로 표시됨
- ⚠️ 전화번호 표시 추가 필요 (`admin_quote_requests_page.dart` 수정 필요)

---

## 📊 구현 상태 요약

| 항목 | 상태 | 우선순위 |
|------|------|----------|
| 게스트 UID 저장 | ✅ 완료 | - |
| Firebase 서비스 확장 | ✅ 완료 | - |
| 견적 요청 폼 개선 | ✅ 완료 | - |
| 내집관리 페이지 기본 UI | ✅ 완료 | - |
| main.dart 개선 | ✅ 완료 | - |
| 내집관리 페이지 개인정보 보호 | ✅ 완료 | 1 |
| main_page 내집관리 탭 게스트 접근 | ✅ 완료 | 1 |
| broker_list_page 게스트 모드 지원 (로직) | ✅ 완료 | 2 |
| broker_list_page UI 로그인 체크 제거 | ✅ 완료 | 1 |
| assignQuoteToBroker 게스트 모드 처리 | ✅ 완료 | 3 |
| 견적 비교 페이지 확인 | ✅ 완료 | 3 |
| house_management_page 공인중개사 선택 | ✅ 완료 | 3 |
| request_info_card 전화번호 표시 | ✅ 완료 | 1 |
| admin_quote_requests_page 전화번호 표시 | ✅ 완료 | 1 |
| broker_dashboard_page 전화번호 표시 확인 | ✅ 완료 | 2 |
| quote_history_page 게스트 모드 처리 | ✅ 완료 | 2 |

**전체 구현 완료도**: 100% ✅ (코드 구현 완료, UI 개선 완료, 로직 검사 완료, 최종 개선 완료)

---

## 🎯 다음 단계

1. ✅ **우선순위 1 완료**: 개인정보 보호 강화
2. ✅ **우선순위 2 완료**: 게스트 모드에서 견적 요청 가능하도록 수정 (로직)
3. ✅ **우선순위 3 완료**: 공인중개사 선택 시 전화번호 전달 확인
4. ✅ **우선순위 4 완료**: UI 개선 (전화번호 표시, 로그인 체크 제거)
5. ✅ **우선순위 5 완료**: 전체 코드 로직 검사 완료
6. ✅ **최종 개선 완료**: 내집관리 탭 게스트 모드 접근 허용
7. ⏳ **최종 단계**: 실제 테스트 및 검증

---

## ✅ 구현 완료 내역 (2025-01-XX)

### 완료된 수정 사항

#### 1. 내집관리 페이지 개인정보 보호 ✅
- ✅ 게스트 모드에서 자동 조회 방지 (`_loadQuotes()` 수정)
- ✅ 이메일/전화번호 입력 전 내역 표시 안 함 (UI 조건부 렌더링)
- ✅ 검색 전 안내 메시지 표시 (아이콘 + 설명 텍스트)

#### 2. broker_list_page 게스트 모드 지원 ✅
- ✅ `_requestQuoteToTop10()` 게스트 모드 지원 추가
- ✅ `_requestQuoteToMultiple()` 게스트 모드 지원 추가
- ✅ 게스트 모드 연락처 입력 다이얼로그 추가 (`_showGuestContactDialog()`)
- ✅ 고유 링크 ID 생성 및 저장 (`inquiryLinkId`)

#### 3. assignQuoteToBroker 게스트 모드 처리 ✅
- ✅ 견적 요청 문서에서 userPhone 우선 조회
- ✅ users 컬렉션 fallback 처리 (정식 로그인 사용자용)

#### 4. 견적 비교 페이지 게스트 모드 지원 ✅
- ✅ quote.userId 사용하여 게스트 모드에서도 공인중개사 선택 가능
- ✅ effectiveUserId 계산 로직 추가

#### 5. house_management_page 공인중개사 선택 ✅
- ✅ 게스트 모드에서도 공인중개사 선택 가능하도록 수정
- ✅ quote.userId fallback 처리

---

## 🔧 최근 개선 사항 (2025-01-XX)

### 내집관리 탭 게스트 모드 접근 허용 ✅

**문제점**: 
- 게스트 모드 사용자가 내집관리 탭을 클릭하면 로그인 페이지로 리다이렉트됨
- 하지만 `house_management_page.dart`에는 이미 게스트 모드 이메일/전화번호 검색 UI가 구현되어 있음

**수정 내용**:
- `main_page.dart`: 내집관리 탭(인덱스 2)은 게스트 모드에서도 접근 가능하도록 수정
- 내 정보 탭(인덱스 3)만 로그인 필요로 유지
- 게스트 모드 사용자가 내집관리 탭 클릭 시 바로 접근하여 이메일/전화번호 검색 UI 표시

**파일**: `lib/screens/main_page.dart`
**라인**: 468줄 수정

**상태**: ✅ 완료

---

## 🔄 전체 로직 점검 결과 요약 (2025-01-XX)

### 점검 범위
게스트 모드 구현과 관련하여 전체 플로우를 추적하며 모든 페이지와 영향받는 부분을 점검했습니다.

### 점검 결과

#### ✅ 완료된 항목 (영향 없음)
- 인증 및 초기화 플로우 (`main.dart`)
- 견적 요청 폼 (`quote_request_form_page.dart`)
- 내집관리 페이지 (`house_management_page.dart`)
- 견적 비교 페이지 (`quote_comparison_page.dart`)
- Firebase 서비스 (`firebase_service.dart`)
- 성공 페이지 (`submit_success_page.dart`)
- 선택된 견적 카드 (`selected_quote_card.dart`)

#### ⚠️ 수정 필요 항목

**우선순위 1 (필수)**:
1. ✅ `main_page.dart` - 내집관리 탭 게스트 모드 접근 허용 (완료)
2. ✅ `broker_list_page.dart` - UI 로그인 체크 제거 (완료)
3. ✅ `request_info_card.dart` - 전화번호 표시 추가 (완료)
4. ✅ `admin_quote_requests_page.dart` - 전화번호 표시 추가 (완료)

**우선순위 2 (권장)**:
5. ✅ `broker_dashboard_page.dart` - 전화번호 표시 확인 (완료)
6. ✅ `quote_history_page.dart` - 게스트 모드 처리 추가 (완료)

**우선순위 3 (선택)**:
7. ✅ `home_page.dart` - 게스트 모드 확인 (완료)
8. ✅ `personal_info_page.dart` - 게스트 모드 처리 확인 (완료)

### 상세 점검 내용
각 페이지별 상세 점검 결과는 위의 "전체 로직 점검 결과" 섹션을 참고하세요.

---

## ✅ 전체 코드 로직 검사 결과 (2025-01-XX)

### 검사 완료 항목

#### 1. 견적 요청 저장 시 이메일/전화번호 저장 확인 ✅
- ✅ `quote_request_form_page.dart`: `userEmail`, `userPhone`, `inquiryLinkId` 모두 저장됨
- ✅ `broker_list_page.dart`: 일괄 요청 시에도 `userEmail`, `userPhone`, `inquiryLinkId` 저장됨
- ✅ `_requestQuoteToTop10()`: 게스트 모드 연락처 다이얼로그 후 저장
- ✅ `_requestQuoteToMultiple()`: 게스트 모드 연락처 다이얼로그 후 저장

#### 2. 게스트 모드에서 이메일/전화번호로 견적 조회 확인 ✅
- ✅ `house_management_page.dart`: 게스트 모드 체크 및 검색 UI 구현됨
- ✅ `quote_history_page.dart`: 게스트 모드 체크 추가됨
- ✅ `firebase_service.dart`: `getQuoteRequestsByEmail()`, `getQuoteRequestsByPhone()`, `getQuoteRequestByLinkId()` 구현됨

#### 3. 공인중개사 선택 시 전화번호 전달 확인 ✅
- ✅ `assignQuoteToBroker()`: 견적 요청 문서에서 `userPhone` 우선 조회, `users` 컬렉션 fallback
- ✅ `quote_comparison_page.dart`: 게스트 모드 체크 및 `quote.userId` 사용
- ✅ `house_management_page.dart`: 게스트 모드 체크 및 `quote.userId` 사용

#### 4. 모든 페이지에서 게스트 모드 처리 확인 ✅
- ✅ `main.dart`: 게스트 모드 초기화 및 UID 저장
- ✅ `main_page.dart`: 내집관리 탭 게스트 모드 접근 허용
- ✅ `broker_list_page.dart`: UI 로그인 체크 제거 완료
- ✅ `personal_info_page.dart`: 게스트 모드 체크 추가
- ✅ `home_page.dart`: 게스트 모드에서도 정상 작동
- ✅ `request_info_card.dart`: 전화번호 표시 추가
- ✅ `admin_quote_requests_page.dart`: 전화번호 표시 추가
- ✅ `broker_dashboard_page.dart`: 전화번호 표시 추가

#### 5. 에러 처리 확인 ✅
- ✅ `ErrorHandler` 클래스가 잘 구현되어 있음
- ✅ try-catch 블록이 적절히 사용됨
- ✅ 게스트 모드 관련 예외 처리 적절함

### 검사 결과 요약

| 검사 항목 | 상태 | 비고 |
|----------|------|------|
| 견적 요청 저장 | ✅ 완료 | 이메일/전화번호/링크ID 모두 저장 |
| 견적 조회 | ✅ 완료 | 게스트 모드 검색 UI 구현 |
| 전화번호 전달 | ✅ 완료 | 공인중개사 선택 시 전달 확인 |
| 페이지별 처리 | ✅ 완료 | 모든 페이지 게스트 모드 대응 |
| 에러 처리 | ✅ 완료 | 적절한 예외 처리 구현 |

**전체 로직 검사 완료도**: 100% ✅

---

## 📌 참고 사항

- 로그인 기능은 **절대 제거하지 않음**
- 게스트 모드는 **추가 옵션**으로 제공
- 정식 로그인 사용자는 기존과 동일하게 작동
- 개인정보 보호가 최우선 고려사항

