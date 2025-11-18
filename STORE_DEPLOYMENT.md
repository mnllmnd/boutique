# 📱 Guide de Déploiement App Store & Google Play Store

## ✅ Checklist Pré-Publication

### 1️⃣ Configuration de Base (pubspec.yaml)

**À faire:**
```yaml
name: boutique
version: 1.0.0+1
description: Application de gestion de dettes pour les petits commerces. Suivez vos clients, enregistrez les paiements et gérez votre trésorerie facilement.
```

**Version Format:** `major.minor.patch+buildNumber`
- `1.0.0` = version pour utilisateurs
- `+1` = build number interne

### 2️⃣ Configuration Android

#### A. Package Name & Version (android/app/build.gradle.kts)

**À changer:**
```gradle
applicationId = "com.mnllmnd.boutique"  // IMPORTANT: Unique et descriptif
versionCode = 1
versionName = "1.0.0"

minSdk = 21  // Android 5.0 minimum recommandé
targetSdk = 33  // Android 13+
```

#### B. Permissions (android/app/src/main/AndroidManifest.xml)

**Ajouter:**
```xml
<!-- Internet pour API calls -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Stockage (si photos de clients) -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- Localisation réseau -->
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Connectivité -->
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
```

#### C. Créer un Keystore Signé

**Commande (une seule fois):**
```bash
keytool -genkey -v -keystore ~/boutique-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias boutique_key
```

**Puis configurer le signing (android/app/build.gradle.kts):**
```gradle
signingConfigs {
    release {
        storeFile = file(System.getenv("KEYSTORE_PATH") ?: "~/boutique-key.jks")
        storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
        keyAlias = "boutique_key"
        keyPassword = System.getenv("KEY_PASSWORD") ?: ""
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.release
    }
}
```

### 3️⃣ Configuration iOS

#### A. Bundle ID & Version (ios/Runner/Info.plist)

```xml
<key>CFBundleIdentifier</key>
<string>com.mnllmnd.boutique</string>

<key>CFBundleVersion</key>
<string>1</string>

<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
```

#### B. Permissions (ios/Runner/Info.plist)

```xml
<!-- Pour accès réseau -->
<key>NSLocalNetworkUsageDescription</key>
<string>Boutique utilise la connexion réseau pour synchroniser vos données</string>

<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <string>_https._tcp</string>
</array>

<!-- Autre Permission -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Utilisé pour les photos de profil des clients</string>
```

#### C. Créer un Certificat Apple

1. Aller sur [Apple Developer Account](https://developer.apple.com/)
2. Certificates, Identifiers & Profiles → Certificates
3. Créer un "iOS App Development" ou "iOS Distribution" certificate
4. Télécharger et installer le certificat

### 4️⃣ Icônes et Assets

#### A. Icône App (192x192 minimum)

**Android:** `android/app/src/main/res/mipmap-*/ic_launcher.png`
- mdpi: 48x48
- hdpi: 72x72
- xhdpi: 96x96
- xxhdpi: 144x144
- xxxhdpi: 192x192

**iOS:** `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Générer via [AppIcon.co](https://www.appicon.co/)
- Formats: 29x29, 40x40, 60x60, 76x76, 83.5x83.5, 120x120, 152x152, 167x167, 180x180

#### B. Splash Screen

**Placer dans:** `flutter/assets/` ou générer avec [flutter_native_splash](https://pub.dev/packages/flutter_native_splash)

### 5️⃣ Configuration API & Environnements

**Important:** Utiliser des URLs de production différentes

**main.dart:**
```dart
String get apiHost {
  const environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'production');
  
  if (environment == 'development') {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }
  
  // Production - remplacer par votre serveur réel
  return 'https://api.boutique.example.com/api';
}
```

**Compiler avec:** `flutter build apk --dart-define=ENVIRONMENT=production`

### 6️⃣ Tests Pré-Déploiement

```bash
# Build Android Release
flutter build apk --release

# Build iOS Release
flutter build ios --release

# Test sur device réel
flutter run --release

# Build Web (si applicable)
flutter build web --release
```

### 7️⃣ Documents Requis

#### Privacy Policy
```
https://your-domain.com/privacy-policy

Doit couvrir:
- Données collectées (numéros de téléphone, noms)
- Utilisation des données
- Données stockées localement vs synchronisées
- Politique de rétention
```

#### Terms of Service
```
https://your-domain.com/terms

Doit inclure:
- Conditions d'utilisation
- Limitations de responsabilité
- Droits des utilisateurs
```

#### Support Email
```
support@boutique.example.com
```

### 8️⃣ Google Play Store

**Fichiers à préparer:**

1. **APK ou App Bundle** - `flutter build appbundle --release`
2. **Screenshots** (5-8)
   - 1080×1920px (9:16 ratio)
3. **Feature Graphic** - 1024×500px
4. **Icon** - 512×512px
5. **Descriptions:**
   - Short description (80 caractères max)
   - Full description (4000 caractères max)
6. **Content Rating** - Remplir le questionnaire
7. **Privacy Policy URL**

**Processus:**
1. Créer Google Play Developer Account ($25 one-time)
2. Google Play Console → Créer app
3. Compléter les informations
4. Uploader APK/Bundle
5. Soumettre pour review (24-48h)

### 9️⃣ App Store (iOS)

**Fichiers à préparer:**

1. **Build via Xcode** - `flutter build ios`
2. **Screenshots** (2-5 par device)
   - iPhone: 1080×1920px
   - iPad: 2048×2732px
3. **Preview Video** (optional) - 30sec max
4. **Icon** - 1024×1024px
5. **Descriptions** (même que Play Store)
6. **Privacy Policy URL**

**Processus:**
1. Créer Apple Developer Account ($99/an)
2. App Store Connect → My Apps
3. Créer nouvelle app
4. Compléter les informations
5. Upload build via Xcode/TestFlight
6. Soumettre pour review (1-3 jours)

### 🔟 Checklist Final

- [ ] Version augmentée dans pubspec.yaml
- [ ] Package/Bundle ID unique configuré
- [ ] Icônes en haute résolution
- [ ] Permissions minimales déclarées
- [ ] URL API pointant vers production
- [ ] Privacy Policy et Terms disponibles
- [ ] Build release testé sur device réel
- [ ] Pas d'erreurs de compilation
- [ ] Descriptions et screenshots préparés
- [ ] Support email configuré
- [ ] Accounts développeurs créés (Google/Apple)
- [ ] Keystore Android sécurisé
- [ ] Certificat Apple installé

---

## 📋 Commandes Pratiques

```bash
# Vérifier build sans compiler
flutter doctor

# Analyser le code
flutter analyze

# Formater le code
flutter format lib/

# Tester la build
flutter test

# Build Release Android
flutter build apk --release

# Build AppBundle (préféré pour Play Store)
flutter build appbundle --release

# Build iOS
flutter build ios --release

# Nettoyer avant build
flutter clean

# Montrer les fichiers de sortie
flutter build appbundle --release && echo "Sortie: build/app/outputs/bundle/release/app-release.aab"
```

---

## 🚨 Pièges Courants

1. **Package name invalide** - Doit être `com.monentreprise.app`
2. **Version code non-incrémentée** - Google refuse les re-uploads avec même versionCode
3. **Pas de Privacy Policy** - Rejet automatique
4. **Permissions non justifiées** - Rejet pour over-permissioning
5. **API URLs hardcodées** - Remplac par des env vars
6. **Pas de test sur device réel** - Peut causer crashes après publication
7. **Screenshots non actualisés** - Peut être rejeté
8. **Support email invalide** - Impossible de contacter pour problèmes

---

## 📞 Support

Pour questions sur l'hébergement:
- Google Play: [support.google.com/googleplay](https://support.google.com/googleplay)
- App Store: [developer.apple.com/support](https://developer.apple.com/support)
