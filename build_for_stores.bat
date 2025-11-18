@echo off
REM ================================
REM Script de Build pour Publication (Windows)
REM ================================

setlocal enabledelayedexpansion

echo.
echo ================================
echo  Build Boutique pour Publication
echo ================================
echo.

set VERSION=%1
if "%VERSION%"=="" set VERSION=1.0.0

set BUILD_NUMBER=%2
if "%BUILD_NUMBER%"=="" set BUILD_NUMBER=1

echo [1/8] Verification de l'environnement...
call flutter doctor
if errorlevel 1 goto error

echo.
echo [2/8] Nettoyage...
call flutter clean
if errorlevel 1 goto error

echo.
echo [3/8] Recuperation des dependances...
call flutter pub get
if errorlevel 1 goto error

echo.
echo [4/8] Linting...
call flutter analyze
if errorlevel 1 goto error

echo.
echo [5/8] Formatage du code...
call flutter format lib/
if errorlevel 1 goto error

echo.
echo [6/8] Build Android (APK)...
call flutter build apk --release ^
  --dart-define=ENVIRONMENT=production
if errorlevel 1 goto error

echo.
echo [7/8] Build Android (AppBundle pour Play Store)...
call flutter build appbundle --release ^
  --dart-define=ENVIRONMENT=production
if errorlevel 1 goto error

echo.
echo [8/8] Build iOS...
call flutter build ios --release ^
  --dart-define=ENVIRONMENT=production
if errorlevel 1 goto error

echo.
echo ================================
echo  SUCCESS! Build termine!
echo ================================
echo.
echo Fichiers generes:
echo   APK: build\app\outputs\flutter-apk\app-release.apk
echo   AppBundle: build\app\outputs\bundle\release\app-release.aab
echo   iOS: build\ios\iphoneos\Runner.app
echo.
echo Prochaines etapes:
echo   1. Google Play: Uploader AppBundle
echo   2. App Store: Uploader via Xcode
echo   3. Verifier descriptions et screenshots
echo   4. Soumettre pour review
echo.
pause
goto end

:error
echo.
echo ================================
echo  ERREUR: Build echouee!
echo ================================
echo.
pause
exit /b 1

:end
