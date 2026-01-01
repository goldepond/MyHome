/// 선택된 주소 결과 정보
/// 
/// GPS 기반 검색과 주소 입력 검색 모두에서 사용되는 공통 결과 모델입니다.
class SelectedAddressResult {
  /// 선택된 주소
  final String address;

  /// 위도 (GPS 기반 검색의 경우 필수, 주소 입력 검색의 경우 선택)
  final double? latitude;

  /// 경도 (GPS 기반 검색의 경우 필수, 주소 입력 검색의 경우 선택)
  final double? longitude;

  /// 전체 주소 API 데이터 (주소 입력 검색의 경우 포함)
  final Map<String, String>? fullAddrAPIData;

  /// 검색 반경 (미터 단위, 슬라이더로 선택한 값)
  final double? radiusMeters;

  const SelectedAddressResult({
    required this.address,
    this.latitude,
    this.longitude,
    this.fullAddrAPIData,
    this.radiusMeters,
  });
}

