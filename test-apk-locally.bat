@echo off
REM Script pour tester l'APK localement avec un émulateur Android ou appareil physique
REM Utilisation: test-apk-locally.bat

setlocal enabledelayedexpansion

echo ========================================
echo Boutique Mobile - Test APK Locally
echo ========================================
echo.

REM Vérifier si Flutter est installé
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter n'est pas installé ou n'est pas dans le PATH
    pause
    exit /b 1
)

echo ✅ Flutter détecté
echo.

REM Vérifier si l'APK existe
if not exist "public\downloads\boutique-mobile.apk" (
    echo ❌ L'APK n'a pas été trouvée
    echo Constructis d'abord: flutter build apk --release
    pause
    exit /b 1
)

echo ✅ APK trouvée: public/downloads/boutique-mobile.apk
echo.

REM Lister les appareils disponibles
echo Appareils disponibles:
flutter devices

echo.
echo Options:
echo 1. Installer sur l'appareil par défaut
echo 2. Lister les appareils
echo 3. Quitter
echo.

set /p choice="Votre choix (1-3): "

if "%choice%"=="1" (
    echo.
    echo Installation en cours...
    
    REM Utiliser l'APK construit (pas celui dans public)
    set APK="mobile\build\app\outputs\flutter-apk\app-release.apk"
    
    if exist !APK! (
        flutter install !APK!
        
        if %ERRORLEVEL% EQU 0 (
            echo.
            echo ✅ Installation réussie!
            echo.
            echo Pour lancer l'application:
            echo   flutter run
            echo.
            echo Ou via adb:
            echo   adb shell am start -n com.boutique.mobile/.MainActivity
            echo.
        ) else (
            echo ❌ L'installation a échoué
        )
    ) else (
        echo ❌ APK non trouvé: !APK!
        echo Reconstruisez: flutter build apk --release
    )
)

if "%choice%"=="2" (
    echo.
    flutter devices
)

if "%choice%"=="3" (
    echo Annulé
    exit /b 0
)

pause
