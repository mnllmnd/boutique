#!/bin/bash

# ================================
# Script de Build pour Publication
# ================================

set -e  # Exit on error

echo "🚀 Préparation Boutique pour publication..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables
VERSION=${1:-"1.0.0"}
BUILD_NUMBER=${2:-"1"}
OUTPUT_DIR="build/release"

echo -e "${YELLOW}Étape 1: Vérification de l'environnement${NC}"
flutter doctor

echo -e "${YELLOW}Étape 2: Nettoyage${NC}"
flutter clean

echo -e "${YELLOW}Étape 3: Récupération des dépendances${NC}"
flutter pub get

echo -e "${YELLOW}Étape 4: Linting${NC}"
flutter analyze

echo -e "${YELLOW}Étape 5: Formatage du code${NC}"
flutter format lib/

echo -e "${YELLOW}Étape 6: Build Android (APK)${NC}"
flutter build apk --release \
  --dart-define=ENVIRONMENT=production \
  -v

echo -e "${YELLOW}Étape 7: Build Android (AppBundle pour Play Store)${NC}"
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  -v

echo -e "${YELLOW}Étape 8: Build iOS${NC}"
flutter build ios --release \
  --dart-define=ENVIRONMENT=production \
  -v

echo -e "${GREEN}✅ Build terminé avec succès!${NC}"
echo ""
echo -e "${GREEN}Fichiers générés:${NC}"
echo "  📱 APK: build/app/outputs/flutter-apk/app-release.apk"
echo "  📦 AppBundle: build/app/outputs/bundle/release/app-release.aab"
echo "  🍎 iOS: build/ios/iphoneos/Runner.app"
echo ""
echo -e "${YELLOW}Prochaines étapes:${NC}"
echo "  1. Google Play: Uploader build/app/outputs/bundle/release/app-release.aab"
echo "  2. App Store: Uploader via Xcode ou Transporter"
echo "  3. Vérifier les descriptions et screenshots"
echo "  4. Soumettre pour review"
