import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property/firebase_options.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/main_page.dart';
import 'package:property/screens/broker/broker_dashboard_page.dart';
import 'package:property/api_request/firebase_service.dart';
import 'package:property/screens/inquiry/broker_inquiry_response_page.dart';
import 'package:property/utils/app_analytics_observer.dart';
import 'package:property/utils/admin_page_loader_actual.dart';
import 'package:property/utils/logger.dart';
// 웹에서만 사용하는 import
import 'dart:html' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 이미지 캐시 최적화 (메모리 사용량 제한)
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
  
  // 전역 에러 핸들러 설정
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Logger.error(
      'Flutter Error 발생',
      error: details.exception,
      stackTrace: details.stack,
      context: 'flutter_error_handler',
    );
  };
  
  // 비동기 에러 핸들러 설정
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.error(
      'Platform Error 발생',
      error: error,
      stackTrace: stack,
      context: 'platform_error_handler',
    );
    return true;
  };
  
  // .env 파일이 있으면 로드, 없으면 무시 (웹에서는 건너뜀)
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // .env 파일이 없어도 앱은 실행 가능
      Logger.warning(
        '.env 파일을 로드할 수 없습니다',
        metadata: {'error': e.toString()},
      );
    }
  }
  
  // 앱을 먼저 실행하여 초기 렌더링 지연 방지
  runApp(const MyApp());
  
  // 웹에서 Flutter 첫 프레임 렌더링 완료 후 로딩 화면 제거 신호 전송
  if (kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 첫 프레임 렌더링 완료 후 JavaScript에 신호 전송
      html.window.dispatchEvent(html.Event('flutterAppReady'));
    });
  }
  
  // 백그라운드에서 Firebase 초기화 (웹에서는 지연 로딩)
  _initializeFirebaseInBackground();
}

  /// Firebase를 백그라운드에서 초기화하여 앱 시작 속도 향상
Future<void> _initializeFirebaseInBackground() async {
  try {
    // 웹에서는 Firebase SDK가 완전히 로드될 때까지 대기
    if (kIsWeb) {
      // 초기 대기 시간 제거 (즉시 시도하여 최초 접속 성능 개선)
      // await Future.delayed(const Duration(milliseconds: 300)); // 제거
      
      // Firebase 초기화 시도 (최대 1초로 단축)
      var initAttempts = 0;
      var lastError;
      
      // 재시도 횟수 대폭 감소: 30 -> 10 (최대 1초)
      while (initAttempts < 10) {
        try {
          // Firebase 초기화 시도
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            );
            Logger.info('Firebase 초기화 성공');
            return;
          } else {
            Logger.info('Firebase가 이미 초기화되어 있습니다');
            return;
          }
        } catch (e) {
          lastError = e;
          
          // 타입 변환 에러인 경우 대기 시간 단축
          final errorString = e.toString();
          if (errorString.contains('subtype') || 
              errorString.contains('minified') ||
              errorString.contains('JavaScriptObject')) {
            // SDK가 아직 완전히 로드되지 않은 경우로 판단
            await Future.delayed(const Duration(milliseconds: 50)); // 100 -> 50
          } else {
            // 다른 에러인 경우 더 짧은 대기 후 재시도
            await Future.delayed(const Duration(milliseconds: 20)); // 50 -> 20
          }
          
          initAttempts++;
        }
      }
      
      // 최대 시도 횟수 초과 시 최종 시도 (대기 시간 단축)
      if (Firebase.apps.isEmpty) {
        try {
          await Future.delayed(const Duration(milliseconds: 100)); // 300 -> 100
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
          Logger.info('Firebase 초기화 성공 (지연 로딩)');
        } catch (e) {
          // 최종 시도 실패 시 마지막 에러 또는 현재 에러 사용
          final errorToLog = lastError ?? e;
          Logger.error(
            'Firebase 초기화 최종 실패',
            error: errorToLog,
            context: 'firebase_initialization_final',
          );
          // 실패해도 앱은 계속 실행
        }
      }
    } else {
      // 모바일/데스크톱에서는 즉시 초기화
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        Logger.info('Firebase 초기화 성공');
      } else {
        Logger.info('Firebase가 이미 초기화되어 있습니다');
      }
    }
  } catch (e, stackTrace) {
    // Firebase 초기화 실패 시 에러 로깅
    Logger.error(
      'Firebase 초기화 실패',
      error: e,
      stackTrace: stackTrace,
      context: 'firebase_initialization',
    );
    // Firebase 초기화 실패 시에도 앱은 계속 실행
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHome - 쉽고 빠른 부동산 상담', 
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AirbnbColors.primary,
        scaffoldBackgroundColor: AirbnbColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AirbnbColors.primary,
          primary: AirbnbColors.primary,
          secondary: AirbnbColors.success,
          surface: AirbnbColors.surface,
          background: AirbnbColors.background,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AirbnbColors.background,
          foregroundColor: AirbnbColors.textPrimary,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
            foregroundColor: AirbnbColors.textWhite,
            elevation: 2,
            shadowColor: AirbnbColors.textPrimary.withValues(alpha: 0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AirbnbColors.textPrimary,
            side: const BorderSide(color: AirbnbColors.textPrimary, width: 1.5), // 에어비엔비 스타일: 검은색 테두리
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AirbnbColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AirbnbColors.textPrimary, // 에어비엔비 스타일: 검은색 배경
          foregroundColor: AirbnbColors.textWhite,
          elevation: 3,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AirbnbColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AirbnbColors.border, width: 1),
          ),
          shadowColor: Colors.black.withValues(alpha: 0.08),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AirbnbColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AirbnbColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AirbnbColors.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AirbnbColors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      // 화면 전환 로깅을 위한 Observer 등록
      navigatorObservers: [
        AppAnalyticsObserver(),
      ],
      // URL 기반 라우팅
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // 관리자 페이지 라우팅 (조건부 로드)
        // 관리자 페이지를 외부로 분리할 때는 AdminPageLoaderActual 파일을 삭제하면
        // 자동으로 관리자 기능이 비활성화됩니다.
        try {
          final adminRoute = AdminPageLoaderActual.createAdminRoute(settings.name);
          if (adminRoute != null) {
            return adminRoute;
          }
        } catch (e) {
          // 관리자 페이지 파일이 없는 경우 (외부로 분리된 경우)
          Logger.warning(
            '관리자 페이지 라우팅 실패',
            metadata: {'route': settings.name, 'error': e.toString()},
          );
        }
        
        // 공인중개사용 답변 페이지 (/inquiry/:id)
        final uri = Uri.parse(settings.name ?? '/');
        if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'inquiry') {
          final linkId = uri.pathSegments[1];
          return MaterialPageRoute(
            builder: (context) => BrokerInquiryResponsePage(linkId: linkId),
          );
        }
        
        // 기본 홈 페이지: Auth 게이트 사용
        return MaterialPageRoute(
          builder: (context) => const _AuthGate(),
        );
      },
    );
  }
}

/// Firebase Auth 상태를 구독하여 새로고침 시에도 로그인 유지
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Map<String, dynamic>? _cachedUserData;
  bool _firebaseReady = false;
  bool _showLoading = true;
  
  @override
  void initState() {
    super.initState();
    // 즉시 UI를 표시하고, Firebase는 백그라운드에서 초기화
    _initializeFirebaseAsync();
    // 최대 0.5초 후에는 로딩 화면 제거 (최초 접속 성능 개선)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showLoading = false;
        });
      }
    });
  }
  
  /// Firebase를 백그라운드에서 비동기로 초기화
  Future<void> _initializeFirebaseAsync() async {
    // Firebase가 준비될 때까지 대기 (최대 1초로 단축)
    var attempts = 0;
    while (Firebase.apps.isEmpty && attempts < 10) { // 30 -> 10
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (mounted) {
      setState(() {
        _firebaseReady = true;
      });
      // Firebase가 준비되면 익명 로그인 시도 (백그라운드)
      _initializeAnonymousUser();
    }
  }
  
  Future<void> _initializeAnonymousUser() async {
    // Firebase가 준비되지 않았으면 대기
    if (Firebase.apps.isEmpty) {
      return;
    }
    
    // 이미 로그인된 사용자가 있으면 익명 로그인은 시도하지 않는다.
    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }
    
    try {
      await FirebaseService().signInAnonymously();
    } catch (e) {
      // 익명 로그인 실패는 무시하고 계속 진행
      Logger.warning(
        '익명 로그인 실패',
        metadata: {'error': e.toString()},
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // 최대 2초까지만 로딩 화면 표시, 그 이후에는 Firebase 준비 여부와 무관하게 UI 표시
    if (_showLoading && !_firebaseReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Firebase가 준비되지 않았어도 기본 UI 표시
    if (!_firebaseReady) {
      return const MainPage(userId: '', userName: '');
    }
    
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        // Firebase 준비 중이거나 익명 로그인 중이어도 기본 UI 표시
        if (snapshot.connectionState == ConnectionState.waiting && user == null) {
          return const MainPage(userId: '', userName: '');
        }
        
        if (user == null) {
          _cachedUserData = null;
          return const MainPage(userId: '', userName: '');
        }
        
        // 캐시된 데이터가 있고 같은 사용자면 즉시 반환
        if (_cachedUserData != null && _cachedUserData!['uid'] == user.uid) {
          // 브로커 계정인 경우 공인중개사 대시보드로 진입
          if (_cachedUserData!['userType'] == 'broker' &&
              _cachedUserData!['brokerData'] != null) {
            final brokerId =
                _cachedUserData!['brokerId'] ?? _cachedUserData!['uid'];
            final brokerName = _cachedUserData!['name'] ?? '공인중개사';
            return BrokerDashboardPage(
              brokerId: brokerId,
              brokerName: brokerName,
              brokerData: _cachedUserData!['brokerData'],
            );
          }

          // 일반 사용자 기본 페이지
          return MainPage(
            key: ValueKey('main_${_cachedUserData!['uid']}'),
            userId: _cachedUserData!['uid'],
            userName: _cachedUserData!['name'],
          );
        }

        // Firestore / brokers 컬렉션에서 사용자 유형 및 표시 이름 로드
        // 로딩 중에도 기본 UI를 먼저 표시하여 사용자 경험 개선
        return FutureBuilder<Map<String, dynamic>?>(
          key: ValueKey(user.uid),
          future: () async {
            final service = FirebaseService();

            // 1) 공인중개사 컬렉션 먼저 확인
            final brokerData = await service.getBroker(user.uid);
            if (brokerData != null) {
              final brokerName = (brokerData['ownerName'] as String?) ??
                  (brokerData['businessName'] as String?) ??
                  '공인중개사';
              final brokerId =
                  (brokerData['brokerId'] as String?) ?? user.uid;

              return <String, dynamic>{
                'uid': user.uid,
                'name': brokerName,
                'userType': 'broker',
                'brokerId': brokerId,
                'brokerData': brokerData,
              };
            }

            // 2) 일반 사용자 컬렉션 조회
            final data = await service.getUser(user.uid);
            final userName = data != null
                ? (data['name'] as String? ??
                    data['id'] as String? ??
                    user.email?.split('@').first ??
                    '사용자')
                : (user.email?.split('@').first ?? '사용자');

            return <String, dynamic>{
              'uid': user.uid,
              'name': userName,
              'userType': 'user',
              'userData': data,
            };
          }(),
          builder: (context, userSnap) {
            // 에러 발생 시 기본 UI 표시 (재시도 옵션 제공)
            if (userSnap.hasError) {
              // 에러가 발생해도 기본 UI는 표시
              return MainPage(
                userId: user.uid,
                userName: user.email?.split('@').first ?? '사용자',
              );
            }
            
            // 로딩 중에도 기본 UI를 먼저 표시
            if (userSnap.connectionState == ConnectionState.waiting) {
              return MainPage(
                userId: user.uid,
                userName: user.email?.split('@').first ?? '사용자',
              );
            }

            final profile = userSnap.data;

            // 프로필이 없으면 기본 UI 표시
            if (profile == null) {
              return MainPage(
                userId: user.uid,
                userName: user.email?.split('@').first ?? '사용자',
              );
            }

            // 캐시 업데이트 (브로커 / 일반 사용자 공통)
            _cachedUserData = profile;

            // 브로커 계정이면 공인중개사 대시보드로 이동
            if (profile['userType'] == 'broker' &&
                profile['brokerData'] != null) {
              final brokerId = profile['brokerId'] ?? profile['uid'];
              final brokerName = profile['name'] ?? '공인중개사';
              return BrokerDashboardPage(
                brokerId: brokerId,
                brokerName: brokerName,
                brokerData: profile['brokerData'],
              );
            }

            // 기본: 일반 사용자 메인 페이지
            return MainPage(
              key: ValueKey('main_${user.uid}'),
              userId: profile['uid'] as String,
              userName: profile['name'] as String,
            );
          },
        );
      },
    );
  }
}
