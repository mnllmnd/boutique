@echo off
REM Test Script for PIN System (Windows)
REM Usage: test_pin_system.bat

setlocal enabledelayedexpansion

set API_URL=http://localhost:3000/api
set PHONE=0612345678
set PIN=1234

echo.
echo ============================================
echo  PIN System Test Suite (Windows)
echo ============================================
echo.

echo [1/3] Checking server connectivity...
powershell -Command "try { Invoke-WebRequest -Uri '%API_URL%/auth/login-pin' -Method POST -Headers @{'Content-Type'='application/json'} -Body '{}' -ErrorAction Stop } catch { if ($_.Exception.Response.StatusCode -eq 400) { exit 0 } else { exit 1 } }"

if %ERRORLEVEL% equ 0 (
  echo [OK] Server is running
) else (
  echo [FAIL] Server not responding
  exit /b 1
)

echo.
echo [2/3] Testing invalid PIN...
powershell -Command "
  $response = Invoke-WebRequest -Uri '%API_URL%/auth/login-pin' `
    -Method POST `
    -Headers @{'Content-Type'='application/json'} `
    -Body '{\"pin\": \"0000\"}' `
    -ErrorAction SilentlyContinue
  if ($response.StatusCode -ne 401) {
    Write-Host '[WARN] Unexpected response'
  } else {
    Write-Host '[OK] Invalid PIN correctly rejected'
  }
"

echo.
echo [3/3] Testing invalid format...
powershell -Command "
  try {
    $response = Invoke-WebRequest -Uri '%API_URL%/auth/login-pin' `
      -Method POST `
      -Headers @{'Content-Type'='application/json'} `
      -Body '{\"pin\": \"abc\"}' `
      -ErrorAction SilentlyContinue
  } catch {
    if ($_.Exception.Response.StatusCode -eq 400) {
      Write-Host '[OK] Invalid format correctly rejected'
    }
  }
"

echo.
echo ============================================
echo  Test Complete
echo ============================================
echo.
echo Next steps:
echo 1. Configure a PIN:
echo    node backend/manage-pins.js set-pin "%PHONE%" "%PIN%"
echo.
echo 2. Test PIN login:
echo    powershell -Command "Invoke-WebRequest -Uri '%API_URL%/auth/login-pin' -Method POST -Headers @{'Content-Type'='application/json'} -Body '{\"pin\": \"%PIN%\"}' | ConvertTo-Json"
echo.
echo 3. List all PINs:
echo    node backend/manage-pins.js list-pins
echo.
