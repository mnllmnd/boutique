@echo off
REM Kill all build processes
taskkill /F /IM java.exe 2>nul
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM gradle.exe 2>nul
timeout /t 2 /nobreak

REM Clean build artifacts
cd /d "c:\Users\bmd-tech\Desktop\Boutique\mobile"
echo Cleaning Flutter build...
rmdir /s /q build 2>nul
rmdir /s /q .dart_tool 2>nul
rmdir /s /q android\.gradle 2>nul

REM Reinstall dependencies
echo Getting Flutter dependencies...
call flutter pub get

REM Start fresh build
echo Starting release build...
call flutter build appbundle --release

pause
