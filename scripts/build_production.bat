@echo off
REM 프로덕션 빌드 스크립트 (Windows)
REM 웹, Android, iOS 프로덕션 빌드 자동화

setlocal enabledelayedexpansion

echo ========================================
echo 프로덕션 빌드 스크립트
echo ========================================
echo.

REM 결과 디렉토리 생성
if not exist "build_results" mkdir build_results
set RESULT_DIR=build_results
set TIMESTAMP=%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set RESULT_FILE=%RESULT_DIR%\build_results_%TIMESTAMP%.txt

echo 빌드 시작 시간: %date% %time%
echo 결과 파일: %RESULT_FILE%
echo.

REM Flutter 환경 확인
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [오류] Flutter가 설치되어 있지 않거나 PATH에 없습니다.
    exit /b 1
)

REM 의존성 설치
echo [1/6] Flutter 의존성 확인...
flutter pub get
if %errorlevel% neq 0 (
    echo [오류] 의존성 설치 실패
    exit /b 1
)
echo.

REM 웹 빌드
echo [2/6] 웹 프로덕션 빌드...
echo ⚠️  API 키 환경 변수가 설정되어 있는지 확인하세요
echo 최적화: HTML 렌더러 사용 (빠른 초기 로딩)
echo.
flutter build web --release --base-href "/TESTHOME/" ^
    --web-renderer html ^
    --dart-define=JUSO_API_KEY=%JUSO_API_KEY% ^
    --dart-define=VWORLD_API_KEY=%VWORLD_API_KEY% ^
    --dart-define=VWORLD_GEOCODER_API_KEY=%VWORLD_GEOCODER_API_KEY% ^
    --dart-define=DATA_GO_KR_SERVICE_KEY=%DATA_GO_KR_SERVICE_KEY% ^
    --dart-define=NAVER_MAP_CLIENT_ID=%NAVER_MAP_CLIENT_ID% ^
    --dart-define=CODEF_CLIENT_ID=%CODEF_CLIENT_ID% ^
    --dart-define=CODEF_CLIENT_SECRET=%CODEF_CLIENT_SECRET% ^
    --dart-define=CODEF_PUBLIC_KEY=%CODEF_PUBLIC_KEY% ^
    --dart-define=REGISTER_API_KEY=%REGISTER_API_KEY% ^
    --dart-define=SEOUL_OPEN_API_KEY=%SEOUL_OPEN_API_KEY%

if %errorlevel% equ 0 (
    echo [성공] 웹 빌드 완료: build\web
    set WEB_BUILD_RESULT=0
) else (
    echo [실패] 웹 빌드 실패
    set WEB_BUILD_RESULT=1
)
echo.

REM Android APK 빌드
echo [3/6] Android APK 프로덕션 빌드...
echo ⚠️  Keystore 설정이 필요할 수 있습니다
echo.
if exist "android\key.properties" (
    flutter build apk --release
    if %errorlevel% equ 0 (
        echo [성공] Android APK 빌드 완료: build\app\outputs\flutter-apk\app-release.apk
        set ANDROID_BUILD_RESULT=0
    ) else (
        echo [실패] Android APK 빌드 실패
        set ANDROID_BUILD_RESULT=1
    )
) else (
    echo [경고] android\key.properties 파일이 없습니다. Keystore 설정이 필요합니다.
    echo [스킵] Android APK 빌드를 건너뜁니다.
    set ANDROID_BUILD_RESULT=2
)
echo.

REM Android AAB 빌드
echo [4/6] Android AAB (App Bundle) 프로덕션 빌드...
if exist "android\key.properties" (
    flutter build appbundle --release
    if %errorlevel% equ 0 (
        echo [성공] Android AAB 빌드 완료: build\app\outputs\bundle\release\app-release.aab
        set ANDROID_AAB_RESULT=0
    ) else (
        echo [실패] Android AAB 빌드 실패
        set ANDROID_AAB_RESULT=1
    )
) else (
    echo [스킵] Android AAB 빌드를 건너뜁니다 (Keystore 설정 필요)
    set ANDROID_AAB_RESULT=2
)
echo.

REM iOS 빌드 (Mac에서만 가능)
echo [5/6] iOS 프로덕션 빌드...
REM Windows에서는 iOS 빌드 불가능
echo [스킵] iOS 빌드는 Mac 환경에서만 가능합니다.
set IOS_BUILD_RESULT=2
echo.

REM 빌드 결과 요약
echo [6/6] 빌드 결과 요약...
echo ========================================
echo 빌드 완료 시간: %date% %time%
echo.
echo 웹 빌드:
if %WEB_BUILD_RESULT% equ 0 (echo   [성공]) else (echo   [실패])
echo.
echo Android APK 빌드:
if %ANDROID_BUILD_RESULT% equ 0 (echo   [성공]) else if %ANDROID_BUILD_RESULT% equ 2 (echo   [스킵]) else (echo   [실패])
echo.
echo Android AAB 빌드:
if %ANDROID_AAB_RESULT% equ 0 (echo   [성공]) else if %ANDROID_AAB_RESULT% equ 2 (echo   [스킵]) else (echo   [실패])
echo.
echo iOS 빌드:
if %IOS_BUILD_RESULT% equ 0 (echo   [성공]) else if %IOS_BUILD_RESULT% equ 2 (echo   [스킵]) else (echo   [실패])
echo.
echo ========================================

REM 결과를 파일에 저장
(
    echo 빌드 결과 요약
    echo 빌드 시간: %date% %time%
    echo.
    echo 웹 빌드: 
    if %WEB_BUILD_RESULT% equ 0 (echo 성공) else (echo 실패)
    echo.
    echo Android APK 빌드:
    if %ANDROID_BUILD_RESULT% equ 0 (echo 성공) else if %ANDROID_BUILD_RESULT% equ 2 (echo 스킵) else (echo 실패)
    echo.
    echo Android AAB 빌드:
    if %ANDROID_AAB_RESULT% equ 0 (echo 성공) else if %ANDROID_AAB_RESULT% equ 2 (echo 스킵) else (echo 실패)
    echo.
    echo iOS 빌드:
    if %IOS_BUILD_RESULT% equ 0 (echo 성공) else (echo 스킵 - Mac 환경 필요)
) > %RESULT_FILE%

echo 결과가 저장되었습니다: %RESULT_FILE%
echo.

REM 전체 결과
if %WEB_BUILD_RESULT% equ 0 (
    echo 전체 빌드: [부분 성공]
    exit /b 0
) else (
    echo 전체 빌드: [실패]
    exit /b 1
)

