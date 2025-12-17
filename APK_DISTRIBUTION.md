# 📱 Distribution APK Boutique Mobile

## 🎯 Vue d'ensemble

Votre application Boutique Mobile est maintenant prête pour la distribution Android directe (sans Play Store). Les utilisateurs peuvent télécharger et installer l'APK directement depuis votre site web.

---

## 📂 Structure des fichiers

```
public/
├── downloads/
│   └── boutique-mobile.apk          ← L'APK téléchargeable
└── download.html                     ← Page de téléchargement
```

---

## 🚀 Déploiement rapide

### Option 1: Script PowerShell (Recommandé)

```powershell
# Tout en un: build, copie, et déploie sur Vercel
.\build-and-deploy-apk.ps1
```

### Option 2: Commandes manuelles

```powershell
# 1. Construire l'APK
cd mobile
flutter build apk --release
cd ..

# 2. Copier l'APK
Copy-Item "mobile/build/app/outputs/flutter-apk/app-release.apk" `
          "public/downloads/boutique-mobile.apk" -Force

# 3. Déployer sur Vercel
vercel --prod
```

### Option 3: Batch (Windows uniquement)

```batch
deploy-apk.bat
```

---

## 📊 Infos sur l'APK actuelle

| Propriété | Détail |
|-----------|--------|
| **Chemin** | `public/downloads/boutique-mobile.apk` |
| **Taille** | 58.6 MB |
| **Version** | 1.0.0 |
| **Package ID** | com.boutique.mobile |
| **Min Android** | 5.0 (API 21) |
| **Target Android** | 14 (API 34) |
| **État** | ✅ Signé et prêt |

---

## 🌐 Accès utilisateur

### 📥 Pour les utilisateurs

1. **Via page web**:
   ```
   https://your-domain.vercel.app/download.html
   ```

2. **Lien direct**:
   ```
   https://your-domain.vercel.app/downloads/boutique-mobile.apk
   ```

3. **Code QR** (générez un pour `https://your-domain.vercel.app/download.html`)

### Vous pouvez partager:
- ✅ Lien web
- ✅ Lien direct
- ✅ Code QR
- ✅ Fichier APK par email (attention: peut être bloqué)

---

## 🔄 Mise à jour de l'APK

### Quand vous apportez des modifications:

1. **Rebuild** (simple):
   ```powershell
   .\build-and-deploy-apk.ps1
   ```

2. **Ou manuellement**:
   ```powershell
   cd mobile
   flutter clean
   flutter pub get
   flutter build apk --release
   cd ..
   Copy-Item "mobile/build/app/outputs/flutter-apk/app-release.apk" `
             "public/downloads/boutique-mobile.apk" -Force
   vercel --prod
   ```

### Version et historique

- Modifiez `versionCode` et `versionName` dans `mobile/android/app/build.gradle.kts`
- Les anciennes versions restent en local dans `mobile/build/app/outputs/flutter-apk/`

---

## 🔐 Certificat de signature

Votre APK est signé avec:

```
Fichier: mobile/boutique-release.jks
Alias: boutique_key
Mots de passe: Stockés dans android/key.properties
```

⚠️ **IMPORTANT**: Ne partagez jamais `boutique-release.jks` ou `key.properties`!

---

## 📱 Compatibilité

### ✅ Appareils supportés
- Android 5.0 et supérieur
- Smartphones et tablettes
- Tous les constructeurs (Samsung, Xiaomi, Google, Huawei, etc.)

### ⚠️ Limitations
- Pas de support iOS
- Espace disque: ~60 MB minimum
- RAM: 2 GB recommandé

---

## 🔧 Troubleshooting

### L'APK ne se télécharge pas
```powershell
# Vérifier que l'APK existe
Test-Path "public/downloads/boutique-mobile.apk"

# Vérifier sa taille
(Get-Item "public/downloads/boutique-mobile.apk").Length / 1MB
```

### Vercel ne trouve pas l'APK
```powershell
# S'assurer que vercel.json est correct
Get-Content vercel.json | ConvertFrom-Json

# Redéployer
vercel --prod --force
```

### Rebuild échoue
```powershell
# Nettoyer et reconstruire
cd mobile
flutter clean
flutter pub get
flutter build apk --release --verbose
```

---

## 📊 Statistiques de déploiement

Chaque déploiement crée:

```
mobile/build/app/outputs/flutter-apk/
├── app-release.apk                    ← L'APK final
└── app-release.apk.sha1              ← Hash de sécurité
```

Vérification d'intégrité:
```powershell
# Afficher le hash SHA1
certUtil -hashfile "public/downloads/boutique-mobile.apk" SHA1
```

---

## 🎓 Guide utilisateur complet

Voir: [APK_DOWNLOAD_GUIDE.md](APK_DOWNLOAD_GUIDE.md)

---

## ✅ Checklist de déploiement

Avant de déployer une nouvelle version:

- [ ] Code testé et fonctionnel
- [ ] Version mise à jour dans `pubspec.yaml`
- [ ] `versionCode` et `versionName` incrémentés
- [ ] Build local réussi (`flutter build apk --release`)
- [ ] APK peut être exécuté sur un appareil/émulateur de test
- [ ] APK copié dans `public/downloads/`
- [ ] `vercel.json` n'a pas de conflits
- [ ] Prêt pour `vercel --prod`

---

## 📞 Support et questions

Besoin d'aide?
- 📖 Consultez [APK_DOWNLOAD_GUIDE.md](APK_DOWNLOAD_GUIDE.md)
- 🔍 Vérifiez les logs Vercel
- 💬 Contactez le support

---

**Dernière mise à jour**: 17 décembre 2025  
**Version APK**: 1.0.0  
**État**: ✅ Production Ready
