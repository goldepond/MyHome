import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'constants/app_constants.dart';
import 'screens/main_page.dart';
import 'screens/broker/broker_dashboard_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_request/firebase_service.dart';
import 'screens/inquiry/broker_inquiry_response_page.dart';
import 'widgets/retry_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'utils/app_analytics_observer.dart';
import 'utils/admin_page_loader_actual.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
  
  // 백그라운드에서 Firebase 초기화 (웹에서는 지연 로딩)
  _initializeFirebaseInBackground();
}

/// Firebase를 백그라운드에서 초기화하여 앱 시작 속도 향상
Future<void> _initializeFirebaseInBackground() async {
  try {
    // 웹에서는 Firebase SDK가 로드될 때까지 대기 (최대 5초)
    if (kIsWeb) {
      var attempts = 0;
      while (attempts < 50) {
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
          // SDK가 아직 로드되지 않았거나 초기화 실패
          // 100ms 후 재시도
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }
      // 최대 시도 횟수 초과 시 마지막으로 한 번 더 시도
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        Logger.info('Firebase 초기화 성공 (지연 로딩)');
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
  bool _isInitializingAnonymous = false;
  bool _firebaseReady = false;
  
  @override
  void initState() {
    super.initState();
    _checkFirebaseAndInitialize();
  }
  
  /// Firebase가 준비될 때까지 대기한 후 초기화
  Future<void> _checkFirebaseAndInitialize() async {
    // Firebase가 준비될 때까지 대기 (최대 5초)
    var attempts = 0;
    while (Firebase.apps.isEmpty && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    
    if (mounted) {
      setState(() {
        _firebaseReady = true;
      });
      _initializeAnonymousUser();
    }
  }
  
  Future<void> _initializeAnonymousUser() async {
    // Firebase가 준비되지 않았으면 대기
    if (!_firebaseReady || Firebase.apps.isEmpty) {
      return;
    }
    
    // 이미 로그인된 사용자가 있으면 익명 로그인은 시도하지 않는다.
    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }
    
    setState(() {
      _isInitializingAnonymous = true;
    });
    
    try {
      await FirebaseService().signInAnonymously();
    } catch (e) {
      // 익명 로그인 실패는 무시하고 계속 진행
      Logger.warning(
        '익명 로그인 실패',
        metadata: {'error': e.toString()},
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingAnonymous = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Firebase가 준비되지 않았으면 로딩 화면 표시
    if (!_firebaseReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        if ((snapshot.connectionState == ConnectionState.waiting || _isInitializingAnonymous) && user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
            if (userSnap.hasError) {
              return Scaffold(
                body: RetryView(
                  message: '사용자 정보를 불러오지 못했습니다.\n네트워크 상태를 확인한 뒤 다시 시도해주세요.',
                  onRetry: () {
                    // 단순 재빌드로 Future 재호출
                    (context as Element).markNeedsBuild();
                  },
                ),
              );
            }
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = userSnap.data!;

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
