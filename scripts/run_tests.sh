#!/bin/bash
# 테스트 실행 스크립트 (Linux/Mac)
# 필수 + 중요 테스트 케이스 실행 및 결과 기록

set -e

echo "========================================"
echo "QA 테스트 실행 스크립트"
echo "========================================"
echo ""

# 결과 디렉토리 생성
RESULT_DIR="test_results"
mkdir -p "$RESULT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="$RESULT_DIR/test_results_$TIMESTAMP.json"
SUMMARY_FILE="$RESULT_DIR/test_summary_$TIMESTAMP.txt"

echo "테스트 시작 시간: $(date)"
echo "결과 파일: $RESULT_FILE"
echo ""

# Flutter 환경 확인
if ! command -v flutter &> /dev/null; then
    echo "[오류] Flutter가 설치되어 있지 않거나 PATH에 없습니다."
    exit 1
fi

echo "[1/5] Flutter 의존성 확인..."
flutter pub get
echo ""

echo "[2/5] 단위 테스트 실행..."
if flutter test test/unit/ --reporter json > "$RESULT_DIR/unit_test_results.json" 2>&1; then
    echo "[성공] 단위 테스트 통과"
    UNIT_TEST_RESULT=0
else
    echo "[실패] 단위 테스트 실패"
    UNIT_TEST_RESULT=1
fi
echo ""

echo "[3/5] 통합 테스트 실행..."
if flutter test test/integration/ --reporter json > "$RESULT_DIR/integration_test_results.json" 2>&1; then
    echo "[성공] 통합 테스트 통과"
    INTEGRATION_TEST_RESULT=0
else
    echo "[실패] 통합 테스트 실패"
    INTEGRATION_TEST_RESULT=1
fi
echo ""

echo "[4/5] E2E 테스트 실행..."
# E2E 테스트는 실제 디바이스나 에뮬레이터가 필요하므로 선택적
if flutter test integration_test/ --reporter json > "$RESULT_DIR/e2e_test_results.json" 2>&1; then
    echo "[성공] E2E 테스트 통과"
    E2E_TEST_RESULT=0
else
    echo "[경고] E2E 테스트 실패 또는 스킵됨 (정상일 수 있음)"
    E2E_TEST_RESULT=1
fi
echo ""

echo "[5/5] 테스트 커버리지 생성..."
if flutter test --coverage; then
    if [ -f "coverage/lcov.info" ]; then
        echo "[성공] 커버리지 리포트 생성됨: coverage/lcov.info"
    else
        echo "[경고] 커버리지 리포트 생성 실패"
    fi
else
    echo "[경고] 커버리지 생성 실패"
fi
echo ""

# 결과 요약 생성
echo "========================================"
echo "테스트 결과 요약"
echo "========================================"
echo "테스트 완료 시간: $(date)"
echo ""
echo "단위 테스트:"
if [ $UNIT_TEST_RESULT -eq 0 ]; then
    echo "  [PASS]"
else
    echo "  [FAIL]"
fi
echo ""
echo "통합 테스트:"
if [ $INTEGRATION_TEST_RESULT -eq 0 ]; then
    echo "  [PASS]"
else
    echo "  [FAIL]"
fi
echo ""
echo "E2E 테스트:"
if [ $E2E_TEST_RESULT -eq 0 ]; then
    echo "  [PASS]"
else
    echo "  [SKIP/FAIL]"
fi
echo ""
echo "========================================"

# 전체 결과
if [ $UNIT_TEST_RESULT -eq 0 ] && [ $INTEGRATION_TEST_RESULT -eq 0 ]; then
    echo "전체 테스트: [PASS]"
    exit 0
else
    echo "전체 테스트: [FAIL]"
    exit 1
fi

