import 'package:url_launcher/url_launcher.dart';
import '../api_request/log_service.dart';

class CallUtils {
  static Future<void> makeCall(String phoneNumber, {String? relatedId}) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    
    // 안심번호 로직 (임시: 실제로는 050 등으로 변환하는 API 호출 필요)
    // 여기서는 010 -> 050 으로 시각적 처리만 예시로 둠
    // String safeNumber = phoneNumber.replaceFirst('010', '050'); 

    if (await canLaunchUrl(launchUri)) {
      // 전화 걸기 시도 로그
      LogService().log(
        actionType: 'call_attempt', 
        target: 'CallUtils',
        metadata: {'phone': phoneNumber, 'relatedId': relatedId},
      );
      
      await launchUrl(launchUri);
    } else {
      throw 'Could not launch $launchUri';
    }
  }
}

