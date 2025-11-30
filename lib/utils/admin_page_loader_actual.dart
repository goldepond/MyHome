import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/admin/admin_dashboard.dart';
import '../api_request/firebase_service.dart';

/// 관리자 페이지 로더
/// 
/// 이 파일을 삭제하면 관리자 페이지 기능이 자동으로 비활성화됩니다.
/// main.dart의 onGenerateRoute에서 조건부로 로드됩니다.
class AdminPageLoaderActual {
  /// 관리자 페이지 라우트 생성
  /// 
  /// [routeName]이 `/admin-panel-myhome-2024`인 경우 관리자 페이지 라우트를 반환합니다.
  /// 그 외의 경우 null을 반환합니다.
  static Route? createAdminRoute(String? routeName) {
    if (routeName == null) {
      return null;
    }

    // 관리자 페이지 경로 확인
    final uri = Uri.parse(routeName);
    if (uri.path == '/admin-panel-myhome-2024' || 
        uri.pathSegments.contains('admin-panel-myhome-2024')) {
      return MaterialPageRoute(
        builder: (context) => const _AdminAuthGate(),
      );
    }

    return null;
  }
}

/// 관리자 로그인 확인 및 대시보드 연결
/// 
/// main_admin.dart의 AdminAuthGate와 동일한 로직을 사용합니다.
class _AdminAuthGate extends StatefulWidget {
  const _AdminAuthGate();

  @override
  State<_AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<_AdminAuthGate> {
  bool _isInitializingAnonymous = false;

  @override
  void initState() {
    super.initState();
    _initializeAnonymousUser();
  }

  Future<void> _initializeAnonymousUser() async {
    // 이미 로그인된 사용자가 있으면 패스
    if (FirebaseAuth.instance.currentUser != null) {
      return;
    }
    
    setState(() {
      _isInitializingAnonymous = true;
    });
    
    try {
      // 임시: 관리자도 일단 익명 로그인 등을 사용한다고 가정
      // 실제 운영 시에는 이메일/비밀번호 로그인 폼으로 대체 권장
      await FirebaseService().signInAnonymously();
    } catch (e) {
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isInitializingAnonymous) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // 로그인 성공 -> 관리자 대시보드
          return AdminDashboard(
            userId: snapshot.data!.uid,
            userName: snapshot.data!.email ?? '관리자',
          );
        }

        // 로그인 실패 또는 로그아웃 상태
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('관리자 접근 권한이 필요합니다.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _initializeAnonymousUser,
                  child: const Text('로그인 재시도'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

