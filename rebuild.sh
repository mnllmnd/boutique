#!/bin/bash
# Script de nettoyage et rebuild complet pour Flutter

echo "🧹 Nettoyage complet du cache Gradle..."
rm -rf ~/.gradle/caches 2>/dev/null
rm -rf ~/.gradle/wrapper 2>/dev/null
echo "✅ Cache Gradle supprimé"

echo "🧹 Nettoyage Flutter..."
cd "c:\Users\bmd-tech\Desktop\Boutique\mobile"
flutter clean
echo "✅ Flutter nettoyé"

echo "📦 Réinstallation des dépendances..."
flutter pub get
echo "✅ Dépendances réinstallées"

echo "🔨 Building appbundle release..."
flutter build appbundle --release 2>&1

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "✅ ✅ ✅ BUILD SUCCESS!"
    echo ""
    echo "📍 Fichier généré:"
    ls -lh build/app/outputs/bundle/release/app-release.aab
else
    echo "❌ Build échoué - AAB non trouvé"
    exit 1
fi
