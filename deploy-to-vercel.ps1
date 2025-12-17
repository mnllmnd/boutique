# Script de déploiement complet sur Vercel
Write-Host "🚀 Démarrage du déploiement sur Vercel..." -ForegroundColor Green

# 1. Build Flutter Web
Write-Host "`n📦 Étape 1: Build Flutter Web..." -ForegroundColor Cyan
cd mobile
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur Flutter build" -ForegroundColor Red
    exit 1
}

# 2. Copier build/web à la racine
Write-Host "`n📂 Étape 2: Copier web artifacts à la racine..." -ForegroundColor Cyan
cd ..
if (Test-Path build\web) {
    Remove-Item build\web -Recurse -Force
}
Copy-Item mobile\build\web build\web -Recurse -Force
Write-Host "✅ Copie réussie" -ForegroundColor Green

# 3. Vérifier la structure
Write-Host "`n🔍 Étape 3: Vérification..." -ForegroundColor Cyan
if (-not (Test-Path build\web\index.html)) {
    Write-Host "❌ Erreur: build/web/index.html non trouvé" -ForegroundColor Red
    exit 1
}

# 4. Copier APK si nécessaire
Write-Host "`n📱 Étape 4: Vérifier APK..." -ForegroundColor Cyan
if (-not (Test-Path build\web\downloads\boutique-mobile.apk)) {
    if (Test-Path public\downloads\boutique-mobile.apk) {
        New-Item -ItemType Directory -Path build\web\downloads -Force | Out-Null
        Copy-Item public\downloads\boutique-mobile.apk build\web\downloads\boutique-mobile.apk -Force
        Write-Host "✅ APK copié" -ForegroundColor Green
    }
}

# 5. Vérifier vercel.json
Write-Host "`n⚙️  Étape 5: Vérifier vercel.json..." -ForegroundColor Cyan
$vercelContent = Get-Content vercel.json | ConvertFrom-Json
Write-Host "outputDirectory: $($vercelContent.outputDirectory)" -ForegroundColor Yellow

# 6. Git add et commit si nécessaire
Write-Host "`n💾 Étape 6: Git push..." -ForegroundColor Cyan
git add build/web
git add vercel.json
git commit -m "chore: prepare for Vercel deployment" -m "- Build Flutter web: $((Get-Item mobile/build/web).LastWriteTime)`n- Copy to build/web root`n- Verify APK placement"
git push origin main

# 7. Vercel deploy
Write-Host "`n🌐 Étape 7: Déployer sur Vercel..." -ForegroundColor Cyan
vercel --prod --force

Write-Host "`n✅ Déploiement terminé!" -ForegroundColor Green
