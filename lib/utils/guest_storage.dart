import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;

/// 게스트 사용자 UID를 로컬 스토리지에 저장/불러오기
class GuestStorage {
  static const String _guestUidKey = 'myhome_guest_uid';
  
  /// 게스트 UID 저장
  static Future<void> saveGuestUid(String uid) async {
    if (kIsWeb) {
      web.window.localStorage.setItem(_guestUidKey, uid);
    }
  }
  
  /// 게스트 UID 불러오기
  static String? getGuestUid() {
    if (kIsWeb) {
      return web.window.localStorage.getItem(_guestUidKey);
    }
    return null;
  }
  
  /// 게스트 UID 삭제
  static Future<void> clearGuestUid() async {
    if (kIsWeb) {
      web.window.localStorage.removeItem(_guestUidKey);
    }
  }
}

