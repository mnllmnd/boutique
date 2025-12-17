# 📱 Guide de Téléchargement APK - Boutique Mobile

## Accès au téléchargement

### 🔗 Lien de téléchargement principal
```
https://your-domain.vercel.app/download.html
```

### 📥 Lien direct APK
```
https://your-domain.vercel.app/downloads/boutique-mobile.apk
```

> Remplacez `your-domain` par votre domaine Vercel réel

---

## 📋 Configuration système requise

- **Système**: Android 5.0 ou supérieur
- **Espace disque**: ~60 MB minimum
- **RAM**: 2 GB recommandé
- **Connexion**: Internet pour synchronisation des données

---

## 📥 Installation sur Android

### Méthode 1: Via Page Web (Recommandée)

1. **Sur votre téléphone Android**, ouvrez un navigateur
2. Accédez à: `https://your-domain.vercel.app/download.html`
3. Cliquez sur le bouton **"Télécharger l'APK"**
4. Une fenêtre de confirmation apparaîtra
5. Cliquez sur **"Télécharger"**

### Méthode 2: Lien Direct

1. Accédez directement à: `https://your-domain.vercel.app/downloads/boutique-mobile.apk`
2. Le téléchargement commence automatiquement

### Méthode 3: Code QR

Vous pouvez générer un code QR pointant vers:
```
https://your-domain.vercel.app/download.html
```

Utilisez un générateur de code QR en ligne et partagez-le avec vos utilisateurs.

---

## 🚀 Installation de l'APK

### Après le téléchargement:

1. **Allez dans** Paramètres → Sécurité
2. **Activez** "Sources inconnues" ou "Installer depuis des sources inconnues"
3. **Ouvrez** le gestionnaire de fichiers
4. **Naviguez vers** Téléchargements
5. **Appuyez sur** `boutique-mobile.apk`
6. **Cliquez sur** Installer
7. **Attendez** la fin de l'installation
8. **Lancez** l'application depuis votre écran d'accueil

---

## ⚙️ Configuration initiale

L'application se configure automatiquement au premier lancement:

1. ✅ API Backend détectée automatiquement
2. ✅ Base de données locale initialisée
3. ✅ Cache des données configuré
4. ✅ Prêt à l'emploi

**Pas d'étapes de configuration supplémentaires requises!**

---

## 🔧 Dépannage

### L'installation est bloquée
- ✅ Vérifiez que "Sources inconnues" est activé
- ✅ Essayez de télécharger à nouveau
- ✅ Libérez de l'espace disque (~60 MB)

### L'application ne démarre pas
- ✅ Vérifiez votre connexion Internet
- ✅ Essayez de redémarrer votre téléphone
- ✅ Désinstallez et réinstallez l'APK

### Erreur de connexion à l'API
- ✅ Vérifiez votre connexion Internet
- ✅ L'API backend doit être en ligne
- ✅ Vérifiez l'URL de l'API dans les logs

---

## 🔄 Mise à jour de l'APK

Quand une nouvelle version est disponible:

1. **Reconstruisez** l'APK:
   ```powershell
   cd mobile
   flutter build apk --release
   ```

2. **Copiez** le nouvel APK:
   ```powershell
   Copy-Item "mobile/build/app/outputs/flutter-apk/app-release.apk" `
              "public/downloads/boutique-mobile.apk" -Force
   ```

3. **Déployez** sur Vercel:
   ```bash
   vercel --prod
   ```

4. **Les utilisateurs** téléchargeront automatiquement la nouvelle version

---

## 📊 Informations de l'APK

| Propriété | Valeur |
|-----------|--------|
| **Nom de l'application** | Boutique Mobile |
| **Package ID** | com.boutique.mobile |
| **Taille** | 58.6 MB |
| **Version** | 1.0.0 |
| **Type** | Release (Signée) |
| **Min SDK** | 21 (Android 5.0) |
| **Target SDK** | 34 (Android 14) |

---

## 🔐 Sécurité

✅ **APK Signé**: Certificat de signature: `boutique-release.jks`  
✅ **Stockage Sécurisé**: Données chiffrées localement  
✅ **Connexion SSL/TLS**: Communication chiffrée avec l'API  
✅ **Pas de données sensibles**: Aucune clé stockée dans l'APK  

---

## 📞 Support

Pour des problèmes ou des questions:
- 📧 Contactez le support technique
- 🐛 Signalez les bugs via le système de feedback
- 💬 Rejoignez notre communauté d'utilisateurs

---

## 📝 Notes importantes

- ⚠️ **Ne partagez pas votre keystore** (`boutique-release.jks`)
- ⚠️ **Protégez vos mots de passe** dans `key.properties`
- ℹ️ **L'application fonctionne hors ligne** partiellement
- ℹ️ **Synchronisation automatique** quand Internet est disponible

---

**Version du guide**: 1.0.0  
**Dernière mise à jour**: 17 décembre 2025
