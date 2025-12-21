import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/action_log.dart';

/// 사용자 행동 로깅 서비스 (최적화 버전)
/// - 메모리 버퍼링: 로그를 즉시 전송하지 않고 모아서 보냅니다.
/// - 배치 전송: 일정 개수(10개)나 시간(30초)이 지나면 한 번에 저장합니다.
/// - 앱 생명주기 감지: 앱이 백그라운드로 가면 남은 로그를 즉시 전송합니다.
class LogService with WidgetsBindingObserver {
  // Firebase 인스턴스를 지연 초기화하여 초기화 완료 후에만 접근
  FirebaseFirestore get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      // Firebase가 아직 초기화되지 않은 경우 예외 처리
      // 실제 사용 시점에 다시 시도하도록 함
      throw StateError('Firebase가 아직 초기화되지 않았습니다: $e');
    }
  }
  
  FirebaseAuth get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      throw StateError('Firebase가 아직 초기화되지 않았습니다: $e');
    }
  }

  // 싱글톤 패턴
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;

  LogService._internal() {
    // 앱 생명주기 감지 등록
    WidgetsBinding.instance.addObserver(this);
    // 주기적 플러시 타이머 시작
    _startFlushTimer();
  }

  // --- 설정 값 ---
  static const int _batchSize = 10; // 10개 모이면 전송
  static const Duration _flushInterval = Duration(seconds: 30); // 30초마다 전송

  // --- 상태 변수 ---
  final List<ActionLog> _logQueue = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  /// 로그 저장 (큐에 추가)
  void log({
    required String actionType,
    required String target,
    Map<String, dynamic>? metadata,
  }) {
    try {
      // Firebase가 초기화되지 않았으면 큐에만 추가하고 전송은 나중에
      final user = _auth.currentUser;
      final userId = user?.uid ?? 'anonymous';

      final log = ActionLog(
        userId: userId,
        actionType: actionType,
        target: target,
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
      );

      // 메모리 큐에 추가 (UI 스레드 차단 최소화)
      _logQueue.add(log);

      // 배치 크기에 도달하면 즉시 전송
      if (_logQueue.length >= _batchSize) {
        _flushQueue();
      }
    } catch (e) {
      // Firebase 초기화 실패나 다른 에러는 무시 (비동기 작업)
      // 로그는 큐에만 추가하고 나중에 전송 시도
    }
  }

  /// 화면 진입 로그
  void logScreenView(String screenName, {String? screenClass}) {
    log(
      actionType: 'view_screen',
      target: screenName,
      metadata: {
        if (screenClass != null) 'screenClass': screenClass,
      },
    );
  }

  /// 큐에 쌓인 로그를 Firestore로 전송 (Batch Write)
  Future<void> _flushQueue() async {
    if (_isFlushing || _logQueue.isEmpty) return;

    _isFlushing = true;
    // 전송할 로그들을 큐에서 꺼내서 별도 리스트로 복사
    final List<ActionLog> logsToSend = List.from(_logQueue);
    _logQueue.clear();

    try {
      // Firebase가 초기화되었는지 확인
      final firestore = _firestore;
      final batch = firestore.batch();
      final collection = firestore.collection('user_logs');

      for (final log in logsToSend) {
        final docRef = collection.doc(); // 새 문서 ID 생성
        batch.set(docRef, log.toMap());
      }

      // 한 번에 전송 (비동기)
      await batch.commit();
    } catch (e) {
      // Firebase 초기화 실패나 네트워크 에러인 경우
      // 로그를 다시 큐에 넣지 않고 버림 (무한 큐 증가 방지)
      // Firebase가 초기화되지 않은 경우는 나중에 다시 시도할 수 있도록
      // 큐에 다시 넣지 않음 (메모리 누수 방지)
    } finally {
      _isFlushing = false;
    }
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      _flushQueue();
    });
  }

  // --- 앱 생명주기 관리 ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드로 가거나 종료될 때 남은 로그 강제 전송
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _flushQueue();
    }
  }

  // --- 관리자용 조회 기능 (기존 유지) ---
  
  /// 관리자용: 로그 조회 (최신순)
  Stream<List<ActionLog>> getLogs({int limit = 100}) {
    try {
      return _firestore
          .collection('user_logs')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => ActionLog.fromFirestore(doc)).toList();
      });
    } catch (e) {
      // Firebase 초기화 실패 시 빈 스트림 반환
      return Stream.value([]);
    }
  }

  /// 관리자용: 특정 사용자 로그 조회
  Stream<List<ActionLog>> getUserLogs(String userId) {
    try {
      return _firestore
          .collection('user_logs')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => ActionLog.fromFirestore(doc)).toList();
      });
    } catch (e) {
      // Firebase 초기화 실패 시 빈 스트림 반환
      return Stream.value([]);
    }
  }
  
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
  }
}
