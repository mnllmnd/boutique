# Script PowerShell pour construire et déployer l'APK sur Vercel
# Usage: .\build-and-deploy-apk.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Boutique Mobile - Build & Deploy Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$projectRoot = Split-Path -Parent $MyInvocation.MyCommandPath
$mobileDir = Join-Path $projectRoot "mobile"
$apkSource = Join-Path $mobileDir "build\app\outputs\flutter-apk\app-release.apk"
$apkDest = Join-Path $projectRoot "public\downloads\boutique-mobile.apk"

# Fonctions
function Write-Success {
    param([string]$message)
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Error-Msg {
    param([string]$message)
    Write-Host "❌ $message" -ForegroundColor Red
}

function Write-Info {
    param([string]$message)
    Write-Host "ℹ️  $message" -ForegroundColor Blue
}

function Write-Warning-Msg {
    param([string]$message)
    Write-Host "⚠️  $message" -ForegroundColor Yellow
}

# Vérifications préalables
Write-Info "Vérification des outils requis..."

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error-Msg "Flutter n'est pas installé ou n'est pas dans le PATH"
    exit 1
}
Write-Success "Flutter trouvé"

if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    Write-Warning-Msg "Vercel CLI n'est pas installé"
    Write-Info "Installez-le avec: npm install -g vercel"
}
Write-Success "Vercel CLI trouvé"

Write-Host ""

# Construction
Write-Info "Étape 1/3: Construction de l'APK..."
Write-Host ""

Push-Location $mobileDir
flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Error-Msg "La construction a échoué"
    Pop-Location
    exit 1
}
Pop-Location

Write-Success "APK construit avec succès"
Write-Host ""

# Copie
Write-Info "Étape 2/3: Copie de l'APK..."

if (-not (Test-Path $apkSource)) {
    Write-Error-Msg "Fichier APK source non trouvé: $apkSource"
    exit 1
}

$apkSize = (Get-Item $apkSource).Length / 1MB
Write-Info "Taille de l'APK: {0:F1} MB" -f $apkSize

# Créer le répertoire de destination s'il n'existe pas
$destDir = Split-Path -Parent $apkDest
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
}

Copy-Item $apkSource $apkDest -Force
Write-Success "APK copié vers: $apkDest"
Write-Host ""

# Déploiement
Write-Info "Étape 3/3: Déploiement sur Vercel..."
Write-Host ""

# Vérifier si Vercel CLI est disponible
if (Get-Command vercel -ErrorAction SilentlyContinue) {
    Push-Location $projectRoot
    
    Write-Warning-Msg "Assurez-vous d'être connecté à Vercel: vercel login"
    Write-Host ""
    
    $response = Read-Host "Déployer maintenant? (y/n)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        vercel --prod
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Déploiement terminé!"
            Write-Host ""
            Write-Info "Votre APK est maintenant disponible à:"
            Write-Host "  📥 https://your-domain.vercel.app/downloads/boutique-mobile.apk" -ForegroundColor Cyan
            Write-Host "  🌐 https://your-domain.vercel.app/download.html" -ForegroundColor Cyan
        } else {
            Write-Error-Msg "Le déploiement a échoué"
        }
    } else {
        Write-Info "Déploiement annulé"
        Write-Host ""
        Write-Info "Pour déployer plus tard, utilisez:"
        Write-Host "  vercel --prod" -ForegroundColor Cyan
    }
    
    Pop-Location
} else {
    Write-Warning-Msg "Vercel CLI n'est pas disponible"
    Write-Info "Installez-le et déployez manuellement avec: vercel --prod"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Process Completed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
