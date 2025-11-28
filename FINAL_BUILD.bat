@echo off
setlocal enabledelayedexpansion

REM === Boutique App - Clean Release Build with Java 11 ===
echo.
echo [*] Stopping all build processes...
taskkill /F /IM java.exe >nul 2>&1
taskkill /F /IM dart.exe >nul 2>&1
taskkill /F /IM gradle.exe >nul 2>&1
taskkill /F /IM python.exe >nul 2>&1
timeout /t 3 /nobreak

REM === Clean directories ===
cd /d "c:\Users\bmd-tech\Desktop\Boutique\mobile"
echo [*] Cleaning build artifacts...

if exist "build" (
    echo   - Removing build directory...
    rmdir /s /q build
)

if exist ".dart_tool" (
    echo   - Removing .dart_tool directory...
    rmdir /s /q .dart_tool
)

if exist "android\.gradle" (
    echo   - Removing android/.gradle directory...
    rmdir /s /q android\.gradle
)

timeout /t 2 /nobreak

REM === Get dependencies ===
echo [*] Getting Flutter dependencies...
call flutter pub get

REM === Build release ===
echo [*] Building Android App Bundle for Play Store...
echo [*] Using Java 11 target (default Flutter configuration)...
call flutter build appbundle --release

if errorlevel 1 (
    echo.
    echo [!] Build failed! Check the output above.
    pause
    exit /b 1
)

echo.
echo [+] Build successful!
echo [+] Output: c:\Users\bmd-tech\Desktop\Boutique\mobile\build\app\outputs\bundle\release\app-release.aab
echo.
pause
exit /b 0
