#!/bin/bash
# 프로덕션 빌드 스크립트 (Linux/Mac)
# 웹, Android, iOS 프로덕션 빌드 자동화

set -e

echo "========================================"
echo "프로덕션 빌드 스크립트"
echo "========================================"
echo ""

# 결과 디렉토리 생성
RESULT_DIR="build_results"
mkdir -p "$RESULT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$RESULT_DIR/build_results_$TIMESTAMP.txt"

echo "빌드 시작 시간: $(date)"
echo "결과 파일: $RESULT_FILE"
echo ""

# Flutter 환경 확인
if ! command -v flutter &> /dev/null; then
    echo "[오류] Flutter가 설치되어 있지 않거나 PATH에 없습니다."
    exit 1
fi

# 의존성 설치
echo "[1/6] Flutter 의존성 확인..."
flutter pub get
echo ""

# 웹 빌드
echo "[2/6] 웹 프로덕션 빌드..."
echo "⚠️  API 키 환경 변수가 설정되어 있는지 확인하세요"
echo "최적화: HTML 렌더러 사용 (빠른 초기 로딩)"
echo ""

if flutter build web --release --base-href "/TESTHOME/" \
    --web-renderer html \
    --dart-define=JUSO_API_KEY="${JUSO_API_KEY}" \
    --dart-define=VWORLD_API_KEY="${VWORLD_API_KEY}" \
    --dart-define=VWORLD_GEOCODER_API_KEY="${VWORLD_GEOCODER_API_KEY}" \
    --dart-define=DATA_GO_KR_SERVICE_KEY="${DATA_GO_KR_SERVICE_KEY}" \
    --dart-define=NAVER_MAP_CLIENT_ID="${NAVER_MAP_CLIENT_ID}" \
    --dart-define=CODEF_CLIENT_ID="${CODEF_CLIENT_ID}" \
    --dart-define=CODEF_CLIENT_SECRET="${CODEF_CLIENT_SECRET}" \
    --dart-define=CODEF_PUBLIC_KEY="${CODEF_PUBLIC_KEY}" \
    --dart-define=REGISTER_API_KEY="${REGISTER_API_KEY}" \
    --dart-define=SEOUL_OPEN_API_KEY="${SEOUL_OPEN_API_KEY}"; then
    echo "[성공] 웹 빌드 완료: build/web"
    WEB_BUILD_RESULT=0
else
    echo "[실패] 웹 빌드 실패"
    WEB_BUILD_RESULT=1
fi
echo ""

# Android APK 빌드
echo "[3/6] Android APK 프로덕션 빌드..."
echo "⚠️  Keystore 설정이 필요할 수 있습니다"
echo ""

if [ -f "android/key.properties" ]; then
    if flutter build apk --release; then
        echo "[성공] Android APK 빌드 완료: build/app/outputs/flutter-apk/app-release.apk"
        ANDROID_BUILD_RESULT=0
    else
        echo "[실패] Android APK 빌드 실패"
        ANDROID_BUILD_RESULT=1
    fi
else
    echo "[경고] android/key.properties 파일이 없습니다. Keystore 설정이 필요합니다."
    echo "[스킵] Android APK 빌드를 건너뜁니다."
    ANDROID_BUILD_RESULT=2
fi
echo ""

# Android AAB 빌드
echo "[4/6] Android AAB (App Bundle) 프로덕션 빌드..."
if [ -f "android/key.properties" ]; then
    if flutter build appbundle --release; then
        echo "[성공] Android AAB 빌드 완료: build/app/outputs/bundle/release/app-release.aab"
        ANDROID_AAB_RESULT=0
    else
        echo "[실패] Android AAB 빌드 실패"
        ANDROID_AAB_RESULT=1
    fi
else
    echo "[스킵] Android AAB 빌드를 건너뜁니다 (Keystore 설정 필요)"
    ANDROID_AAB_RESULT=2
fi
echo ""

# iOS 빌드 (Mac에서만 가능)
echo "[5/6] iOS 프로덕션 빌드..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    if flutter build ios --release; then
        echo "[성공] iOS 빌드 완료"
        IOS_BUILD_RESULT=0
    else
        echo "[실패] iOS 빌드 실패"
        IOS_BUILD_RESULT=1
    fi
else
    echo "[스킵] iOS 빌드는 Mac 환경에서만 가능합니다."
    IOS_BUILD_RESULT=2
fi
echo ""

# 빌드 결과 요약
echo "[6/6] 빌드 결과 요약..."
echo "========================================"
echo "빌드 완료 시간: $(date)"
echo ""
echo "웹 빌드:"
if [ $WEB_BUILD_RESULT -eq 0 ]; then
    echo "  [성공]"
else
    echo "  [실패]"
fi
echo ""
echo "Android APK 빌드:"
if [ $ANDROID_BUILD_RESULT -eq 0 ]; then
    echo "  [성공]"
elif [ $ANDROID_BUILD_RESULT -eq 2 ]; then
    echo "  [스킵]"
else
    echo "  [실패]"
fi
echo ""
echo "Android AAB 빌드:"
if [ $ANDROID_AAB_RESULT -eq 0 ]; then
    echo "  [성공]"
elif [ $ANDROID_AAB_RESULT -eq 2 ]; then
    echo "  [스킵]"
else
    echo "  [실패]"
fi
echo ""
echo "iOS 빌드:"
if [ $IOS_BUILD_RESULT -eq 0 ]; then
    echo "  [성공]"
elif [ $IOS_BUILD_RESULT -eq 2 ]; then
    echo "  [스킵]"
else
    echo "  [실패]"
fi
echo ""
echo "========================================"

# 결과를 파일에 저장
cat > "$RESULT_FILE" << EOF
빌드 결과 요약
빌드 시간: $(date)

웹 빌드: $([ $WEB_BUILD_RESULT -eq 0 ] && echo "성공" || echo "실패")

Android APK 빌드: $([ $ANDROID_BUILD_RESULT -eq 0 ] && echo "성공" || ([ $ANDROID_BUILD_RESULT -eq 2 ] && echo "스킵" || echo "실패"))

Android AAB 빌드: $([ $ANDROID_AAB_RESULT -eq 0 ] && echo "성공" || ([ $ANDROID_AAB_RESULT -eq 2 ] && echo "스킵" || echo "실패"))

iOS 빌드: $([ $IOS_BUILD_RESULT -eq 0 ] && echo "성공" || echo "스킵 - Mac 환경 필요")
EOF

echo "결과가 저장되었습니다: $RESULT_FILE"
echo ""

# 전체 결과
if [ $WEB_BUILD_RESULT -eq 0 ]; then
    echo "전체 빌드: [부분 성공]"
    exit 0
else
    echo "전체 빌드: [실패]"
    exit 1
fi

