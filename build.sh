#!/bin/bash

# Build script for Vercel Flutter Web deployment
set -e

echo "🚀 Building Flutter Web App..."

# Navigate to mobile directory
cd mobile

# Install Flutter SDK if not present
if ! command -v flutter &> /dev/null; then
  echo "📦 Installing Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable
  export PATH="$PATH:$(pwd)/flutter/bin"
fi

# Get dependencies
echo "📚 Getting Flutter dependencies..."
flutter pub get

# Build web
echo "🔨 Building Flutter Web (Release)..."
flutter build web --release

echo "✅ Build completed!"
echo "Output directory: $(pwd)/build/web"
