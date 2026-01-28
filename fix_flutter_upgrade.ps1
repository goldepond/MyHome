# Flutter 업그레이드 문제 해결 스크립트
# 관리자 권한으로 실행하세요

Write-Host "Flutter 업그레이드 문제 해결 중..." -ForegroundColor Yellow

$flutterCachePath = "C:\flutter\bin\cache"
$dartSdkPath = Join-Path $flutterCachePath "dart-sdk"

# 1. 실행 중인 Dart/Flutter 프로세스 종료
Write-Host "`n실행 중인 Dart/Flutter 프로세스 확인 중..." -ForegroundColor Cyan
$dartProcesses = Get-Process -Name "dart","flutter" -ErrorAction SilentlyContinue
if ($dartProcesses) {
    Write-Host "다음 프로세스를 종료합니다: $($dartProcesses.ProcessName -join ', ')" -ForegroundColor Yellow
    $dartProcesses | Stop-Process -Force
    Start-Sleep -Seconds 2
} else {
    Write-Host "실행 중인 Dart/Flutter 프로세스가 없습니다." -ForegroundColor Green
}

# 2. 기존 백업 디렉토리 삭제
Write-Host "`n기존 백업 디렉토리 삭제 중..." -ForegroundColor Cyan
Get-ChildItem -Path $flutterCachePath -Filter "dart-sdk.old*" -Directory -ErrorAction SilentlyContinue | 
    ForEach-Object {
        Write-Host "  삭제 중: $($_.FullName)" -ForegroundColor Yellow
        Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

# 3. dart-sdk 디렉토리 강제 삭제 시도
if (Test-Path $dartSdkPath) {
    Write-Host "`ndart-sdk 디렉토리 삭제 시도 중..." -ForegroundColor Cyan
    
    # 파일 잠금 해제를 위한 재시도 루프
    $maxRetries = 5
    $retryCount = 0
    $deleted = $false
    
    while ($retryCount -lt $maxRetries -and -not $deleted) {
        try {
            # 디렉토리 내 파일들의 읽기 전용 속성 제거
            Get-ChildItem -Path $dartSdkPath -Recurse -Force | 
                ForEach-Object { $_.Attributes = 'Normal' }
            
            Remove-Item -Path $dartSdkPath -Recurse -Force -ErrorAction Stop
            Write-Host "  dart-sdk 디렉토리가 성공적으로 삭제되었습니다." -ForegroundColor Green
            $deleted = $true
        } catch {
            $retryCount++
            if ($retryCount -lt $maxRetries) {
                Write-Host "  재시도 $retryCount/$maxRetries..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
            } else {
                Write-Host "  경고: dart-sdk 디렉토리를 삭제할 수 없습니다. 수동으로 삭제해주세요." -ForegroundColor Red
                Write-Host "  경로: $dartSdkPath" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "`ndart-sdk 디렉토리가 없습니다." -ForegroundColor Green
}

# 4. Flutter 업그레이드 재시도
Write-Host "`nFlutter 업그레이드를 시작합니다..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
flutter upgrade

Write-Host "`n완료되었습니다!" -ForegroundColor Green






