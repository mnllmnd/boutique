# Build script optimisé pour Flutter Web (PowerShell)
# Élimine les écrans blancs avec configuration d'optimisation

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🎯 Compilation Flutter Web Optimisée" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier que Flutter est installé
try {
    flutter --version | Out-Null
} catch {
    Write-Host "❌ Flutter n'est pas installé ou non accessible" -ForegroundColor Red
    exit 1
}

# Se placer dans le répertoire mobile
$mobilePath = Join-Path $PSScriptRoot "mobile"
if (!(Test-Path $mobilePath)) {
    Write-Host "❌ Répertoire 'mobile' non trouvé" -ForegroundColor Red
    exit 1
}

Set-Location $mobilePath
Write-Host "✅ Répertoire actuel: $(Get-Location)" -ForegroundColor Green
Write-Host ""

# Nettoyer les builds précédents
Write-Host "📦 Nettoyage des builds précédents..." -ForegroundColor Yellow
flutter clean | Out-Null
flutter pub get | Out-Null

Write-Host ""
Write-Host "🔨 Compilation avec renderer HTML..." -ForegroundColor Yellow
Write-Host ""

# Build pour production avec renderer HTML
flutter build web --release --web-renderer html

Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Compilation réussie!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📁 Output: build/web/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🚀 Pour déployer:" -ForegroundColor Green
    Write-Host "   - Copier le contenu de build/web/ vers votre serveur" -ForegroundColor Gray
    Write-Host "   - Vérifier que web/index.html est servi correctement" -ForegroundColor Gray
    Write-Host ""
    Write-Host "📝 Configuration appliquée:" -ForegroundColor Green
    Write-Host "   ✓ HTML Renderer (plus stable que CanvasKit)" -ForegroundColor Gray
    Write-Host "   ✓ Timeouts augmentés à 12 secondes" -ForegroundColor Gray
    Write-Host "   ✓ Cache local automatique" -ForegroundColor Gray
    Write-Host "   ✓ ErrorBoundary pour les crashs" -ForegroundColor Gray
    Write-Host "   ✓ Indicateurs de chargement visibles" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🎉 Prêt pour la production!" -ForegroundColor Green
} else {
    Write-Host "❌ Erreur lors de la compilation" -ForegroundColor Red
    exit 1
}

Read-Host "Appuyez sur Entrée pour fermer"
