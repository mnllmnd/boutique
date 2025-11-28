@echo off
REM Script de nettoyage et rebuild pour Flutter sur Windows

echo.
echo ====================================================
echo   FLUTTER BUILD - NETTOYAGE ET REBUILD COMPLET
echo ====================================================
echo.

echo [1/5] Arrêt des processus Java...
taskkill /F /IM java.exe >nul 2>&1
echo OK

echo.
echo [2/5] Suppression du cache Gradle...
rmdir /S /Q "%USERPROFILE%\.gradle" >nul 2>&1
echo OK

echo.
echo [3/5] Nettoyage Flutter...
cd /d "c:\Users\bmd-tech\Desktop\Boutique\mobile"
call flutter clean
echo OK

echo.
echo [4/5] Installation des dépendances...
call flutter pub get
echo OK

echo.
echo [5/5] BUILD APPBUNDLE RELEASE...
echo.
call flutter build appbundle --release

echo.
if exist "build\app\outputs\bundle\release\app-release.aab" (
    echo.
    echo ====================================================
    echo   SUCCESS! AAB généré avec succès!
    echo ====================================================
    echo.
    for %%F in (build\app\outputs\bundle\release\app-release.aab) do (
        echo   Fichier: %%~nxF
        echo   Taille: %%~zF bytes
    )
    echo.
    echo Prochaines etapes:
    echo   1. flutterfire configure
    echo   2. Uploader sur Google Play Store
    echo.
) else (
    echo.
    echo ====================================================
    echo   ERREUR: Build échoué
    echo ====================================================
    echo.
    echo AAB non trouvé dans: build\app\outputs\bundle\release\
    echo.
)

pause
