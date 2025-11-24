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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      debugPrint('Logging queue failed: $e');
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
      final batch = _firestore.batch();
      final collection = _firestore.collection('user_logs');

      for (final log in logsToSend) {
        final docRef = collection.doc(); // 새 문서 ID 생성
        batch.set(docRef, log.toMap());
      }

      // 한 번에 전송 (비동기)
      await batch.commit();
      debugPrint('✅ Flushed ${logsToSend.length} logs.');
    } catch (e) {
      debugPrint('❌ Failed to flush logs: $e');
      // 실패 시 다시 큐에 넣을지 여부는 정책에 따라 결정 (여기선 버림/단순 로깅)
      // 재시도 로직을 넣으면 큐가 무한히 커질 위험이 있어 조심해야 함.
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
    return _firestore
        .collection('user_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActionLog.fromFirestore(doc)).toList();
    });
  }

  /// 관리자용: 특정 사용자 로그 조회
  Stream<List<ActionLog>> getUserLogs(String userId) {
    return _firestore
        .collection('user_logs')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActionLog.fromFirestore(doc)).toList();
    });
  }
  
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
  }
}
