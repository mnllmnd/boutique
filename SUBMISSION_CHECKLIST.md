# 📋 Checklist Final Avant Soumission

## ✅ Tâches Techniques

### Code & Build
- [ ] Version mise à jour dans `pubspec.yaml`
- [ ] Build number incrémenté
- [ ] API URL pointant vers production
- [ ] Pas de logs de debug
- [ ] Pas de TODOs critiques
- [ ] Code formaté (`flutter format lib/`)
- [ ] Analyse sans erreurs (`flutter analyze`)
- [ ] Tests unitaires passants
- [ ] Build release généré et testé

### Configuration Android
- [ ] Package name unique: `com.mnllmnd.boutique`
- [ ] Version code/name corrects
- [ ] minSdk = 21 (Android 5.0)
- [ ] targetSdk = 33+
- [ ] Permissions justifiées et minimales
- [ ] Keystore créé et sécurisé
- [ ] ProGuard/R8 configuré
- [ ] APK signé et testable

### Configuration iOS
- [ ] Bundle ID unique: `com.mnllmnd.boutique`
- [ ] Version correcte
- [ ] Certificat Apple installé
- [ ] Team ID configuré
- [ ] Permissions déclarées dans Info.plist
- [ ] Pas de dépendances non-publiques

### Icônes & Graphiques
- [ ] Icône app 512×512px haute résolution
- [ ] Icônes Android mipmap complètes
- [ ] Icônes iOS (AppIcon.appiconset)
- [ ] Pas de branding tiers dedans
- [ ] PNG sans transparence problématique

### Contenu & Documentation
- [ ] Privacy Policy en ligne et accessible
- [ ] Terms of Service en ligne et accessible
- [ ] Support email valide et fonctionnel
- [ ] Description claire et non trompeuse
- [ ] Screenshots actualisés et pertinents
- [ ] Pas de contenu généré par IA visiblement

---

## ✅ Tâches de Contenu

### Descriptions (App Store + Google Play)
- [ ] **Titre** (30-50 caractères):
  ```
  Boutique - Gestion de Dettes
  ```
- [ ] **Sous-titre** (30-50 caractères):
  ```
  Suivi clients et paiements facile
  ```
- [ ] **Description courte** (80 caractères):
  ```
  App gestion dettes pour petits commerces
  ```
- [ ] **Description complète** (4000 caractères):
  ```
  ✅ Enregistrez vos clients et dettes
  ✅ Suivez les paiements en temps réel
  ✅ Synchronisez avec votre équipe
  ✅ Accès hors ligne
  
  Parfait pour:
  - Petits commerces
  - Boutiques
  - Vendeurs ambulants
  
  Caractéristiques:
  - Interface simple et intuitive
  - Données sécurisées localement
  - Synchronisation cloud optionnelle
  - Gestion multi-utilisateur
  - Aucun frais caché
  ```

### Screenshots
- [ ] 5-8 screenshots par plateforme
- [ ] Format correct (1080×1920 pour Android)
- [ ] Montrant les fonctionnalités principales
- [ ] Texte lisible et en français
- [ ] Pas de données réelles sensibles
- [ ] Cohérent avec le design actuel

**Ordre suggéré:**
1. Écran d'accueil avec total
2. Liste des clients
3. Détails d'une dette
4. Ajout de paiement
5. Section équipe (si applicable)

### Métadonnées
- [ ] Catégorie: Business/Productivity
- [ ] Rating: 4+ (si possible)
- [ ] Région de publication: France/Afrique
- [ ] Langue: Français (+ English si possible)
- [ ] Contenu gratuit ou payant déclaré

---

## ✅ Tâches Légales

### Conformité Data
- [ ] RGPD compliant (Privacy Policy)
- [ ] Politique de données claires
- [ ] Pas de tracking non-consentis
- [ ] Droit à l'oubli respecté
- [ ] Consentement explicite pour partage

### Déclaration Contenu
- [ ] Pas de contenu pour mineurs
- [ ] Pas de jeux d'argent
- [ ] Pas de contenu violent/sexuel
- [ ] Pas de contact avec mineurs
- [ ] Évaluation pédiatrique si iOS

### Conformité Légale
- [ ] Pas de reproduction de devises
- [ ] Pas de fraude déclarée
- [ ] Conditions d'utilisation claires
- [ ] Support email valide
- [ ] Entreprise légalement constituée

---

## ✅ Tâches Pré-Soumission

### Tests Finaux
- [ ] [ ] Test complet sur device Android réel
- [ ] [ ] Test complet sur device iOS réel
- [ ] [ ] Test offline mode
- [ ] [ ] Test synchronisation (si applicable)
- [ ] [ ] Test avec données réelles (anonymisées)
- [ ] [ ] Pas de crash après 5 min utilisation
- [ ] [ ] Performance acceptable (< 2s load time)

### Signing & Build
- [ ] [ ] APK/IPA signé avec le bon certificat
- [ ] [ ] Version code/name correcte
- [ ] [ ] Taille app < 100MB (Android)
- [ ] [ ] Pas de fichiers temporaires
- [ ] [ ] Pas de clés/secrets en dur

### Préparation Soumission
- [ ] [ ] Comptes développeurs créés (Google/Apple)
- [ ] [ ] Paiements configurés (si payant)
- [ ] [ ] Adresse Support confirmée
- [ ] [ ] Contact legal identifié
- [ ] [ ] Images haute résolution prêtes

---

## 📱 Google Play Store

### Avant Soumission
```
1. Google Play Console → Créer App
2. Compléter les détails de l'app
3. Uploader AppBundle (app-release.aab)
4. Compléter les screenshots
5. Compléter la description
6. Configurer politique de contenu
7. Remplir questionnaire "Content Rating"
8. Configurer paiements (si applicable)
```

### Pré-Lancement
- [ ] Version en test à 10+ testeurs
- [ ] Feedback positif reçu
- [ ] Bugs critiques corrigés
- [ ] Version finale construite
- [ ] AppBundle final uploadé

### Checklist Soumission
- [ ] Titre + Sous-titre
- [ ] Description courte + longue
- [ ] Screenshot en 1080×1920 (min 2, max 8)
- [ ] Feature graphic en 1024×500
- [ ] Icon app en 512×512
- [ ] Privacy Policy URL
- [ ] Support email
- [ ] Category: Business
- [ ] Content rating questionnaire
- [ ] Révision en 2-3 jours (habituellement)

---

## 🍎 App Store (iOS)

### Avant Soumission
```
1. App Store Connect → My Apps
2. Créer nouvelle app
3. Compléter les informations
4. Générer certificat de distribution
5. Archive app depuis Xcode
6. Valider et distribuer
```

### Pré-Lancement
- [ ] TestFlight beta à 20+ testeurs
- [ ] 5+ jours de test minimum
- [ ] Feedback intégré
- [ ] Bugs majeurs résolus

### Checklist Soumission
- [ ] Titre
- [ ] Sous-titre
- [ ] Description (4000 car max)
- [ ] Mots-clés (100 caractères)
- [ ] Screenshot iPhone (6.5": 1242×2688)
- [ ] Screenshot iPad (12.9": 2048×2732)
- [ ] Preview video (optionnel)
- [ ] Icon 1024×1024
- [ ] Privacy Policy URL (HTTPS)
- [ ] Support URL
- [ ] Age Rating (Kids: NON)
- [ ] Révision en 1-3 jours

### Questionnaire App Store
- [ ] Collecte de données personnelles: OUI (phone)
- [ ] Données vendues à tiers: NON
- [ ] Données tracées: NON
- [ ] Données liées à identité utilisateur: OUI
- [ ] Santé & fitness: NON
- [ ] Contacts: OUI (optionnel)

---

## 🚨 Pièges à Éviter

### Rejection Commune Android
- ❌ APK avec même versionCode
- ❌ Package name comme com.example.app
- ❌ Pas de Privacy Policy
- ❌ Permissions non justifiées
- ❌ Over-permissioning (demander tout)
- ❌ Publicités non déclarées
- ❌ Frais cachés
- ❌ Contenu généré par IA evident

### Rejection Commune iOS
- ❌ Pas de Privacy Policy HTTPS
- ❌ App ne fonctionne pas au démarrage
- ❌ URLs cassées
- ❌ Crash sur device
- ❌ Performance pourrie (jank)
- ❌ Screenshots obsolètes
- ❌ Support email inactif
- ❌ API Apple non-publiques utilisées

---

## 📞 Support Post-Publication

### Monitoring
- [ ] Configurer crash reporting (Firebase)
- [ ] Monitorer reviews/ratings
- [ ] Répondre aux critiques négatives
- [ ] Tracker version adoptée

### Maintenance
- [ ] Plan de support utilisateur
- [ ] Email de support configuré
- [ ] FAQ préparée
- [ ] Version 1.1 planifiée (bugfixes)

---

## 🎉 Après Acceptation

### Célébration! 🎊
```
✅ App Live sur Play Store
✅ App Live sur App Store
✅ Url de partage:
   - Play Store: https://play.google.com/store/apps/details?id=com.mnllmnd.boutique
   - App Store: https://apps.apple.com/app/boutique/id[ID]
```

### Communication
- [ ] Annoncer dans les réseaux
- [ ] Notifier utilisateurs beta
- [ ] Ajouter lien en site/README
- [ ] Récolter premières reviews

### Itération
- [ ] Relire les reviews utilisateurs
- [ ] Planner version 1.1
- [ ] Corriger bugs signalés
- [ ] Ajouter fonctionnalités demandées

---

**Version Checklist:** 1.0  
**Dernière MAJ:** 18 novembre 2025
