import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/address_service.dart';


class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // 최소 2글자 이상일 때만 실제 API 호출 (너무 짧은 검색은 에러 안내)
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = [];
        _errorMessage = '도로명, 건물명, 지번 등을 최소 2글자 이상 입력해 주세요.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AddressService().searchRoadAddress(trimmed, page: 1);

      setState(() {
        _searchResults = result.fullData;
        _errorMessage = result.errorMessage;
        _isLoading = false;
      });
      if (mounted &&
          result.errorMessage == null &&
          result.fullData.length == 1) {
        final singleAddress = result.fullData.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _selectAddress(singleAddress);
        });
      }
    } catch (e, stackTrace) {
      // 디버그 모드에서 상세 로깅
      debugPrint('주소 검색 화면 예외 발생:');
      debugPrint('예외 타입: ${e.runtimeType}');
      debugPrint('예외 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');
      
      // 예외 메시지를 안전하게 추출
      String errorMsg = '알 수 없는 오류가 발생했습니다.';
      try {
        final exceptionStr = e.toString();
        final typeName = e.runtimeType.toString();
        
        // Instance of가 포함되지 않은 경우에만 메시지 사용
        if (!exceptionStr.contains('Instance of') && exceptionStr.isNotEmpty) {
          errorMsg = exceptionStr.length > 100 
              ? exceptionStr.substring(0, 100) 
              : exceptionStr;
        } else if (typeName.isNotEmpty && typeName != 'Object') {
          // 타입 이름으로 대체
          errorMsg = '$typeName 오류가 발생했습니다.';
        }
      } catch (_) {
        // 예외 처리 중 오류 발생 시 기본 메시지 사용
        debugPrint('예외 메시지 추출 중 오류 발생');
      }
      
      setState(() {
        _errorMessage = '오류가 발생했습니다: $errorMsg';
        _isLoading = false;
      });
    }
  }

  void _selectAddress(Map<String, String> address) {
    Navigator.pop(context, {
      'roadAddress': address['roadAddr'],
      'jibunAddress': address['jibunAddr'],
      'zipCode': address['zipNo'],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '주소를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.kBrown.withAlpha((0.2 * 255).toInt())),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.kBrown.withAlpha((0.1 * 255).toInt())),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.kBrown, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      // 실시간 자동완성: 2글자 이상 입력 시, 디바운스로 검색
                      _debounce?.cancel();

                      final trimmed = value.trim();
                      if (trimmed.length < 2) {
                        setState(() {
                          _searchResults = [];
                          _errorMessage = null; // 짧은 입력에서는 에러 없이 비우기
                          _isLoading = false;
                        });
                        return;
                      }

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _searchAddress(trimmed);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _searchAddress(_controller.text);
                  },
                  child: const Text('검색'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final address = _searchResults[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      title: Text(address['roadAddr'] ?? ''),
                      subtitle: Text(address['jibunAddr'] ?? ''),
                      onTap: () => _selectAddress(address),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
} 