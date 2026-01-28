import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:property/firebase_options.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/screens/admin/admin_dashboard.dart';
import 'package:property/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (.env 파일이 있으면 로드, 없으면 무시, 웹에서는 건너뜀)
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

  // Firebase 초기화
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      Logger.info('Firebase 초기화 성공 (관리자 앱)');
    }
  } catch (e, stackTrace) {
    // Firebase 초기화 실패는 로깅
    Logger.error(
      'Firebase 초기화 실패 (관리자 앱)',
      error: e,
      stackTrace: stackTrace,
      context: 'firebase_initialization_admin',
    );
  }

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyHome 관리자',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AirbnbColors.primary,
        scaffoldBackgroundColor: AirbnbColors.surface,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AirbnbColors.primary,
          primary: AirbnbColors.primary,
          secondary: AirbnbColors.success,
          surface: AirbnbColors.surface,
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
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      // 관리자 앱은 자동 익명 로그인 후 대시보드로 연결
      home: const AdminAutoLogin(),
    );
  }
}

/// 자동 익명 로그인 후 대시보드 연결 (로그인 UI 없음)
class AdminAutoLogin extends StatefulWidget {
  const AdminAutoLogin({super.key});

  @override
  State<AdminAutoLogin> createState() => _AdminAutoLoginState();
}

class _AdminAutoLoginState extends State<AdminAutoLogin> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    try {
      // 이미 로그인되어 있으면 패스
      if (FirebaseAuth.instance.currentUser != null) {
        setState(() => _isLoading = false);
        return;
      }

      // 자동 익명 로그인
      await FirebaseAuth.instance.signInAnonymously();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      Logger.warning('자동 로그인 실패', metadata: {'error': e.toString()});
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('관리자 페이지 로딩 중...'),
            ],
          ),
        ),
      );
    }

    // 에러 발생 시
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('로그인 오류: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _autoLogin();
                },
                child: const Text('재시도'),
              ),
            ],
          ),
        ),
      );
    }

    // 로그인 성공 -> 대시보드
    final user = FirebaseAuth.instance.currentUser;
    return AdminDashboard(
      userId: user?.uid ?? 'admin',
      userName: '관리자',
    );
  }
}

