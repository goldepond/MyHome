@echo off
REM 테스트 실행 스크립트 (Windows)
REM 필수 + 중요 테스트 케이스 실행 및 결과 기록

setlocal enabledelayedexpansion

echo ========================================
echo QA 테스트 실행 스크립트
echo ========================================
echo.

REM 결과 디렉토리 생성
if not exist "test_results" mkdir test_results
set RESULT_DIR=test_results
set TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set RESULT_FILE=%RESULT_DIR%\test_results_%TIMESTAMP%.json
set SUMMARY_FILE=%RESULT_DIR%\test_summary_%TIMESTAMP%.txt

echo 테스트 시작 시간: %date% %time%
echo 결과 파일: %RESULT_FILE%
echo.

REM Flutter 환경 확인
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] Flutter가 설치되어 있지 않거나 PATH에 없습니다.
    exit /b 1
)

echo [1/5] Flutter 의존성 확인...
flutter pub get
if %errorlevel% neq 0 (
    echo [오류] 의존성 설치 실패
    exit /b 1
)
echo.

echo [2/5] 단위 테스트 실행...
flutter test test/unit/ --reporter json > %RESULT_DIR%\unit_test_results.json 2>&1
set UNIT_TEST_RESULT=%errorlevel%
if %UNIT_TEST_RESULT% equ 0 (
    echo [성공] 단위 테스트 통과
) else (
    echo [실패] 단위 테스트 실패
)
echo.

echo [3/5] 통합 테스트 실행...
flutter test test/integration/ --reporter json > %RESULT_DIR%\integration_test_results.json 2>&1
set INTEGRATION_TEST_RESULT=%errorlevel%
if %INTEGRATION_TEST_RESULT% equ 0 (
    echo [성공] 통합 테스트 통과
) else (
    echo [실패] 통합 테스트 실패
)
echo.

echo [4/5] E2E 테스트 실행...
REM E2E 테스트는 실제 디바이스나 에뮬레이터가 필요하므로 선택적
flutter test integration_test/ --reporter json > %RESULT_DIR%\e2e_test_results.json 2>&1
set E2E_TEST_RESULT=%errorlevel%
if %E2E_TEST_RESULT% equ 0 (
    echo [성공] E2E 테스트 통과
) else (
    echo [경고] E2E 테스트 실패 또는 스킵됨 (정상일 수 있음)
)
echo.

echo [5/5] 테스트 커버리지 생성...
flutter test --coverage
if exist coverage\lcov.info (
    echo [성공] 커버리지 리포트 생성됨: coverage\lcov.info
) else (
    echo [경고] 커버리지 리포트 생성 실패
)
echo.

REM 결과 요약 생성
echo ========================================
echo 테스트 결과 요약
echo ========================================
echo 테스트 완료 시간: %date% %time%
echo.
echo 단위 테스트: 
if %UNIT_TEST_RESULT% equ 0 (echo   [PASS]) else (echo   [FAIL])
echo.
echo 통합 테스트:
if %INTEGRATION_TEST_RESULT% equ 0 (echo   [PASS]) else (echo   [FAIL])
echo.
echo E2E 테스트:
if %E2E_TEST_RESULT% equ 0 (echo   [PASS]) else (echo   [SKIP/FAIL])
echo.
echo ========================================

REM 전체 결과
if %UNIT_TEST_RESULT% equ 0 if %INTEGRATION_TEST_RESULT% equ 0 (
    echo 전체 테스트: [PASS]
    exit /b 0
) else (
    echo 전체 테스트: [FAIL]
    exit /b 1
)

