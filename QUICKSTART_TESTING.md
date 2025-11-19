# 🚀 QUICK START - Tester la Fonctionnalité Mot de Passe Oublié

## 1️⃣ Préparation

### Backend
```bash
cd c:\Users\bmd-tech\Desktop\Boutique\backend
npm install  # Si besoin
npm run dev  # Démarre le serveur
```

### Base de Données
```sql
-- Appliquer la migration (une seule fois)
\connect boutique
\i migrations/004_add_security_question.sql
```

### Frontend
```bash
cd c:\Users\bmd-tech\Desktop\Boutique\mobile
flutter pub get
flutter run
```

---

## 2️⃣ Test Manuel Complet

### Étape 1: Créer un Compte
**Dans l'app:**
1. Appuyer sur "Créer un compte" (en bas de la page de login)
2. Remplir:
   - Prénom: `Jean`
   - Nom: `Dupont`
   - Numéro: `+212601234567` (ou votre numéro)
   - Mot de passe: `TestPass123`
   - Boutique: `Ma Boutique` (optionnel)
   - **Question secrète:** `Quel est le nom de votre premier animal?`
   - **Réponse secrète:** `Rex`
3. Appuyer "Créer un compte"

**Attendre:** Inscription réussie ✅

---

### Étape 2: Vérifier la Base de Données
**En terminal:**
```bash
# Vérifier que la réponse est hachée
psql -U user -d boutique -c "
  SELECT phone, security_question, security_answer_hash 
  FROM owners 
  WHERE phone='+212601234567'
"
```

**Résultat attendu:**
```
phone          | security_question                  | security_answer_hash
+212601234567  | Quel est le nom de votre premier   | $2b$10$... (hachée)
```

⚠️ La réponse ne doit PAS être "Rex" en plaintext!

---

### Étape 3: Déconnexion
**Dans l'app:**
1. Fermer l'app ou se déconnecter

---

### Étape 4: Test "Mot de Passe Oublié"
**Dans l'app (écran de login):**
1. Appuyer sur "Mot de passe oublié?"
2. Entrer le numéro: `+212601234567`
3. Appuyer "Continuer"

**Résultat attendu:**
- Message de succès disparaît
- La question secrète s'affiche: "Quel est le nom de votre premier animal?"
- Nouveau formulaire apparaît:
  - Réponse secrète
  - Nouveau mot de passe
  - Bouton "Réinitialiser le mot de passe"

---

### Étape 5: Test Mauvaise Réponse
**Dans l'app:**
1. Réponse secrète: `Chat` (MAUVAISE)
2. Nouveau mot de passe: `NewPass456`
3. Appuyer "Réinitialiser le mot de passe"

**Résultat attendu:**
- Erreur: "Incorrect answer" ❌

---

### Étape 6: Test Bonne Réponse
**Dans l'app:**
1. Réponse secrète: `rex` (minuscules, fonctionne aussi)
2. Nouveau mot de passe: `NewPass456`
3. Appuyer "Réinitialiser le mot de passe"

**Résultat attendu:**
- Succès: "Mot de passe réinitialisé avec succès!" ✅
- Redirection à l'écran de login

---

### Étape 7: Test Ancien Mot de Passe
**Dans l'app (écran de login):**
1. Numéro: `+212601234567`
2. Mot de passe: `TestPass123` (ANCIEN)
3. Appuyer "Se connecter"

**Résultat attendu:**
- Erreur: "Identifiants incorrects" ❌

---

### Étape 8: Test Nouveau Mot de Passe
**Dans l'app (écran de login):**
1. Numéro: `+212601234567`
2. Mot de passe: `NewPass456` (NOUVEAU)
3. Appuyer "Se connecter"

**Résultat attendu:**
- Connexion réussie ✅
- Accès à l'app

---

## 3️⃣ Tests API (avec curl ou Postman)

### Test GET - Récupérer la Question
```bash
curl -X GET "http://localhost:3000/api/auth/forgot-password/%2B212601234567" \
  -H "Content-Type: application/json"
```

**Réponse attendue:**
```json
{
  "security_question": "Quel est le nom de votre premier animal?"
}
```

---

### Test POST - Réinitialiser le Mot de Passe
```bash
curl -X POST "http://localhost:3000/api/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+212601234567",
    "security_answer": "rex",
    "new_password": "FinalPass789"
  }'
```

**Réponse attendue:**
```json
{
  "success": true,
  "message": "Password reset successfully",
  "user": {
    "id": 1,
    "phone": "+212601234567",
    "shop_name": "Ma Boutique",
    "first_name": "Jean",
    "last_name": "Dupont"
  }
}
```

---

### Test POST - Mauvaise Réponse
```bash
curl -X POST "http://localhost:3000/api/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+212601234567",
    "security_answer": "Chat",
    "new_password": "WrongAnswer789"
  }'
```

**Réponse attendue:**
```json
{
  "error": "Incorrect answer"
}
```

---

## 4️⃣ Checklist de Vérification Finale

### Frontend
- [ ] Champs de question/réponse visibles à l'inscription
- [ ] Lien "Mot de passe oublié?" visible à la connexion
- [ ] Page ForgotPasswordPage se lance correctement
- [ ] Question s'affiche après entrée du numéro
- [ ] Message d'erreur "Incorrect answer" s'affiche
- [ ] Succès redirection au login
- [ ] Aucun crash ou erreur

### Backend
- [ ] GET /forgot-password/:phone répond avec la question
- [ ] POST /reset-password met à jour le mot de passe
- [ ] Réponse incorrecte retourne erreur 401
- [ ] Nouveau mot de passe fonctionne pour connexion
- [ ] Ancien mot de passe ne fonctionne plus
- [ ] Logs serveur sans erreur

### Base de Données
- [ ] Colonne security_question créée
- [ ] Colonne security_answer_hash créée
- [ ] security_answer_hash est hachée (pas plaintext)
- [ ] security_question et security_answer_hash remplis pour nouveaux users
- [ ] password mis à jour après reset

---

## 5️⃣ Dépannage

### Problème: "Question introuvable"
```
Cause: Utilisateur pas trouvé ou question non définie
Solution: Vérifier le numéro de téléphone
```

### Problème: "Mot de passe non mis à jour"
```
Cause: Mauvaise réponse ou erreur serveur
Solution: Vérifier les logs backend
```

### Problème: "Migration échouée"
```
Cause: Colonne déjà existe
Solution: `DROP COLUMN IF EXISTS` ou ignorer
```

### Problème: "Connexion refuse après reset"
```
Cause: Nouveau mot de passe pas sauvegardé
Solution: Vérifier les logs backend et la base de données
```

---

## 6️⃣ Logs Utiles

### Backend (affichage pendant npm run dev)
```
GET /api/auth/forgot-password/+212601234567 200
POST /api/auth/reset-password 200
```

### Frontend (affichage dans flutter logs)
```
I/flutter (xxxxx): Requesting security question for phone: +212601234567
I/flutter (xxxxx): Got security question: Quel est...
I/flutter (xxxxx): Resetting password...
```

---

## 7️⃣ Notes Importantes

- ✅ La réponse est **case-insensitive** (`Rex`, `rex`, `REX` → tous valides)
- ✅ La réponse est **trimmed** (espaces avant/après supprimés)
- ✅ Le numéro de téléphone utilise le format: `+212...`
- ✅ Les réponses sont **hachées avec bcrypt** (5 salt rounds en test, 10 en prod)
- ⚠️ Les erreurs sont **génériques** pour la sécurité (ne dit pas "user not found")

---

## 8️⃣ Temps Estimé

- Installation/Préparation: 5 min
- Création de compte: 1 min
- Test complet (tous scénarios): 10 min
- **Total: ~15 minutes**

---

## 9️⃣ Validation Finale

✅ **SI TOUS LES TESTS PASSENT:**
- La fonctionnalité est prête pour production
- Documenter dans les release notes
- Notifier les utilisateurs de la nouvelle fonctionnalité

---

## 📚 Ressources

| Document | Contenu |
|----------|---------|
| `FORGOT_PASSWORD_FEATURE.md` | Vue d'ensemble |
| `IMPLEMENTATION_SUMMARY.md` | Détails techniques |
| `VERIFICATION_CHECKLIST.md` | Checklist complète |
| `COMPLETION_REPORT.md` | Rapport final |
| `test_forgot_password.sh` | Script de test |

---

**Bon test! 🎉**
