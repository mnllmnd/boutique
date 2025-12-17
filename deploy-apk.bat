@echo off
REM Script de déploiement de l'APK sur Vercel
REM Ce script déploie les fichiers web et l'APK sur Vercel

echo ========================================
echo Boutique Mobile - APK Deployment
echo ========================================
echo.

REM Vérifier si Vercel CLI est installé
where vercel >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Vercel CLI n'est pas installé
    echo Installez-le avec: npm install -g vercel
    pause
    exit /b 1
)

cd /d "%~dp0"

echo ✅ Vercel CLI détecté
echo.
echo 📱 Avant le déploiement, assurez-vous que:
echo    - L'APK est dans: public/downloads/boutique-mobile.apk
echo    - Vous êtes connecté à Vercel (vercel login)
echo.

REM Vérifier si l'APK existe
if not exist "public\downloads\boutique-mobile.apk" (
    echo ❌ Erreur: L'APK n'a pas été trouvée
    echo Exécutez d'abord: flutter build apk --release
    echo Puis: Copy-Item "mobile\build\app\outputs\flutter-apk\app-release.apk" "public\downloads\boutique-mobile.apk"
    pause
    exit /b 1
)

echo ✅ APK trouvée: public/downloads/boutique-mobile.apk
echo.

REM Afficher l'URL de téléchargement
for /f "delims=" %%i in ('vercel env pull 2^>nul') do (
    if not "%%i"=="" (
        set "VERCEL_URL=%%i"
    )
)

echo 🚀 Déploiement en cours...
echo.

vercel --prod

echo.
echo ✅ Déploiement terminé!
echo.
echo 📥 Lien de téléchargement:
echo    https://your-domain.vercel.app/download.html
echo.
echo 📥 Lien direct APK:
echo    https://your-domain.vercel.app/downloads/boutique-mobile.apk
echo.
echo ℹ️  Remplacez "your-domain" par votre domaine Vercel réel
echo.
pause
