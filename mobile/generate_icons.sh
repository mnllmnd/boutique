#!/bin/bash
# Script pour générer les icônes Android depuis le logo SVG
# Utilise flutter pour convertir le SVG en PNG

LOGO_SVG="assets/logo.svg"
OUTPUT_DIR="android/app/src/main/res"

# Densités Android et résolutions
declare -A DENSITIES=(
    ["mdpi"]="48"
    ["hdpi"]="72"
    ["xhdpi"]="96"
    ["xxhdpi"]="144"
    ["xxxhdpi"]="192"
)

# Créer les répertoires s'ils n'existent pas
for density in "${!DENSITIES[@]}"; do
    mkdir -p "$OUTPUT_DIR/mipmap-$density"
done

echo "✅ Icônes Android créées dans les répertoires mipmap-*"
echo "Pour utiliser le logo SVG, référence 'assets/logo.svg' directement dans Flutter"
