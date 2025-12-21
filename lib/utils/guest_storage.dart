import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// 게스트 사용자 UID를 로컬 스토리지에 저장/불러오기
class GuestStorage {
  static const String _guestUidKey = 'myhome_guest_uid';
  
  /// 게스트 UID 저장
  static Future<void> saveGuestUid(String uid) async {
    if (kIsWeb) {
      html.window.localStorage[_guestUidKey] = uid;
    }
  }
  
  /// 게스트 UID 불러오기
  static String? getGuestUid() {
    if (kIsWeb) {
      return html.window.localStorage[_guestUidKey];
    }
    return null;
  }
  
  /// 게스트 UID 삭제
  static Future<void> clearGuestUid() async {
    if (kIsWeb) {
      html.window.localStorage.remove(_guestUidKey);
    }
  }
}

