#!/bin/bash
# Script de vérification rapide de l'APK - Fonctionne sous Windows (Git Bash, WSL, etc.)

echo "=========================================="
echo "✅ Vérification Setup APK Distribution"
echo "=========================================="
echo ""

# Fonction pour afficher le résultat
check_file() {
    if [ -f "$1" ]; then
        size=$(du -h "$1" | cut -f1)
        echo "✅ $1 ($size)"
        return 0
    else
        echo "❌ $1 (MANQUANT)"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo "✅ $1 (dossier)"
        return 0
    else
        echo "❌ $1 (MANQUANT)"
        return 1
    fi
}

echo "📁 Vérification des fichiers..."
echo ""

# Fichiers principaux
check_file "public/downloads/boutique-mobile.apk"
check_file "public/download.html"

echo ""
echo "📖 Documentation:"
check_file "START_APK_DISTRIBUTION.md"
check_file "APK_DISTRIBUTION.md"
check_file "APK_DOWNLOAD_GUIDE.md"
check_file "APK_SHARING_GUIDE.md"

echo ""
echo "🛠️  Scripts:"
check_file "build-and-deploy-apk.ps1"
check_file "deploy-apk.bat"
check_file "test-apk-locally.bat"

echo ""
echo "⚙️  Configuration:"
check_file "apk-distribution-config.json"
check_file "vercel.json"

echo ""
echo "=========================================="
echo "✅ Vérification terminée!"
echo "=========================================="
echo ""
echo "📝 Prochaines étapes:"
echo "1. cd /d c:\\Users\\bmd-tech\\Desktop\\Boutique"
echo "2. vercel login"
echo "3. vercel --prod"
echo ""
echo "Puis partagez le lien: https://YOUR_DOMAIN.vercel.app/download.html"
