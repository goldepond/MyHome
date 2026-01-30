import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// FCM (Firebase Cloud Messaging) 푸시 알림 서비스
///
/// 앱이 꺼져 있어도 알림을 받을 수 있도록 합니다.
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// FCM 초기화 (앱 시작 시 호출)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 웹에서는 FCM 지원하지 않음
      if (kIsWeb) {
        Logger.info('FCM: 웹 플랫폼에서는 푸시 알림을 지원하지 않습니다');
        return;
      }

      // 알림 권한 요청
      await _requestPermission();

      // 로컬 알림 초기화 (포그라운드용)
      await _initializeLocalNotifications();

      // 포그라운드 메시지 리스너
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 백그라운드에서 알림 탭 시 처리
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // 앱이 종료된 상태에서 알림으로 열린 경우
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      _isInitialized = true;
      Logger.info('FCM: 초기화 완료');
    } catch (e) {
      Logger.error('FCM: 초기화 실패', error: e);
    }
  }

  /// 알림 권한 요청
  Future<bool> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final isAuthorized =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      Logger.info('FCM: 알림 권한 ${isAuthorized ? "허용됨" : "거부됨"}');
      return isAuthorized;
    } catch (e) {
      Logger.error('FCM: 권한 요청 실패', error: e);
      return false;
    }
  }

  /// 로컬 알림 초기화
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // 로컬 알림 탭 시 처리
        Logger.info('FCM: 로컬 알림 탭 - ${details.payload}');
      },
    );

    // Android 알림 채널 생성
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'myhome_notifications',
        'MyHome 알림',
        description: '매물 및 방문 요청 관련 알림',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// FCM 토큰 가져오기 및 저장
  Future<String?> getAndSaveToken(String userId) async {
    try {
      if (kIsWeb) return null;

      final token = await _messaging.getToken();
      if (token == null) {
        Logger.warning('FCM: 토큰을 가져올 수 없습니다');
        return null;
      }

      // Firestore에 토큰 저장
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'ios' : 'android',
      });

      Logger.info('FCM: 토큰 저장 완료');

      // 토큰 갱신 리스너
      _messaging.onTokenRefresh.listen((newToken) {
        _saveToken(userId, newToken);
      });

      return token;
    } catch (e) {
      Logger.error('FCM: 토큰 저장 실패', error: e);
      return null;
    }
  }

  /// 토큰 저장 (내부용)
  Future<void> _saveToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      Logger.info('FCM: 토큰 갱신 완료');
    } catch (e) {
      Logger.error('FCM: 토큰 갱신 실패', error: e);
    }
  }

  /// 토큰 삭제 (로그아웃 시)
  Future<void> removeToken(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
      Logger.info('FCM: 토큰 삭제 완료');
    } catch (e) {
      Logger.error('FCM: 토큰 삭제 실패', error: e);
    }
  }

  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    Logger.info('FCM: 포그라운드 메시지 수신 - ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // 로컬 알림으로 표시
    _showLocalNotification(
      title: notification.title ?? '알림',
      body: notification.body ?? '',
      payload: message.data['relatedId'],
    );
  }

  /// 알림 탭으로 앱 열림 처리
  void _handleMessageOpenedApp(RemoteMessage message) {
    Logger.info('FCM: 알림으로 앱 열림 - ${message.data}');
    // TODO: 알림 타입에 따라 해당 화면으로 이동
    // 예: 방문 요청 알림 -> 매물 상세 페이지
  }

  /// 로컬 알림 표시 (포그라운드용)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'myhome_notifications',
      'MyHome 알림',
      channelDescription: '매물 및 방문 요청 관련 알림',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// 수동으로 로컬 알림 표시 (테스트용)
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(title: title, body: body, payload: payload);
  }
}

/// 백그라운드 메시지 핸들러 (top-level 함수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Logger.info('FCM: 백그라운드 메시지 수신 - ${message.notification?.title}');
  // 백그라운드에서는 시스템이 자동으로 알림 표시
}
