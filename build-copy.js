#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function copyDirSync(src, dest) {
  // Créer le répertoire de destination
  if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
  }

  // Lire et copier tous les fichiers/dossiers
  const files = fs.readdirSync(src);
  files.forEach(file => {
    const srcPath = path.join(src, file);
    const destPath = path.join(dest, file);
    
    const stat = fs.statSync(srcPath);
    if (stat.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  });
}

try {
  const srcDir = path.join(__dirname, 'public_build');
  const destDir = path.join(__dirname, 'build', 'web');

  console.log(`📋 Copie de ${srcDir} vers ${destDir}...`);

  if (!fs.existsSync(srcDir)) {
    console.error(`❌ Le répertoire source n'existe pas: ${srcDir}`);
    process.exit(1);
  }

  copyDirSync(srcDir, destDir);

  console.log(`✅ Copie complétée avec succès!`);
  console.log(`📁 build/web contient maintenant ${fs.readdirSync(destDir).length} éléments`);
} catch (err) {
  console.error('❌ Erreur lors de la copie:', err.message);
  process.exit(1);
}
