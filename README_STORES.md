# 📱 Boutique - App Gestion de Dettes
## Guide Complet de Publication App Store & Google Play

---

## 🎯 Objectif

Votre application Boutique est **prête pour la publication**! Ce dossier contient tous les fichiers, guides et checklists nécessaires pour soumettre votre app sur:
- 📱 **Google Play Store** (Android)
- 🍎 **App Store** (iOS)

---

## 📚 Documentation Fournie

### Guides Complets (À Lire en Ordre)

1. **[PUBLISHING_GUIDE.md](PUBLISHING_GUIDE.md)** ⭐ COMMENCER ICI
   - Résumé rapide
   - Prochaines étapes prioritaires
   - Timeline estimée
   - Conseils importants

2. **[STORE_DEPLOYMENT.md](STORE_DEPLOYMENT.md)** - Guide Détaillé
   - Configuration Android/iOS complète
   - Pas à pas pour chaque plateforme
   - Explications techniques
   - Pièges courants et solutions

3. **[SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md)** - Avant Soumission
   - ✅ Checklist technique
   - ✅ Checklist contenu
   - ✅ Checklist légale
   - ✅ Instructions Google Play
   - ✅ Instructions App Store

### Documents Légaux

4. **[PRIVACY_POLICY.md](PRIVACY_POLICY.md)**
   - Template prêt à adapter
   - À publier sur https://votresite.com/privacy-policy
   - Requis pour Google Play & App Store

5. **[TERMS_OF_SERVICE.md](TERMS_OF_SERVICE.md)**
   - Template conditions d'utilisation
   - À publier sur https://votresite.com/terms
   - Recommandé (Google) / Obligatoire (Apple)

6. **[REQUIRED_URLS.md](REQUIRED_URLS.md)**
   - URLs obligatoires à publier
   - Template site simple
   - Où héberger votre site

### Configuration & Scripts

7. **.env.example**
   - Variables d'environnement
   - À dupliquer et remplir: `.env`

8. **build_for_stores.bat** (Windows)
   - Script compilation automatique
   - Exécuter: `build_for_stores.bat 1.0.0 1`

9. **build_for_stores.sh** (macOS/Linux)
   - Même chose pour Unix
   - Exécuter: `chmod +x build_for_stores.sh && ./build_for_stores.sh`

---

## ⚡ Démarrage Rapide (5 Min)

### Étape 1: Lire le Guide (5 min)
Ouvrir **PUBLISHING_GUIDE.md** → Section "Prochaines Étapes Prioritaires"

### Étape 2: Configurer Version (5 min)
```yaml
# mobile/pubspec.yaml
name: boutique
version: 1.0.0+1
description: App gestion dettes pour petits commerces
```

### Étape 3: Configurer Package Names (10 min)
- Android: `android/app/build.gradle.kts` → `com.mnllmnd.boutique`
- iOS: `ios/Runner/Info.plist` → `com.mnllmnd.boutique`

### Étape 4: Créer Comptes (30 min)
- Google Play Console ($25)
- Apple Developer ($99/an)

### Étape 5: Suivre Checklist (1-2 jours)
Utiliser **SUBMISSION_CHECKLIST.md** comme guide

---

## 📋 Structure Documentation

```
Boutique/
├── PUBLISHING_GUIDE.md          ← COMMENCER ICI
├── STORE_DEPLOYMENT.md          ← Guide détaillé technique
├── SUBMISSION_CHECKLIST.md      ← Avant soumission
├── PRIVACY_POLICY.md            ← À publier en ligne
├── TERMS_OF_SERVICE.md          ← À publier en ligne
├── REQUIRED_URLS.md             ← URLs obligatoires
├── .env.example                 ← Configuration
├── build_for_stores.bat         ← Build Windows
├── build_for_stores.sh          ← Build Unix
├── mobile/                      ← Code Flutter
│   ├── pubspec.yaml             ← À mettre à jour
│   ├── android/                 ← À configurer
│   ├── ios/                     ← À configurer
│   └── lib/                     ← Code app
└── README_ORIGINAL.md           ← Docs initiales
```

---

## 🚀 Phases de Publication

### Phase 1: Préparation (Jour 1-2)
- [ ] Lire PUBLISHING_GUIDE.md
- [ ] Mettre à jour versions (pubspec.yaml)
- [ ] Configurer package names (Android/iOS)
- [ ] Créer Keystore Android
- [ ] Installer certificat Apple

### Phase 2: Contenu (Jour 3-4)
- [ ] Publier Privacy Policy
- [ ] Publier Terms of Service
- [ ] Préparer screenshots (5-8 chacun)
- [ ] Préparer icône 512×512
- [ ] Écrire descriptions

### Phase 3: Build & Test (Jour 5-6)
- [ ] Exécuter script build
- [ ] Tester sur device Android
- [ ] Tester sur device iOS
- [ ] Fixer bugs identifiés

### Phase 4: Soumission (Jour 7)
- [ ] Soumettre Google Play
- [ ] Soumettre App Store
- [ ] Attendre approbation (2-48h)

### Phase 5: Publication (Jour 8-9)
- [ ] ✅ App Live sur Google Play!
- [ ] ✅ App Live sur App Store!
- [ ] Annoncer disponibilité
- [ ] Monitorer reviews

---

## 🎯 Informations Clés

### Package Names (IMPORTANT ⚠️)
- **Android:** `com.mnllmnd.boutique`
- **iOS:** `com.mnllmnd.boutique`
- ⚠️ Impossible à changer après publication!

### Versions
- **Actuel:** 1.0.0+1 (version 1.0.0, build 1)
- **Format:** major.minor.patch+buildNumber
- **Incrémenter:** À chaque mise à jour

### Contacts Requis
- **Support Email:** support@boutique.example.com
- **Support Téléphone:** (optionnel)
- **Adresse:** (optionnel mais recommandé)

---

## 🔒 Sécurité Importante

⚠️ **NE PAS:**
- ❌ Committer votre Keystore Android
- ❌ Partager mots de passe Keystore
- ❌ Laisser certificat Apple accessible
- ❌ Publier données sensibles

✅ **À FAIRE:**
- ✅ Garder Keystore en lieu sûr
- ✅ Utiliser des variables d'environnement
- ✅ 2FA sur comptes Google/Apple
- ✅ Sauvegarder certificats localement

---

## 📞 Ressources Officielles

| Ressource | URL |
|-----------|-----|
| Google Play Console | https://play.google.com/console |
| App Store Connect | https://appstoreconnect.apple.com |
| Flutter Deploy Docs | https://flutter.dev/docs/deployment |
| Android Guide | https://developer.android.com/distribute |
| iOS Guide | https://developer.apple.com/app-store |

---

## ❓ Questions Fréquentes

### Q: Combien ça coûte?
**R:** Google Play: $25 (une fois). App Store: $99/an.

### Q: Combien de temps pour approbation?
**R:** Google Play: 2-3h (habituellement). App Store: 1-3 jours.

### Q: Puis-je changer le package name?
**R:** ❌ NON, après publication c'est permanent.

### Q: Mes données clients sont sûres?
**R:** ✅ OUI, stockage local par défaut. Synchronisation optionnelle chiffrée.

### Q: Je peux vendre l'app?
**R:** ✅ OUI, configuration possible dans les stores.

---

## 🆘 Troubleshooting

### Build échoue?
1. Exécuter: `flutter clean`
2. Exécuter: `flutter pub get`
3. Consulter STORE_DEPLOYMENT.md

### Rejet Google Play?
1. Lire message d'erreur complet
2. Consulter section "Rejection Commune Android"
3. Corriger et re-soumettre

### Rejet App Store?
1. Vérifier Privacy Policy HTTPS
2. Vérifier email support actif
3. Tester sur device iOS réel

---

## 📊 Checklist Final Avant Soumission

**✅ Code:**
- [ ] Version augmentée
- [ ] API URL production
- [ ] Pas de debug logs
- [ ] Pas de TODOs
- [ ] Build sans erreurs

**✅ Contenu:**
- [ ] Privacy Policy en ligne
- [ ] Terms en ligne
- [ ] Support email actif
- [ ] Screenshots prêts
- [ ] Descriptions écrites

**✅ Sécurité:**
- [ ] Keystore créé
- [ ] Certificat Apple installé
- [ ] URLs HTTPS validées
- [ ] Pas de secrets en dur

**✅ Tests:**
- [ ] App testée sur Android
- [ ] App testée sur iOS
- [ ] Pas de crashs
- [ ] Performance OK

---

## 📈 Après Publication

### Immediately
- [ ] Partager lien Play Store
- [ ] Partager lien App Store
- [ ] Annoncer sur réseaux sociaux
- [ ] Email à utilisateurs beta

### Semaine 1
- [ ] Monitorer reviews
- [ ] Répondre aux critiques
- [ ] Tracker téléchargements
- [ ] Corriger bugs mineurs

### Mois 1
- [ ] Planner version 1.1
- [ ] Collecter feature requests
- [ ] Optimiser performance
- [ ] Ajouter improvements

---

## 🎓 Ressources Supplémentaires

### Articles Recommandés
- https://flutter.dev/docs/deployment/android
- https://flutter.dev/docs/deployment/ios
- https://developer.android.com/distribute/google-play/launch
- https://developer.apple.com/app-store/review

### Tools Utiles
- App Icon Generator: https://appicon.co
- Google Play Console: https://play.google.com/console
- App Store Connect: https://appstoreconnect.apple.com

---

## ✨ Bonne Chance!

Vous êtes maintenant **100% prêt** pour publier sur les stores! 🚀

Tous les documents, guides et scripts sont fournis. Suivez simplement:
1. Lire PUBLISHING_GUIDE.md
2. Suivre SUBMISSION_CHECKLIST.md
3. Exécuter build_for_stores.bat/sh
4. Soumettre via consoles officielles

**Questions?** Consultez les documents détaillés ou ressources officielles.

**Bonne publication!** 🎉

---

**Version:** 1.0  
**Dernière MAJ:** 18 novembre 2025  
**Valide pour:** Flutter 3.10+ / Dart 3+
