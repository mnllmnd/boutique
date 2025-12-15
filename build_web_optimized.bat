@echo off
REM Build script optimisé pour Flutter Web
REM Élimine les écrans blancs avec configuration d'optimisation

echo.
echo ========================================
echo 🎯 Compilation Flutter Web Optimisée
echo ========================================
echo.

REM Vérifier que Flutter est installé
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter n'est pas installé ou non accessible
    exit /b 1
)

REM Se placer dans le répertoire mobile
cd /d "%~dp0mobile"

echo ✅ Répertoire actuel: %cd%
echo.

REM Nettoyer les builds précédents
echo 📦 Nettoyage des builds précédents...
flutter clean
flutter pub get

echo.
echo 🔨 Compilation avec renderer HTML...
echo.

REM Build pour production avec renderer HTML
flutter build web --release --web-renderer html

echo.
if %errorlevel% equ 0 (
    echo ✅ Compilation réussie!
    echo.
    echo 📁 Output: build/web/
    echo.
    echo 🚀 Pour déployer:
    echo    - Copier le contenu de build/web/ vers votre serveur
    echo    - Vérifier que web/index.html est servi correctement
    echo.
    echo 📝 Configuration appliquée:
    echo    ✓ HTML Renderer (plus stable que CanvasKit)
    echo    ✓ Timeouts augmentés à 12 secondes
    echo    ✓ Cache local automatique
    echo    ✓ ErrorBoundary pour les crashs
    echo    ✓ Indicateurs de chargement visibles
    echo.
) else (
    echo ❌ Erreur lors de la compilation
    exit /b 1
)

pause
