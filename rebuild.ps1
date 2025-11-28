# Script de nettoyage et rebuild complet pour Flutter (PowerShell)

Write-Host "🧹 Nettoyage complet du cache Gradle..." -ForegroundColor Yellow
Remove-Item "$env:USERPROFILE\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "✅ Cache Gradle supprimé" -ForegroundColor Green

Write-Host ""
Write-Host "🧹 Nettoyage Flutter..." -ForegroundColor Yellow
cd "c:\Users\bmd-tech\Desktop\Boutique\mobile"
& flutter clean
Write-Host "✅ Flutter nettoyé" -ForegroundColor Green

Write-Host ""
Write-Host "📦 Réinstallation des dépendances..." -ForegroundColor Yellow
& flutter pub get
Write-Host "✅ Dépendances réinstallées" -ForegroundColor Green

Write-Host ""
Write-Host "🔨 Building appbundle release..." -ForegroundColor Yellow
& flutter build appbundle --release

Write-Host ""
if (Test-Path "build/app/outputs/bundle/release/app-release.aab") {
    Write-Host "✅ ✅ ✅ BUILD SUCCESS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📍 Fichier généré:" -ForegroundColor Cyan
    Get-Item "build/app/outputs/bundle/release/app-release.aab" | Format-List Name, @{Label="Size(MB)";Expression={[math]::Round($_.Length/1MB, 2)}}
} else {
    Write-Host "❌ Build échoué - AAB non trouvé" -ForegroundColor Red
    exit 1
}
