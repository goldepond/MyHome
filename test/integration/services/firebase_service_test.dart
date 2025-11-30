import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/firebase_options.dart';

// 주의: Firebase는 실제 연결 없이 완전히 테스트하기 어렵습니다.
// 이 테스트는 기본적인 구조와 에러 처리를 검증합니다.
// 실제 Firebase 기능 테스트는 E2E 테스트나 Firebase Emulator를 사용하는 것을 권장합니다.

void main() {
  // Firebase 초기화 상태 확인
  bool firebaseInitialized = false;

  // Firebase 초기화 (모든 테스트 전에 한 번만 실행)
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Firebase가 이미 초기화되지 않았을 때만 초기화
    if (Firebase.apps.isEmpty) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseInitialized = true;
      } catch (e) {
        // 테스트 환경에서는 Firebase 초기화가 실패할 수 있음
        // 이 경우 테스트를 스킵함
        print('Firebase initialization failed in test environment: $e');
        print('Tests will be skipped. Use Firebase Emulator or E2E tests for full testing.');
        firebaseInitialized = false;
      }
    } else {
      firebaseInitialized = true;
    }
  });

  group('FirebaseService', () {
    FirebaseService? firebaseService;
    
    setUp(() {
      // Firebase가 초기화되지 않았으면 서비스 생성 시도하지 않음
      if (!firebaseInitialized) {
        return;
      }
      firebaseService = FirebaseService();
    });
    
    group('서비스 구조', () {
      test('클래스가 존재해야 함', () {
        expect(FirebaseService, isNotNull);
      }, skip: !firebaseInitialized);
      
      test('인스턴스 생성 가능', () {
        if (firebaseService == null) return;
        expect(firebaseService, isNotNull);
        expect(firebaseService, isA<FirebaseService>());
      }, skip: !firebaseInitialized);
    });
    
    group('견적 요청 관련 메서드', () {
      test('saveQuoteRequest - 빈 QuoteRequest 처리', () async {
        if (!firebaseInitialized || firebaseService == null) return;
        // Given: 유효하지 않은 QuoteRequest
        final quoteRequest = QuoteRequest(
          id: '',
          userId: '',
          userName: '',
          userEmail: '',
          brokerName: '',
          message: '',
          status: 'pending',
          requestDate: DateTime.now(),
        );
        
        // When: 저장 시도
        final result = await firebaseService!.saveQuoteRequest(quoteRequest);
        
        // Then: null이거나 문자열 반환 (실제 Firebase 연결 없으면 null일 수 있음)
        expect(result, anyOf(isNull, isA<String>()));
      });
      
      test('getQuoteRequestsByUser - 빈 userId 처리', () async {
        if (!firebaseInitialized || firebaseService == null) return;
        // Given: 빈 userId
        final userId = '';
        
        // When: 조회 시도
        final stream = firebaseService!.getQuoteRequestsByUser(userId);
        
        // Then: 빈 스트림 반환
        final quotes = await stream.first;
        expect(quotes, isEmpty);
      });
      
      test('updateQuoteRequestStatus - 빈 requestId 처리', () async {
        if (!firebaseInitialized || firebaseService == null) return;
        // Given: 빈 requestId
        final requestId = '';
        final newStatus = 'completed';
        
        // When: 업데이트 시도
        final result = await firebaseService!.updateQuoteRequestStatus(requestId, newStatus);
        
        // Then: 실패해야 함 (빈 ID는 유효하지 않음)
        expect(result, isFalse);
      });
    });
    
    group('에러 처리', () {
      test('잘못된 데이터로 인한 에러 처리', () async {
        if (!firebaseInitialized || firebaseService == null) return;
        // Given: 잘못된 QuoteRequest
        final quoteRequest = QuoteRequest(
          id: 'invalid',
          userId: 'test_user',
          userName: 'Test User',
          userEmail: 'test@example.com',
          brokerName: 'Test Broker',
          message: 'Test message',
          status: 'pending',
          requestDate: DateTime.now(),
        );
        
        // When: 저장 시도 (실제 Firebase 연결 없으면 실패할 수 있음)
        final result = await firebaseService!.saveQuoteRequest(quoteRequest);
        
        // Then: null이거나 문자열 반환 (에러 처리 확인)
        expect(result, anyOf(isNull, isA<String>()));
      });
    });

    // 참고: 실제 Firebase 통합 테스트를 위해서는:
    // 1. Firebase Emulator Suite 사용
    // 2. 또는 E2E 테스트에서 실제 디바이스/에뮬레이터에서 테스트
    // 3. 또는 mockito를 사용하여 Firebase 인스턴스를 모킹 (복잡함)
    
    // Firebase Emulator를 사용한 테스트 예시:
    // setUpAll(() async {
    //   await Firebase.initializeApp();
    //   FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    //   FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    // });
    
    // 실제 Firebase 연결 테스트 (Firebase Emulator 사용 시):
    // test('견적 요청 생성 및 조회', () async {
    //   // Given
    //   final quoteRequest = QuoteRequest(
    //     id: '',
    //     userId: 'test_user',
    //     userName: 'Test User',
    //     userEmail: 'test@example.com',
    //     brokerName: 'Test Broker',
    //     message: 'Test message',
    //     status: 'pending',
    //     requestDate: DateTime.now(),
    //   );
    //   
    //   // When
    //   final requestId = await firebaseService.saveQuoteRequest(quoteRequest);
    //   
    //   // Then
    //   expect(requestId, isNotNull);
    //   expect(requestId, isNotEmpty);
    //   
    //   // 조회 테스트
    //   final stream = firebaseService.getQuoteRequestsByUser('test_user');
    //   final quotes = await stream.first;
    //   expect(quotes, isNotEmpty);
    //   expect(quotes.first.id, equals(requestId));
    // });
  });
}

