import 'package:flutter/material.dart';
import 'package:property/utils/network_status.dart';

/// 오프라인 상태를 표시하는 배너 위젯
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.child,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final NetworkStatus _networkStatus = NetworkStatus();
  bool? _isOnline;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkNetworkStatus();
    // 주기적으로 네트워크 상태 확인
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _checkNetworkStatus();
      }
    });
  }

  Future<void> _checkNetworkStatus() async {
    if (_isChecking) return;
    
    setState(() {
      _isChecking = true;
    });

    final isOnline = await _networkStatus.isOnline(forceCheck: true);
    
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 오프라인 배너 (오프라인일 때만 표시)
        if (_isOnline == false)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange,
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '인터넷 연결이 없습니다. 일부 기능이 제한될 수 있습니다.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                  onPressed: _checkNetworkStatus,
                  tooltip: '연결 확인',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        // 메인 콘텐츠
        widget.child,
      ],
    );
  }
}

