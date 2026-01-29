import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mls_property.dart';
import '../models/notification_model.dart';
import '../utils/logger.dart';
import 'firebase_service.dart';

/// MLS(Multiple Listing Service)형 매물 관리 서비스
///
/// 매도인 중심의 매물 통합 관리 시스템:
/// - 매물 등록/수정/삭제
/// - 지역 기반 중개사 자동 배포
/// - 실시간 상태 동기화
/// - 방문 예약 관리
/// - 협의 이력 관리
class MLSPropertyService {
  // 싱글톤 패턴
  static final MLSPropertyService _instance = MLSPropertyService._internal();
  factory MLSPropertyService() => _instance;
  MLSPropertyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collectionName = 'mlsProperties';

  // 스트림 캐싱용 변수 (재구독 방지)
  final Map<String, Stream<List<MLSProperty>>> _broadcastStreams = {};

  // 지역 목록 캐시
  List<String>? _cachedRegions;
  DateTime? _regionsCacheTime;

  /// 매물 생성
  Future<String> createProperty(MLSProperty property) async {
    try {
      final docRef = _firestore.collection(_collectionName).doc(property.id);
      await docRef.set(property.toMap());
      Logger.info('MLS Property created: ${property.id}');
      return property.id;
    } catch (e) {
      Logger.error('Failed to create MLS property', error: e);
      rethrow;
    }
  }

  /// 매물 수정
  Future<void> updateProperty(String id, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection(_collectionName).doc(id).update(updates);
      Logger.info('MLS Property updated: $id');
    } catch (e) {
      Logger.error('Failed to update MLS property', error: e);
      rethrow;
    }
  }

  /// 매물 조회 (단건)
  Future<MLSProperty?> getProperty(String id) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(id).get();
      if (!doc.exists) return null;
      return MLSProperty.fromMap(doc.data()!);
    } catch (e) {
      Logger.error('Failed to get MLS property', error: e);
      return null;
    }
  }

  /// 매도인별 매물 목록 조회 (실시간 스트림)
  Stream<List<MLSProperty>> getPropertiesByUser(String userId) {
    return _firestore
      .collection(_collectionName)
      .where('userId', isEqualTo: userId)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList());
  }

  /// 전체 활성 매물 조회 (마켓플레이스용)
  Stream<List<MLSProperty>> getAllActiveProperties({int limit = 50}) {
    return _firestore
      .collection(_collectionName)
      .where('isActive', isEqualTo: true)
      .where('isDeleted', isEqualTo: false)
      .where('status', whereIn: [
        PropertyStatus.active.toString().split('.').last,
        PropertyStatus.inquiry.toString().split('.').last,
        PropertyStatus.underOffer.toString().split('.').last,
      ])
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList());
  }

  /// 전체 활성 매물 빠른 조회 (마켓플레이스 초기 로딩용)
  Future<List<MLSProperty>> getAllActivePropertiesFast({int limit = 100}) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .where('status', whereIn: [
          PropertyStatus.active.toString().split('.').last,
          PropertyStatus.inquiry.toString().split('.').last,
          PropertyStatus.underOffer.toString().split('.').last,
        ])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList();
    } catch (e) {
      Logger.error('Failed to get active properties fast', error: e);
      return [];
    }
  }

  /// 중개사가 영업할 매물 목록 조회 (모든 활성 매물)
  /// whereIn 대신 클라이언트 필터링 사용하여 인덱스 제약 회피
  /// 스트림 캐싱으로 재구독 방지
  Stream<List<MLSProperty>> getAllBrowsableProperties({String? region, int limit = 50}) {
    final cacheKey = 'browsable_${region ?? 'all'}_$limit';

    // 이미 캐싱된 스트림이 있으면 재사용
    if (_broadcastStreams.containsKey(cacheKey)) {
      return _broadcastStreams[cacheKey]!;
    }

    Query<Map<String, dynamic>> query = _firestore
      .collection(_collectionName)
      .where('isActive', isEqualTo: true)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .limit(limit);

    if (region != null && region.isNotEmpty) {
      query = query.where('region', isEqualTo: region);
    }

    final stream = query.snapshots().map((snapshot) {
      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .where((p) =>
          p.status == PropertyStatus.active ||
          p.status == PropertyStatus.inquiry ||
          p.status == PropertyStatus.underOffer)
        .toList();
    }).asBroadcastStream();

    _broadcastStreams[cacheKey] = stream;
    return stream;
  }

  /// 캐시된 스트림 초기화 (지역 변경 시 호출)
  void clearBrowsableCache() {
    _broadcastStreams.removeWhere((key, _) => key.startsWith('browsable_'));
  }

  /// 전체 매물의 지역 목록 조회 (필터용) - 5분 캐싱
  Future<List<String>> getAvailableRegions({bool forceRefresh = false}) async {
    // 캐시가 유효하면 바로 반환 (5분)
    if (!forceRefresh &&
        _cachedRegions != null &&
        _regionsCacheTime != null &&
        DateTime.now().difference(_regionsCacheTime!).inMinutes < 5) {
      return _cachedRegions!;
    }

    try {
      // 필요한 필드만 가져오기 (region만)
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .limit(200) // 최대 200개만 조회
        .get();

      final regions = snapshot.docs
        .map((doc) => doc.data()['region'] as String?)
        .where((r) => r != null && r.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

      regions.sort();

      // 캐시 저장
      _cachedRegions = regions;
      _regionsCacheTime = DateTime.now();

      return regions;
    } catch (e) {
      Logger.error('Failed to get available regions', error: e);
      return _cachedRegions ?? [];
    }
  }

  /// 지역별 활성 매물 조회
  Stream<List<MLSProperty>> getActivePropertiesByRegion(String region) {
    return _firestore
      .collection(_collectionName)
      .where('region', isEqualTo: region)
      .where('isActive', isEqualTo: true)
      .where('isDeleted', isEqualTo: false)
      .where('status', whereIn: [
        PropertyStatus.active.toString().split('.').last,
        PropertyStatus.inquiry.toString().split('.').last,
        PropertyStatus.underOffer.toString().split('.').last,
      ])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList());
  }

  /// 중개사가 참여 중인 매물 목록 조회
  Stream<List<MLSProperty>> getPropertiesByBroker(String brokerId) {
    return _firestore
      .collection(_collectionName)
      .where('targetBrokerIds', arrayContains: brokerId)
      .where('isDeleted', isEqualTo: false)
      .orderBy('broadcastedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
          .map((doc) => MLSProperty.fromMap(doc.data()))
          .where((property) {
            final response = property.brokerResponses[brokerId];
            return response != null && response.hasViewed;
          })
          .toList();
      });
  }

  /// 중개사에게 배포된 모든 매물 조회 (참여 대시보드용) - Future 버전
  /// 수락 여부와 관계없이 targetBrokerIds에 포함된 모든 매물 반환
  Future<List<MLSProperty>> getPropertiesBroadcastedToBroker(String brokerId) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('targetBrokerIds', arrayContains: brokerId)
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .orderBy('broadcastedAt', descending: true)
        .get();

      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList();
    } catch (e) {
      Logger.error('Failed to get broadcasted properties', error: e);
      return [];
    }
  }

  /// 중개사에게 배포된 모든 매물 조회 (실시간 스트림 버전)
  /// 스트림 캐싱으로 재구독 방지
  Stream<List<MLSProperty>> getPropertiesBroadcastedToBrokerStream(String brokerId) {
    final cacheKey = 'broadcasted_$brokerId';

    if (_broadcastStreams.containsKey(cacheKey)) {
      return _broadcastStreams[cacheKey]!;
    }

    final stream = _firestore
      .collection(_collectionName)
      .where('targetBrokerIds', arrayContains: brokerId)
      .where('isDeleted', isEqualTo: false)
      .where('isActive', isEqualTo: true)
      .orderBy('broadcastedAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
          .map((doc) => MLSProperty.fromMap(doc.data()))
          .toList();
      }).asBroadcastStream();

    _broadcastStreams[cacheKey] = stream;
    return stream;
  }

  /// 중개사가 가계약 또는 거래완료한 매물 조회 (성과 탭용)
  /// 스트림 캐싱으로 재구독 방지
  Stream<List<MLSProperty>> getCompletedPropertiesByBroker(String brokerId) {
    final cacheKey = 'completed_$brokerId';

    if (_broadcastStreams.containsKey(cacheKey)) {
      return _broadcastStreams[cacheKey]!;
    }

    final stream = _firestore
      .collection(_collectionName)
      .where('finalBrokerId', isEqualTo: brokerId)
      .where('isDeleted', isEqualTo: false)
      .orderBy('depositTakenAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
          .map((doc) => MLSProperty.fromMap(doc.data()))
          .where((property) =>
            property.status == PropertyStatus.depositTaken ||
            property.status == PropertyStatus.sold)
          .toList();
      }).asBroadcastStream();

    _broadcastStreams[cacheKey] = stream;
    return stream;
  }

  // ========================================
  // 빠른 초기 로딩용 Future 메서드 (대시보드 최적화)
  // ========================================

  /// 전체 활성 매물 빠른 조회 (초기 로딩용)
  Future<List<MLSProperty>> getAllBrowsablePropertiesFast({String? region, int limit = 30}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
        .collection(_collectionName)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);

      if (region != null && region.isNotEmpty) {
        query = query.where('region', isEqualTo: region);
      }

      final snapshot = await query.get();
      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .where((p) =>
          p.status == PropertyStatus.active ||
          p.status == PropertyStatus.inquiry ||
          p.status == PropertyStatus.underOffer)
        .toList();
    } catch (e) {
      Logger.error('Failed to get browsable properties fast', error: e);
      return [];
    }
  }

  /// 중개사에게 배포된 매물 빠른 조회 (초기 로딩용)
  Future<List<MLSProperty>> getPropertiesBroadcastedToBrokerFast(String brokerId) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('targetBrokerIds', arrayContains: brokerId)
        .where('isDeleted', isEqualTo: false)
        .where('isActive', isEqualTo: true)
        .orderBy('broadcastedAt', descending: true)
        .limit(50)
        .get();

      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .toList();
    } catch (e) {
      Logger.error('Failed to get broadcasted properties fast', error: e);
      return [];
    }
  }

  /// 중개사 성과 매물 빠른 조회 (초기 로딩용)
  Future<List<MLSProperty>> getCompletedPropertiesByBrokerFast(String brokerId) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('finalBrokerId', isEqualTo: brokerId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('depositTakenAt', descending: true)
        .limit(50)
        .get();

      return snapshot.docs
        .map((doc) => MLSProperty.fromMap(doc.data()))
        .where((property) =>
          property.status == PropertyStatus.depositTaken ||
          property.status == PropertyStatus.sold)
        .toList();
    } catch (e) {
      Logger.error('Failed to get completed properties fast', error: e);
      return [];
    }
  }

  /// 중개사 관련 캐시 초기화 (로그아웃 시 호출)
  void clearBrokerCache(String brokerId) {
    _broadcastStreams.removeWhere((key, _) =>
        key == 'broadcasted_$brokerId' || key == 'completed_$brokerId');
  }

  /// 전체 캐시 초기화 (로그아웃 시 호출)
  void clearAllCache() {
    _broadcastStreams.clear();
  }

  /// 매물 배포 (지역 내 중개사에게 푸시)
  Future<void> broadcastProperty({
    required String propertyId,
    required List<String> brokerIds,
  }) async {
    try {
      final now = DateTime.now();
      final brokerResponses = <String, BrokerResponse>{};

      for (final brokerId in brokerIds) {
        brokerResponses[brokerId] = BrokerResponse(
          brokerId: brokerId,
          brokerName: '', // 실제로는 중개사 정보 조회 필요
          receivedAt: now,
        );
      }

      await updateProperty(propertyId, {
        'targetBrokerIds': brokerIds,
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
        'broadcastedAt': now.toIso8601String(),
        'status': PropertyStatus.active.toString().split('.').last,
      });

      Logger.info('Property broadcasted to ${brokerIds.length} brokers: $propertyId');
    } catch (e) {
      Logger.error('Failed to broadcast property', error: e);
      rethrow;
    }
  }

  /// 중개사 응답 업데이트 (상태 및 진행 단계 업데이트)
  Future<void> updateBrokerResponse({
    required String propertyId,
    required String brokerId,
    String? brokerName,
    String? brokerCompany,
    String? brokerPhone,
    BrokerStage? stage,
    bool? viewed,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final responses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existing = responses[brokerId];

      responses[brokerId] = BrokerResponse(
        brokerId: brokerId,
        brokerName: brokerName ?? existing?.brokerName ?? '',
        brokerCompany: brokerCompany ?? existing?.brokerCompany,
        brokerPhone: brokerPhone ?? existing?.brokerPhone,
        stage: stage ?? existing?.stage ?? BrokerStage.received,
        receivedAt: existing?.receivedAt ?? DateTime.now(),
        viewedAt: viewed == true ? DateTime.now() : existing?.viewedAt,
      );

      await updateProperty(propertyId, {
        'brokerResponses': responses.map((k, v) => MapEntry(k, v.toMap())),
      });

      Logger.info('Broker response updated: $brokerId -> stage: $stage');
    } catch (e) {
      Logger.error('Failed to update broker response', error: e);
      rethrow;
    }
  }

  /// 매물 상태 변경 (상태 머신)
  Future<void> updateStatus({
    required String propertyId,
    required PropertyStatus newStatus,
    String? changedBy,
    String? reason,
    String? currentBrokerId,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final history = List<StatusHistory>.from(property.statusHistory);
      history.add(StatusHistory(
        from: property.status,
        to: newStatus,
        changedAt: DateTime.now(),
        changedBy: changedBy,
        reason: reason,
      ));

      final updates = <String, dynamic>{
        'status': newStatus.toString().split('.').last,
        'statusChangedAt': DateTime.now().toIso8601String(),
        'statusHistory': history.map((e) => e.toMap()).toList(),
      };

      if (currentBrokerId != null) {
        updates['currentBrokerId'] = currentBrokerId;
      }

      // 가계약/거래완료 시 추가 처리
      if (newStatus == PropertyStatus.depositTaken) {
        updates['depositTakenAt'] = DateTime.now().toIso8601String();
        updates['virtualPhoneActive'] = false; // 안심번호 비활성화

        // 중개사 통계 업데이트 (가계약)
        if (currentBrokerId != null) {
          await FirebaseService().updateBrokerStatsOnDeal(
            brokerId: currentBrokerId,
            isDepositTaken: true,
          );
        }
      } else if (newStatus == PropertyStatus.sold) {
        updates['soldAt'] = DateTime.now().toIso8601String();
        updates['isActive'] = false;
        updates['virtualPhoneActive'] = false;

        // 중개사 통계 업데이트 (거래 완료)
        final finalBrokerId = currentBrokerId ?? property.finalBrokerId;
        if (finalBrokerId != null) {
          await FirebaseService().updateBrokerStatsOnDeal(
            brokerId: finalBrokerId,
            isDepositTaken: false,
          );
        }
      }

      await updateProperty(propertyId, updates);
      Logger.info('Property status updated: $propertyId -> $newStatus');

      // 가계약/거래완료 시 모든 중개사에게 알림 전송
      if (newStatus == PropertyStatus.depositTaken || newStatus == PropertyStatus.sold) {
        await _notifyAllBrokers(propertyId, newStatus);
      }
    } catch (e) {
      Logger.error('Failed to update property status', error: e);
      rethrow;
    }
  }

  /// 방문 예약 생성
  Future<void> createVisitSchedule({
    required String propertyId,
    required VisitSchedule schedule,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      // 동일 시간대 중복 확인
      final hasConflict = property.visitSchedules.any((s) =>
        s.scheduledAt == schedule.scheduledAt &&
        (s.status == VisitStatus.approved || s.status == VisitStatus.requested));

      if (hasConflict) {
        throw Exception('Time slot already booked');
      }

      final schedules = List<VisitSchedule>.from(property.visitSchedules);
      schedules.add(schedule);

      await updateProperty(propertyId, {
        'visitSchedules': schedules.map((e) => e.toMap()).toList(),
      });

      Logger.info('Visit schedule created: ${schedule.id}');
    } catch (e) {
      Logger.error('Failed to create visit schedule', error: e);
      rethrow;
    }
  }

  /// 방문 예약 상태 업데이트
  Future<void> updateVisitSchedule({
    required String propertyId,
    required String scheduleId,
    required VisitStatus status,
    String? feedback,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final schedules = List<VisitSchedule>.from(property.visitSchedules);
      final index = schedules.indexWhere((s) => s.id == scheduleId);
      if (index == -1) {
        throw Exception('Schedule not found: $scheduleId');
      }

      final updatedSchedule = VisitSchedule(
        id: schedules[index].id,
        brokerId: schedules[index].brokerId,
        brokerName: schedules[index].brokerName,
        scheduledAt: schedules[index].scheduledAt,
        status: status,
        note: schedules[index].note,
        feedback: feedback ?? schedules[index].feedback,
        feedbackSubmittedAt: feedback != null ? DateTime.now() : schedules[index].feedbackSubmittedAt,
      );

      schedules[index] = updatedSchedule;

      await updateProperty(propertyId, {
        'visitSchedules': schedules.map((e) => e.toMap()).toList(),
      });

      // 방문 승인 시 매물 상태를 inquiry로 변경
      if (status == VisitStatus.approved && property.status == PropertyStatus.active) {
        await updateStatus(
          propertyId: propertyId,
          newStatus: PropertyStatus.inquiry,
          changedBy: property.userId,
          reason: 'Visit approved',
          currentBrokerId: updatedSchedule.brokerId,
        );
      }

      Logger.info('Visit schedule updated: $scheduleId -> $status');
    } catch (e) {
      Logger.error('Failed to update visit schedule', error: e);
      rethrow;
    }
  }

  /// 협의 로그 추가
  Future<void> addNegotiationLog({
    required String propertyId,
    required NegotiationLog log,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final negotiations = List<NegotiationLog>.from(property.negotiations);
      negotiations.add(log);

      await updateProperty(propertyId, {
        'negotiations': negotiations.map((e) => e.toMap()).toList(),
      });

      // 첫 협의 로그 시 상태를 underOffer로 변경
      if (negotiations.length == 1 && property.status == PropertyStatus.inquiry) {
        await updateStatus(
          propertyId: propertyId,
          newStatus: PropertyStatus.underOffer,
          changedBy: log.brokerId,
          reason: 'Negotiation started',
          currentBrokerId: log.brokerId,
        );
      }

      Logger.info('Negotiation log added: ${log.id}');
    } catch (e) {
      Logger.error('Failed to add negotiation log', error: e);
      rethrow;
    }
  }

  /// 판매자 역제안 추가
  Future<void> addSellerCounterOffer({
    required String propertyId,
    required String brokerId,
    required String brokerName,
    required double counterPrice,
    String? conditions,
    String? message,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      // 협상 로그 추가
      final log = NegotiationLog(
        id: 'counter_${DateTime.now().millisecondsSinceEpoch}',
        brokerId: brokerId,
        brokerName: brokerName,
        proposedPrice: counterPrice,
        conditions: conditions,
        buyerFeedback: message, // 판매자 메시지로 사용
        createdAt: DateTime.now(),
      );

      final negotiations = List<NegotiationLog>.from(property.negotiations);
      negotiations.add(log);

      // 중개사 응답 업데이트 (승인 상태로 - 역제안은 연락 교환 후 진행)
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      if (brokerResponses.containsKey(brokerId)) {
        brokerResponses[brokerId] = brokerResponses[brokerId]!.copyWith(
          stage: BrokerStage.approved,
        );
      }

      await updateProperty(propertyId, {
        'negotiations': negotiations.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
        'status': PropertyStatus.underOffer.toString().split('.').last,
      });

      // 중개사에게 알림 전송
      final firebaseService = FirebaseService();
      await firebaseService.sendNotification(
        userId: brokerId,
        type: 'counter_offer',
        title: '판매자 역제안',
        message: '${property.userName}님이 ${_formatPrice(counterPrice)}에 역제안했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Seller counter-offer added: $propertyId -> $brokerId');
    } catch (e) {
      Logger.error('Failed to add seller counter-offer', error: e);
      rethrow;
    }
  }

  String _formatPrice(double price) {
    if (price >= 10000) {
      final billions = (price / 10000).floor();
      final remainder = (price % 10000).floor();
      if (remainder > 0) {
        return '$billions억 $remainder만원';
      }
      return '$billions억원';
    }
    return '${price.toStringAsFixed(0)}만원';
  }

  /// 거래 완료 처리
  Future<void> completeTransaction({
    required String propertyId,
    required String finalBrokerId,
    required double finalPrice,
  }) async {
    try {
      await updateProperty(propertyId, {
        'finalBrokerId': finalBrokerId,
        'finalPrice': finalPrice,
      });

      await updateStatus(
        propertyId: propertyId,
        newStatus: PropertyStatus.sold,
        changedBy: finalBrokerId,
        reason: 'Transaction completed',
      );

      Logger.info('Transaction completed: $propertyId');
    } catch (e) {
      Logger.error('Failed to complete transaction', error: e);
      rethrow;
    }
  }

  /// 매물 삭제 (소프트 삭제)
  Future<void> deleteProperty(String propertyId) async {
    try {
      await updateProperty(propertyId, {
        'isDeleted': true,
        'isActive': false,
      });
      Logger.info('Property deleted: $propertyId');
    } catch (e) {
      Logger.error('Failed to delete property', error: e);
      rethrow;
    }
  }

  /// 고유 ID 생성 시 시퀀스 조회
  Future<int> getNextSequence(String region) async {
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}';
      final prefix = '${region.toUpperCase()}-$dateStr-';

      final snapshot = await _firestore
        .collection(_collectionName)
        .where('id', isGreaterThanOrEqualTo: prefix)
        .where('id', isLessThan: '${prefix}999999')
        .orderBy('id', descending: true)
        .limit(1)
        .get();

      if (snapshot.docs.isEmpty) {
        return 1;
      }

      final lastId = snapshot.docs.first.id;
      final seqStr = lastId.split('-').last;
      return int.parse(seqStr) + 1;
    } catch (e) {
      Logger.error('Failed to get next sequence', error: e);
      return 1;
    }
  }

  /// 모든 수락 중개사에게 알림 전송 (성사 중개사 제외)
  ///
  /// 가계약/거래완료 시 해당 매물에 참여했던 다른 모든 중개사에게
  /// 거래 성사 알림을 전송하여 중복 영업을 방지합니다.
  Future<void> _notifyAllBrokers(String propertyId, PropertyStatus status) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) return;

      // 성사 중개사 ID (알림 제외 대상)
      final winnerId = property.finalBrokerId;

      // 참여했던 모든 중개사 중 성사 중개사 제외
      final brokerIdsToNotify = property.brokerResponses.entries
        .where((e) =>
          e.value.hasViewed &&
          e.key != winnerId)  // 성사 중개사 제외
        .map((e) => e.key)
        .toList();

      if (brokerIdsToNotify.isEmpty) {
        Logger.info('No brokers to notify for property: $propertyId');
        return;
      }

      // 알림 내용 결정
      String title;
      String message;
      String type;

      if (status == PropertyStatus.depositTaken) {
        title = '매물 가계약 성사 알림';
        message = '${property.roadAddress} 매물이 다른 중개사와 가계약되었습니다.\n해당 매물 영업을 중단해주세요.';
        type = NotificationType.propertyDepositTaken;
      } else if (status == PropertyStatus.sold) {
        title = '매물 거래 완료 알림';
        message = '${property.roadAddress} 매물의 거래가 완료되었습니다.\n수고하셨습니다!';
        type = NotificationType.propertySold;
      } else {
        // 다른 상태는 알림 불필요
        return;
      }

      // 대량 알림 전송
      await FirebaseService().sendBulkNotifications(
        userIds: brokerIdsToNotify,
        title: title,
        message: message,
        type: type,
        relatedId: propertyId,
        additionalData: {
          'propertyAddress': property.roadAddress,
          'winnerBrokerId': winnerId,
        },
      );

      Logger.info('Notifications sent to ${brokerIdsToNotify.length} brokers for property: $propertyId');
    } catch (e) {
      Logger.error('Failed to notify brokers', error: e);
      // 알림 실패해도 거래 처리는 계속 진행
    }
  }

  /// 가용 시간대 설정
  Future<void> setAvailableSlots({
    required String propertyId,
    required Map<String, List<TimeSlot>> slots,
  }) async {
    try {
      final slotsMap = slots.map(
        (date, timeSlots) => MapEntry(date, timeSlots.map((s) => s.toMap()).toList()),
      );

      await updateProperty(propertyId, {
        'availableSlots': slotsMap,
      });

      Logger.info('Available slots updated for property: $propertyId');
    } catch (e) {
      Logger.error('Failed to set available slots', error: e);
      rethrow;
    }
  }

  // ========================================
  // 매물 검증 시스템 (Phase 2)
  // ========================================

  /// 중복 주소 체크
  /// 동일한 도로명주소로 이미 활성 상태인 매물이 있는지 확인
  Future<MLSProperty?> checkDuplicateAddress(String roadAddress) async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('roadAddress', isEqualTo: roadAddress)
        .where('isDeleted', isEqualTo: false)
        .get();

      // 활성 상태인 매물만 중복으로 판단
      // (pending, active, inquiry, underOffer, depositTaken)
      final activeStatuses = [
        PropertyStatus.pending,
        PropertyStatus.active,
        PropertyStatus.inquiry,
        PropertyStatus.underOffer,
        PropertyStatus.depositTaken,
      ].map((s) => s.toString().split('.').last).toSet();

      for (final doc in snapshot.docs) {
        final property = MLSProperty.fromMap(doc.data());
        final statusStr = property.status.toString().split('.').last;
        if (activeStatuses.contains(statusStr)) {
          return property;
        }
      }

      return null;
    } catch (e) {
      Logger.error('Failed to check duplicate address', error: e);
      return null;
    }
  }

  /// 매물 검증 요청 (등록 시 자동 호출)
  /// 중복 없으면 자동 승인 → active로 전환
  /// 중복 있으면 pending 유지 + 관리자 검토 필요
  Future<VerificationStatus> submitForVerification(String propertyId) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      // 중복 주소 체크
      final duplicate = await checkDuplicateAddress(property.roadAddress);

      final now = DateTime.now();
      VerificationStatus verificationStatus;
      PropertyStatus newStatus;

      if (duplicate != null && duplicate.id != propertyId) {
        // 중복 감지 → pending 유지, 관리자 검토 필요
        verificationStatus = VerificationStatus.addressDuplicate;
        newStatus = PropertyStatus.pending;

        await updateProperty(propertyId, {
          'status': newStatus.toString().split('.').last,
          'verificationStatus': verificationStatus.toString().split('.').last,
          'verificationRequestedAt': now.toIso8601String(),
          'duplicatePropertyId': duplicate.id,
          'updatedAt': now.toIso8601String(),
        });

        Logger.warning('Duplicate address detected for property: $propertyId');
      } else {
        // 중복 없음 → 자동 승인
        verificationStatus = VerificationStatus.autoApproved;
        newStatus = PropertyStatus.active;

        await updateProperty(propertyId, {
          'status': newStatus.toString().split('.').last,
          'verificationStatus': verificationStatus.toString().split('.').last,
          'verificationRequestedAt': now.toIso8601String(),
          'verifiedAt': now.toIso8601String(),
          'verifiedBy': 'auto',
          'isActive': true,
          'updatedAt': now.toIso8601String(),
        });

        // 향후 기능: 자동 승인 시 지역 중개사에게 자동 배포
        // 현재는 수동 배포 방식 사용

        Logger.info('Property auto-approved: $propertyId');
      }

      return verificationStatus;
    } catch (e) {
      Logger.error('Failed to submit for verification', error: e);
      rethrow;
    }
  }

  /// 매물 검증 승인 (관리자용)
  Future<void> approveProperty({
    required String propertyId,
    required String adminId,
  }) async {
    try {
      final now = DateTime.now();

      await updateProperty(propertyId, {
        'status': PropertyStatus.active.toString().split('.').last,
        'verificationStatus': VerificationStatus.adminApproved.toString().split('.').last,
        'verifiedAt': now.toIso8601String(),
        'verifiedBy': adminId,
        'isActive': true,
        'updatedAt': now.toIso8601String(),
      });

      // 향후 기능: 관리자 승인 시 지역 중개사에게 자동 배포
      // 현재는 수동 배포 방식 사용

      Logger.info('Property approved by admin: $propertyId');
    } catch (e) {
      Logger.error('Failed to approve property', error: e);
      rethrow;
    }
  }

  /// 매물 검증 거절 (관리자용)
  Future<void> rejectProperty({
    required String propertyId,
    required String adminId,
    required String reason,
  }) async {
    try {
      final now = DateTime.now();
      final property = await getProperty(propertyId);

      await updateProperty(propertyId, {
        'status': PropertyStatus.rejected.toString().split('.').last,
        'verificationStatus': VerificationStatus.rejected.toString().split('.').last,
        'verifiedAt': now.toIso8601String(),
        'verifiedBy': adminId,
        'rejectionReason': reason,
        'isActive': false,
        'updatedAt': now.toIso8601String(),
      });

      // 매도인에게 거절 알림 전송
      if (property != null) {
        await FirebaseService().sendNotification(
          userId: property.userId,
          title: '매물 등록 거절',
          message: '등록하신 매물이 검증 과정에서 거절되었습니다.\n사유: $reason',
          type: 'property_rejected',
          relatedId: propertyId,
        );
      }

      Logger.info('Property rejected by admin: $propertyId, reason: $reason');
    } catch (e) {
      Logger.error('Failed to reject property', error: e);
      rethrow;
    }
  }

  /// 검증 대기 매물 목록 조회 (관리자용)
  Stream<List<MLSProperty>> getPendingProperties() {
    return _firestore
      .collection(_collectionName)
      .where('status', isEqualTo: PropertyStatus.pending.toString().split('.').last)
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: false) // 오래된 순
      .snapshots()
      .map((snapshot) =>
        snapshot.docs.map((doc) => MLSProperty.fromMap(doc.data())).toList());
  }

  /// 검증 대기 매물 수 조회 (관리자용)
  Future<int> getPendingPropertyCount() async {
    try {
      final snapshot = await _firestore
        .collection(_collectionName)
        .where('status', isEqualTo: PropertyStatus.pending.toString().split('.').last)
        .where('isDeleted', isEqualTo: false)
        .count()
        .get();

      return snapshot.count ?? 0;
    } catch (e) {
      Logger.error('Failed to get pending property count', error: e);
      return 0;
    }
  }

  // ========================================
  // 방문 요청 관리 (VisitRequest CRUD)
  // ========================================

  /// 방문 요청 생성 (중개사가 요청)
  ///
  /// 중개사가 매수/임차 희망자 정보와 희망 방문 일시를 제출합니다.
  /// 생성 시 BrokerResponse의 stage도 'requested'로 업데이트됩니다.
  Future<VisitRequest> createVisitRequest({
    required String propertyId,
    required String brokerId,
    required String brokerName,
    required double proposedPrice,
    required DateTime requestedDateTime,
    String? brokerCompany,
    String? brokerPhone,
    String? brokerUid, // Firebase UID (Firestore 규칙용)
    String? message,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      // 중복 요청 방지: 같은 중개사의 pending 요청이 있는지 확인
      final existingPending = property.visitRequests.where(
        (r) => r.brokerId == brokerId && r.status == VisitRequestStatus.pending,
      ).toList();

      if (existingPending.isNotEmpty) {
        throw Exception('이미 대기 중인 방문 요청이 있습니다');
      }

      final now = DateTime.now();
      final requestId = 'vr_${now.millisecondsSinceEpoch}_$brokerId';

      final visitRequest = VisitRequest(
        id: requestId,
        propertyId: propertyId,
        brokerId: brokerId,
        brokerName: brokerName,
        brokerCompany: brokerCompany,
        brokerPhone: brokerPhone,
        proposedPrice: proposedPrice,
        requestedDateTime: requestedDateTime,
        message: message,
        createdAt: now,
      );

      // 방문 요청 리스트 업데이트
      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      visitRequests.add(visitRequest);

      // 중개사 응답 상태도 업데이트 (requested 단계로)
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existingResponse = brokerResponses[brokerId];

      brokerResponses[brokerId] = BrokerResponse(
        brokerId: brokerId,
        brokerName: brokerName,
        brokerCompany: brokerCompany ?? existingResponse?.brokerCompany,
        brokerPhone: brokerPhone ?? existingResponse?.brokerPhone,
        stage: BrokerStage.requested,
        receivedAt: existingResponse?.receivedAt ?? now,
        viewedAt: existingResponse?.viewedAt ?? now,
      );

      // targetBrokerIds에 중개사 추가 (내 참여 탭에 표시되도록)
      final targetBrokerIds = List<String>.from(property.targetBrokerIds);
      if (!targetBrokerIds.contains(brokerId)) {
        targetBrokerIds.add(brokerId);
      }
      // Firebase UID도 추가 (Firestore 보안 규칙에서 request.auth.uid로 확인)
      if (brokerUid != null && !targetBrokerIds.contains(brokerUid)) {
        targetBrokerIds.add(brokerUid);
      }

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
        'targetBrokerIds': targetBrokerIds,
        'broadcastedAt': property.broadcastedAt?.toIso8601String() ?? now.toIso8601String(),
      });

      // 판매자에게 알림 전송
      await FirebaseService().sendNotification(
        userId: property.userId,
        type: 'visit_request',
        title: '새 방문 요청',
        message: '$brokerName 중개사가 ${_formatPrice(proposedPrice)}에 방문을 요청했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Visit request created: $requestId for property: $propertyId');
      return visitRequest;
    } catch (e) {
      Logger.error('Failed to create visit request', error: e);
      rethrow;
    }
  }

  /// 방문 요청 승인 (판매자가 승인 → 연락처 교환)
  ///
  /// 승인 시 양측의 연락처가 공개됩니다.
  /// BrokerResponse의 stage는 'approved'로 업데이트됩니다.
  Future<void> approveVisitRequest({
    required String propertyId,
    required String requestId,
    required String sellerPhone,
    String? sellerMessage,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];
      final now = DateTime.now();

      // 요청 상태 업데이트
      final updatedRequest = request.copyWith(
        status: VisitRequestStatus.approved,
        respondedAt: now,
        sellerResponse: sellerMessage,
        sellerPhone: sellerPhone, // 판매자 연락처 공개
        contactExchangedAt: now,
      );
      visitRequests[index] = updatedRequest;

      // 중개사 응답 상태 업데이트 (approved 단계 + 연락처 공개)
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existingResponse = brokerResponses[request.brokerId];

      brokerResponses[request.brokerId] = BrokerResponse(
        brokerId: request.brokerId,
        brokerName: request.brokerName,
        brokerCompany: request.brokerCompany ?? existingResponse?.brokerCompany,
        brokerPhone: request.brokerPhone ?? existingResponse?.brokerPhone,
        stage: BrokerStage.approved,
        receivedAt: existingResponse?.receivedAt ?? now,
        viewedAt: existingResponse?.viewedAt ?? now,
      );

      // 매물 상태도 inquiry로 변경 (첫 승인인 경우)
      final newStatus = property.status == PropertyStatus.active
          ? PropertyStatus.inquiry
          : property.status;

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
        'status': newStatus.toString().split('.').last,
      });

      // 중개사에게 승인 알림 전송
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'visit_approved',
        title: '방문 요청 승인',
        message: '${property.userName}님이 방문 요청을 승인했습니다. 연락처: $sellerPhone',
        relatedId: propertyId,
      );

      Logger.info('Visit request approved: $requestId, contact exchanged');
    } catch (e) {
      Logger.error('Failed to approve visit request', error: e);
      rethrow;
    }
  }

  /// 방문 요청 거절 (판매자가 거절)
  Future<void> rejectVisitRequest({
    required String propertyId,
    required String requestId,
    String? reason,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];
      final now = DateTime.now();

      // 요청 상태 업데이트
      final updatedRequest = request.copyWith(
        status: VisitRequestStatus.rejected,
        respondedAt: now,
        sellerResponse: reason,
      );
      visitRequests[index] = updatedRequest;

      // BrokerResponse stage는 viewed로 유지 (거절해도 다시 요청 가능)
      // 단, hasRequested가 false가 되도록 stage는 viewed로 변경
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existingResponse = brokerResponses[request.brokerId];

      if (existingResponse != null && existingResponse.stage == BrokerStage.requested) {
        brokerResponses[request.brokerId] = existingResponse.copyWith(
          stage: BrokerStage.viewed,
        );
      }

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
      });

      // 중개사에게 거절 알림 전송
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'visit_rejected',
        title: '방문 요청 거절',
        message: reason != null
            ? '${property.userName}님이 방문 요청을 거절했습니다: $reason'
            : '${property.userName}님이 방문 요청을 거절했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Visit request rejected: $requestId');
    } catch (e) {
      Logger.error('Failed to reject visit request', error: e);
      rethrow;
    }
  }

  /// 다른 시간 제안 (판매자가 대안 제시)
  Future<void> suggestAlternativeTime({
    required String propertyId,
    required String requestId,
    required DateTime alternativeDateTime,
    String? message,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];
      final now = DateTime.now();

      // 요청 상태 업데이트 (reschedule)
      final updatedRequest = request.copyWith(
        status: VisitRequestStatus.reschedule,
        respondedAt: now,
        sellerResponse: message,
        alternativeDateTime: alternativeDateTime,
      );
      visitRequests[index] = updatedRequest;

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
      });

      // 중개사에게 알림 전송
      final dateStr = '${alternativeDateTime.month}/${alternativeDateTime.day} '
          '${alternativeDateTime.hour}:${alternativeDateTime.minute.toString().padLeft(2, '0')}';
      await FirebaseService().sendNotification(
        userId: request.brokerId,
        type: 'visit_reschedule',
        title: '다른 시간 제안',
        message: '${property.userName}님이 $dateStr 시간을 제안했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Alternative time suggested for visit request: $requestId');
    } catch (e) {
      Logger.error('Failed to suggest alternative time', error: e);
      rethrow;
    }
  }

  /// 방문 요청 취소 (중개사가 취소)
  Future<void> cancelVisitRequest({
    required String propertyId,
    required String requestId,
    String? reason,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];

      // pending 상태인 경우만 취소 가능
      if (request.status != VisitRequestStatus.pending &&
          request.status != VisitRequestStatus.reschedule) {
        throw Exception('이미 처리된 요청은 취소할 수 없습니다');
      }

      // 요청 상태 업데이트
      final updatedRequest = request.copyWith(
        status: VisitRequestStatus.cancelled,
      );
      visitRequests[index] = updatedRequest;

      // BrokerResponse stage를 viewed로 변경
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existingResponse = brokerResponses[request.brokerId];

      if (existingResponse != null && existingResponse.stage == BrokerStage.requested) {
        brokerResponses[request.brokerId] = existingResponse.copyWith(
          stage: BrokerStage.viewed,
        );
      }

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
      });

      // 판매자에게 알림 전송
      await FirebaseService().sendNotification(
        userId: property.userId,
        type: 'visit_cancelled',
        title: '방문 요청 취소',
        message: '${request.brokerName} 중개사가 방문 요청을 취소했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Visit request cancelled: $requestId');
    } catch (e) {
      Logger.error('Failed to cancel visit request', error: e);
      rethrow;
    }
  }

  /// 다른 시간 제안 수락 (중개사가 판매자의 제안 시간 수락)
  Future<void> acceptAlternativeTime({
    required String propertyId,
    required String requestId,
  }) async {
    try {
      final property = await getProperty(propertyId);
      if (property == null) {
        throw Exception('Property not found: $propertyId');
      }

      final visitRequests = List<VisitRequest>.from(property.visitRequests);
      final index = visitRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) {
        throw Exception('Visit request not found: $requestId');
      }

      final request = visitRequests[index];

      if (request.status != VisitRequestStatus.reschedule) {
        throw Exception('시간 조율 상태가 아닙니다');
      }

      if (request.alternativeDateTime == null) {
        throw Exception('제안된 시간이 없습니다');
      }

      // 요청 시간을 제안 시간으로 변경하고 다시 pending으로
      final updatedRequest = request.copyWith(
        requestedDateTime: request.alternativeDateTime,
        status: VisitRequestStatus.pending,
      );
      visitRequests[index] = updatedRequest;

      // BrokerResponse stage를 requested로 유지
      final brokerResponses = Map<String, BrokerResponse>.from(property.brokerResponses);
      final existingResponse = brokerResponses[request.brokerId];

      if (existingResponse != null) {
        brokerResponses[request.brokerId] = existingResponse.copyWith(
          stage: BrokerStage.requested,
        );
      }

      await updateProperty(propertyId, {
        'visitRequests': visitRequests.map((e) => e.toMap()).toList(),
        'brokerResponses': brokerResponses.map((k, v) => MapEntry(k, v.toMap())),
      });

      // 판매자에게 알림 전송
      final dateStr = '${updatedRequest.requestedDateTime.month}/${updatedRequest.requestedDateTime.day}';
      await FirebaseService().sendNotification(
        userId: property.userId,
        type: 'time_accepted',
        title: '시간 제안 수락',
        message: '${request.brokerName} 중개사가 $dateStr 방문 시간에 동의했습니다.',
        relatedId: propertyId,
      );

      Logger.info('Alternative time accepted for visit request: $requestId');
    } catch (e) {
      Logger.error('Failed to accept alternative time', error: e);
      rethrow;
    }
  }
}
