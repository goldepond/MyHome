/// 사용자 친화적 에러 메시지 상수
class ErrorMessages {
  // 공통 에러 메시지
  static const String unknown = '알 수 없는 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
  static const String network = '네트워크 연결을 확인해주세요.\n인터넷 연결 상태를 확인한 후 다시 시도해주세요.';
  static const String offline = '인터넷에 연결되어 있지 않습니다.\n네트워크 연결을 확인한 후 다시 시도해주세요.';
  static const String timeout = '요청 시간이 초과되었습니다.\n네트워크 상태를 확인한 후 다시 시도해주세요.';
  static const String server = '서버 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
  static const String permission = '권한이 없습니다.\n필요한 권한을 확인해주세요.';
  static const String notFound = '요청한 정보를 찾을 수 없습니다.';
  static const String validation = '입력한 정보를 확인해주세요.';

  // 인증 관련 에러
  static const String authRequired = '로그인이 필요합니다.';
  static const String authFailed = '로그인에 실패했습니다.\n이메일과 전화번호를 확인해주세요.';
  static const String authExpired = '로그인 세션이 만료되었습니다.\n다시 로그인해주세요.';
  static const String userNotFound = '등록되지 않은 사용자입니다.\n회원가입을 먼저 진행해주세요.';
  static const String wrongPassword = '전화번호가 올바르지 않습니다.';
  static const String weakPassword = '전화번호 형식이 올바르지 않습니다.\n01012345678 형식으로 입력해주세요.';
  static const String emailAlreadyInUse = '이미 사용 중인 이메일입니다.\n다른 이메일을 사용하거나 로그인해주세요.';
  static const String invalidEmail = '올바른 이메일 형식을 입력해주세요.';
  static const String requiresRecentLogin = '보안을 위해 다시 로그인한 후 시도해주세요.';

  // 회원가입 관련
  static const String signupFailed = '회원가입에 실패했습니다.\n입력한 정보를 확인한 후 다시 시도해주세요.';
  static const String signupSuccess = '회원가입이 완료되었습니다.';

  // 데이터 조회 관련
  static const String loadDataFailed = '데이터를 불러오는데 실패했습니다.\n다시 시도해주세요.';
  static const String saveDataFailed = '데이터 저장에 실패했습니다.\n다시 시도해주세요.';
  static const String deleteDataFailed = '데이터 삭제에 실패했습니다.\n다시 시도해주세요.';
  static const String updateDataFailed = '데이터 수정에 실패했습니다.\n다시 시도해주세요.';
  static const String dataNotFound = '데이터를 찾을 수 없습니다.';

  // 주소 검색 관련
  static const String addressSearchFailed = '주소 검색에 실패했습니다.\n검색어를 확인한 후 다시 시도해주세요.';
  static const String addressNotFound = '검색 결과가 없습니다.\n다른 검색어로 시도해주세요.';
  static const String addressParseFailed = '주소 정보를 처리하는 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';

  // 공인중개사 검색 관련
  static const String brokerSearchFailed = '공인중개사 검색에 실패했습니다.\n잠시 후 다시 시도해주세요.';
  static const String brokerNotFound = '공인중개사를 찾을 수 없습니다.';
  static const String brokerInfoLoadFailed = '공인중개사 정보를 불러오는데 실패했습니다.';

  // 견적 관련
  static const String quoteRequestFailed = '견적 요청에 실패했습니다.\n입력한 정보를 확인한 후 다시 시도해주세요.';
  static const String quoteLoadFailed = '견적 정보를 불러오는데 실패했습니다.';
  static const String quoteSaveFailed = '견적 저장에 실패했습니다.\n다시 시도해주세요.';
  static const String quoteNotFound = '견적 정보를 찾을 수 없습니다.';

  // 등기부등본 관련
  static const String registerLoadFailed = '등기부등본 조회에 실패했습니다.\n입력한 정보를 확인한 후 다시 시도해주세요.';
  static const String registerParseFailed = '등기부등본 정보를 처리하는 중 오류가 발생했습니다.';
  static const String registerInvalidInfo = '등기부등본 조회 정보가 올바르지 않습니다.\n입력한 정보를 확인해주세요.';

  // 매물 관련
  static const String propertyLoadFailed = '매물 정보를 불러오는데 실패했습니다.';
  static const String propertySaveFailed = '매물 등록에 실패했습니다.\n입력한 정보를 확인한 후 다시 시도해주세요.';
  static const String propertyUpdateFailed = '매물 수정에 실패했습니다.\n다시 시도해주세요.';
  static const String propertyDeleteFailed = '매물 삭제에 실패했습니다.\n다시 시도해주세요.';
  static const String propertyNotFound = '매물 정보를 찾을 수 없습니다.';

  // 파일 업로드 관련
  static const String uploadFailed = '파일 업로드에 실패했습니다.\n파일 크기와 형식을 확인한 후 다시 시도해주세요.';
  static const String fileTooLarge = '파일 크기가 너무 큽니다.\n더 작은 파일을 선택해주세요.';
  static const String invalidFileFormat = '지원하지 않는 파일 형식입니다.\n올바른 파일 형식을 선택해주세요.';

  // 권한 관련
  static const String adminRequired = '관리자 권한이 필요합니다.';
  static const String brokerRequired = '공인중개사 권한이 필요합니다.';

  // 기타
  static const String retryLater = '잠시 후 다시 시도해주세요.';
  static const String contactSupport = '문제가 계속되면 고객센터로 문의해주세요.';
}

